# Splynek licence-server (Cloudflare Worker)

> 2026-06 direct-sale launch.  Receives the LemonSqueezy webhook
> when someone buys Splynek Pro, signs a `.splynekkey` licence file
> with the Ed25519 private key held in a Worker secret, and emails
> it to the buyer.  See `../LAUNCH-WITHOUT-APPLE.md` for the wider
> strategy.

## Files

| File | Purpose |
|---|---|
| `worker.js` | Worker source.  Two routes: `/api/license/health` and `/api/license/lemonsqueezy-webhook` |
| `wrangler.toml` | Cloudflare Worker config |
| `README.md` | This file |

## One-time setup (maintainer)

```bash
# 1. Install Wrangler
npm install -g wrangler@latest

# 2. Log in to Cloudflare
wrangler login

# 3. Generate the Ed25519 signing keypair.  Run this LOCALLY on a
#    trusted machine — the private key NEVER goes into a git-tracked
#    file.  Output is two base64 strings.
swift -e '
import CryptoKit
let k = Curve25519.Signing.PrivateKey()
print("PRIVATE (Worker secret):", k.rawRepresentation.base64EncodedString())
print("PUBLIC  (bake into app):", k.publicKey.rawRepresentation.base64EncodedString())
'

# 4. Paste the private key into a Worker secret.
cd Worker/
wrangler secret put LICENSE_SIGNING_PRIVATE_KEY
# (paste the base64 PRIVATE string, hit enter)

# 5. Paste the LemonSqueezy webhook signing secret.  Get it from
#    LemonSqueezy dashboard → Settings → Webhooks → Signing secret.
wrangler secret put LEMONSQUEEZY_WEBHOOK_SECRET

# 6. Paste the Resend API key (or whichever transactional-email
#    provider you pick).
wrangler secret put RESEND_API_KEY

# 7. Deploy
wrangler deploy
```

After deploy, copy the *.workers.dev URL Cloudflare prints and paste
it into LemonSqueezy → Settings → Webhooks → Add endpoint, ticking
the `order_created` event.

## What the maintainer takes from this

After deploy you have:

- A **public Ed25519 key** in base64 — paste it into
  `Sources/SplynekCore/ProStubs.swift` replacing the
  `REPLACE_ME_WITH_LAUNCH_PUBLIC_KEY` placeholder.  Commit that
  before tagging the launch build.
- A **private Ed25519 key** in base64 — already in the Worker
  secret.  Back it up to 1Password / a hardware key.  If we ever
  need to rotate (key compromise), we generate a new pair, redeploy
  the Worker with the new private, and ship a Mac app point-release
  with the new public.  Old licences keep working in older app
  versions; new licences only verify on the post-rotation app.
- A **webhook endpoint** at `https://<your-worker>.workers.dev/api/license/lemonsqueezy-webhook`.

## Local testing

```bash
# Run the worker locally on http://localhost:8787
wrangler dev

# In another terminal, hit the health endpoint
curl http://localhost:8787/api/license/health
# → {"status":"ok","product":"splynek-pro"}
```

To test the webhook flow without a real LemonSqueezy purchase, you'd
need to:
1. Compute the X-Signature HMAC of a sample body manually
2. POST it to the local endpoint
3. Inspect the Resend response

The maintainer can run an integration test against LemonSqueezy's
"Send test webhook" button in the dashboard once the Worker is
deployed.

## Canonicalisation contract

The licence signature is computed over a **canonical JSON form** of
the licence envelope.  Both this Worker and the Mac client
(`Sources/SplynekCore/LicenseFile.swift`) must produce
**byte-identical** canonical payloads, or signatures won't verify.

Rules:
1. **Sorted keys alphabetically.**  `edition`, `email`, `license_id`,
   `product`, `purchased_at`, `version_cap`.
2. **No whitespace.**  JSON spec separators only.
3. **`null` for missing version_cap**, never omitted.
4. **ISO-8601 timestamps** for `purchased_at`.
5. **The `signature` field itself is EXCLUDED** from the canonical
   payload (we're signing everything else).

JS:
```js
JSON.stringify({
    edition: license.edition,
    email: license.email,
    license_id: license.license_id,
    product: license.product,
    purchased_at: license.purchased_at,
    version_cap: license.version_cap ?? null,
})
```

Swift (mirror):
```swift
try JSONSerialization.data(
    withJSONObject: [
        "edition":      edition.rawValue,
        "email":        email,
        "license_id":   licenseID,
        "product":      product,
        "purchased_at": Self.isoFormatter.string(from: purchasedAt),
        "version_cap":  versionCap as Any,
    ],
    options: [.sortedKeys, .withoutEscapingSlashes]
)
```

If you change one side, change both, and add a paired test in
`Tests/SplynekTests/LicenseFileTests.swift` that exercises a fresh
end-to-end flow with the new canonicalisation.

## Cost

Cloudflare Workers free tier: 100,000 requests/day.  We expect
< 100 license activations/day in the first year — well within free.

Resend free tier: 3,000 emails/month, 100/day.  Same comfort margin.

Upgrade trigger: if Splynek hits viral growth and we cross the free
tier, the per-license cost is still pennies — not a strategic
concern.

## Future

- **Re-issue endpoint** (`/api/license/reissue`) — buyer who lost
  the email can re-trigger.  Need a KV/D1 store keyed by email or
  order ID.  Out of launch scope.
- **Revocation list** (`/api/license/revoke`) — if we ever see
  meaningful piracy, sign + serve a revocation list the Mac client
  checks once a month with a 30-day grace window.  Out of launch
  scope.
- **Refund hook** — LemonSqueezy `order_refunded` webhook → add
  the license_id to the revocation list.  Pair with the previous
  bullet.  Out of launch scope.
