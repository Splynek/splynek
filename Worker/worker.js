// Splynek licence-server Cloudflare Worker.
//
// 2026-06 direct-sale launch — see LAUNCH-WITHOUT-APPLE.md § 5 for
// the strategy.  Pipeline:
//
//   1.  Buyer hits splynek.app/pro, clicks "Buy Splynek Pro".
//   2.  LemonSqueezy hosted checkout takes payment.
//   3.  LemonSqueezy fires `order_created` webhook to this worker.
//   4.  Worker verifies the LemonSqueezy webhook HMAC.
//   5.  Worker builds the licence JSON envelope, signs it with the
//       Ed25519 private key held in `LICENSE_SIGNING_PRIVATE_KEY`
//       secret, and emails the signed `.splynekkey` attachment to
//       the buyer via Resend (or whichever transactional-email API
//       the maintainer picks).
//
// The Mac client (Sources/SplynekCore/LicenseFile.swift) verifies
// signatures against the matching PUBLIC key, which is baked into
// the Mac app binary at build time (LicenseManager.publicKeyBase64).
// Canonicalisation is identical on both sides: sorted JSON keys, no
// whitespace, ISO-8601 timestamps, signature computed over the
// envelope minus the `signature` field itself.
//
// Local-test invocation:
//   wrangler dev
//   curl -X POST http://localhost:8787/api/license/lemonsqueezy-webhook \
//     -H "X-Signature: $(node -e "...")" \
//     -d '<test webhook body>'
//
// Production routing: bind `splynek.app/api/license/*` to this
// worker in the Cloudflare dashboard, or use the *.workers.dev URL
// configured as the LemonSqueezy webhook endpoint.

// ────────────────────────────────────────────────────────────────────
// Crypto utilities
// ────────────────────────────────────────────────────────────────────

/**
 * Decode a base64 string into a Uint8Array.  Worker runtime has atob;
 * we wrap it for buffer convenience.
 */
function b64decode(b64) {
    const bin = atob(b64);
    const out = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
    return out;
}

/**
 * Base64-encode a Uint8Array (worker-safe — no Buffer).
 */
function b64encode(bytes) {
    let bin = "";
    for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);
    return btoa(bin);
}

/**
 * Import an Ed25519 private key (32-byte raw) into a SubtleCrypto
 * CryptoKey ready for signing.  Worker's WebCrypto supports Ed25519
 * via the `Ed25519` algorithm name; nodejs_compat is required.
 */
async function importPrivateKey(privBase64) {
    const raw = b64decode(privBase64);
    // Construct a PKCS8 wrapper around the raw 32-byte seed.
    // Ed25519 OID: 1.3.101.112, encoded as 06 03 2B 65 70.
    const pkcs8Prefix = new Uint8Array([
        0x30, 0x2e, 0x02, 0x01, 0x00, 0x30, 0x05, 0x06,
        0x03, 0x2b, 0x65, 0x70, 0x04, 0x22, 0x04, 0x20,
    ]);
    const pkcs8 = new Uint8Array(pkcs8Prefix.length + raw.length);
    pkcs8.set(pkcs8Prefix, 0);
    pkcs8.set(raw, pkcs8Prefix.length);
    return crypto.subtle.importKey(
        "pkcs8", pkcs8,
        { name: "Ed25519" }, false, ["sign"],
    );
}

/**
 * Verify a LemonSqueezy webhook HMAC.  Signature header is
 * "X-Signature: <hex of HMAC-SHA256(payload, secret)>".  Constant-
 * time comparison.
 */
async function verifyLemonSqueezySignature(body, signatureHex, secret) {
    const enc = new TextEncoder();
    const key = await crypto.subtle.importKey(
        "raw", enc.encode(secret),
        { name: "HMAC", hash: "SHA-256" }, false, ["sign"],
    );
    const sigBytes = await crypto.subtle.sign("HMAC", key, enc.encode(body));
    const expected = Array.from(new Uint8Array(sigBytes))
        .map((b) => b.toString(16).padStart(2, "0")).join("");
    if (expected.length !== signatureHex.length) return false;
    let diff = 0;
    for (let i = 0; i < expected.length; i++) {
        diff |= expected.charCodeAt(i) ^ signatureHex.charCodeAt(i);
    }
    return diff === 0;
}

// ────────────────────────────────────────────────────────────────────
// Licence canonicalisation (must match LicenseFile.swift exactly)
// ────────────────────────────────────────────────────────────────────

/**
 * Build the canonical JSON payload that the Ed25519 signature is
 * computed over.  Sorted keys, no whitespace, `null` for missing
 * versionCap, ISO-8601 timestamp.
 *
 * IMPORTANT: this MUST byte-match the output of
 * LicenseFile.canonicalPayload() on the Swift side, or signatures
 * won't verify on the Mac client.  Both sides use:
 *   - alphabetical key order
 *   - JSON spec separators (no extra spaces)
 *   - `null` for nullable fields when nil/undefined
 *   - the `signature` field excluded
 */
function canonicalLicensePayload(env, license) {
    // Keys in alphabetical order to match Swift's
    // JSONSerialization.WritingOptions.sortedKeys output.
    const ordered = {
        edition:      license.edition,
        email:        license.email,
        license_id:   license.license_id,
        product:      license.product,
        purchased_at: license.purchased_at,
        version_cap:  license.version_cap ?? null,
    };
    return JSON.stringify(ordered);
}

/**
 * Sign the canonical payload with Ed25519, return base64 signature.
 */
async function signLicense(privateKey, canonical) {
    const enc = new TextEncoder();
    const sig = await crypto.subtle.sign(
        "Ed25519", privateKey, enc.encode(canonical),
    );
    return b64encode(new Uint8Array(sig));
}

// ────────────────────────────────────────────────────────────────────
// LemonSqueezy webhook handler
// ────────────────────────────────────────────────────────────────────

/**
 * Build the licence envelope from a LemonSqueezy `order_created`
 * webhook payload.  Field mapping (LemonSqueezy → Splynek):
 *   data.attributes.user_email   → email
 *   data.attributes.identifier   → license_id (prefix "lic_")
 *   data.attributes.created_at   → purchased_at
 *
 * If the product variant slug includes "annual" / "pro-plus", flip
 * `edition` accordingly.  Default is `lifetime`.
 */
function buildLicenseFromWebhook(env, webhook) {
    const order = webhook?.data?.attributes ?? {};
    const variant = (order.first_order_item?.variant_name || "").toLowerCase();
    let edition = "lifetime";
    if (variant.includes("pro plus") || variant.includes("pro+")) {
        edition = "pro_plus_annual";
    } else if (variant.includes("annual")) {
        edition = "annual";
    }
    return {
        license_id:   "lic_" + (order.identifier || crypto.randomUUID()),
        email:        order.user_email,
        product:      env.PRODUCT_SLUG || "splynek-pro",
        edition,
        version_cap:  null,
        purchased_at: (order.created_at || new Date().toISOString()),
    };
}

/**
 * Email the signed licence file to the buyer via Resend (or any
 * provider the maintainer configures).  We use Resend's REST API
 * here because it has the simplest worker-friendly auth model;
 * swap for Postmark / SendGrid / SES by changing this function.
 */
async function emailLicense(env, license, signedJson) {
    const attachmentB64 = b64encode(new TextEncoder().encode(signedJson));
    const body = {
        from: `${env.FROM_NAME} <${env.FROM_EMAIL}>`,
        to:   [license.email],
        subject: "Your Splynek Pro licence",
        html: `
            <p>Hey,</p>
            <p>Thanks for buying Splynek Pro. Your licence file is
            attached — just double-click <code>splynek-license.splynekkey</code>
            and Splynek will activate Pro on your Mac.</p>
            <p>If you haven't installed Splynek yet, grab it at
            <a href="${env.APP_DOWNLOAD_URL}">${env.APP_DOWNLOAD_URL}</a>.</p>
            <p>The licence is yours forever, no account required, no
            phone-home. It works on every Mac you own — sign in via
            File &rarr; Activate Licence&hellip; on each one.</p>
            <p>Need help? Reply to this email or write to
            <a href="mailto:${env.SUPPORT_EMAIL}">${env.SUPPORT_EMAIL}</a>.</p>
            <p>— Splynek</p>
        `,
        attachments: [
            {
                filename: "splynek-license.splynekkey",
                content: attachmentB64,
            },
        ],
    };
    const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
            "Authorization": `Bearer ${env.RESEND_API_KEY}`,
            "Content-Type": "application/json",
        },
        body: JSON.stringify(body),
    });
    if (!res.ok) {
        const txt = await res.text();
        throw new Error(`Resend ${res.status}: ${txt}`);
    }
}

// ────────────────────────────────────────────────────────────────────
// Worker entry point
// ────────────────────────────────────────────────────────────────────

export default {
    async fetch(request, env, ctx) {
        const url = new URL(request.url);

        // Health check — useful for monitoring + dashboard ping.
        if (url.pathname === "/api/license/health" && request.method === "GET") {
            return new Response(
                JSON.stringify({ status: "ok", product: env.PRODUCT_SLUG }),
                { headers: { "Content-Type": "application/json" } },
            );
        }

        // LemonSqueezy webhook receiver.
        if (url.pathname === "/api/license/lemonsqueezy-webhook"
            && request.method === "POST") {

            const body = await request.text();
            const sig = request.headers.get("X-Signature") || "";
            const ok = await verifyLemonSqueezySignature(
                body, sig, env.LEMONSQUEEZY_WEBHOOK_SECRET,
            );
            if (!ok) {
                return new Response("Invalid signature", { status: 401 });
            }

            let payload;
            try {
                payload = JSON.parse(body);
            } catch {
                return new Response("Malformed JSON", { status: 400 });
            }

            // We only react to successful orders here.  Refunds /
            // subscription updates / etc. land in their own routes
            // when we add them.
            const eventName = request.headers.get("X-Event-Name") || "";
            if (!["order_created", "subscription_payment_success"].includes(eventName)) {
                // Silently 200 — webhook delivery is at-least-once, we
                // don't want LemonSqueezy retrying.
                return new Response("Ignored", { status: 200 });
            }

            try {
                const license = buildLicenseFromWebhook(env, payload);
                if (!license.email) {
                    return new Response("Missing email", { status: 400 });
                }

                const canonical = canonicalLicensePayload(env, license);
                const privKey = await importPrivateKey(env.LICENSE_SIGNING_PRIVATE_KEY);
                const signature = await signLicense(privKey, canonical);
                const signed = { ...license, signature };
                const signedJson = JSON.stringify(signed);

                await emailLicense(env, license, signedJson);

                return new Response(
                    JSON.stringify({ ok: true, license_id: license.license_id }),
                    { headers: { "Content-Type": "application/json" } },
                );
            } catch (err) {
                // Best to surface the error so LemonSqueezy retries.
                console.error("licence pipeline failure:", err);
                return new Response("Internal error: " + err.message, { status: 500 });
            }
        }

        // Re-issue endpoint — buyer lost their email, wants the
        // licence file resent.  Auth = email match against a
        // separate KV / D1 store the maintainer wires up later.
        // Out of scope for the launch ship; placeholder route here.
        if (url.pathname === "/api/license/reissue" && request.method === "POST") {
            return new Response(
                "Re-issue endpoint not yet wired — email " + env.SUPPORT_EMAIL + " for manual re-send.",
                { status: 503 },
            );
        }

        return new Response("Not found", { status: 404 });
    },
};
