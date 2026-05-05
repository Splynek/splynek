# Splynek Direct Channel — Stripe + Postmark — Design Doc

> Status: **design only.** No code in `Sources/SplynekCore` is wired
> to this yet.  The doc captures the architecture so that when the
> maintainer is ready to ship the channel, the implementation is a
> straight-line build instead of a green-field design problem.
> Drafted 2026-05-05 as part of the post-audit roadmap.

## Why this exists

Splynek's only payment channel today is the Mac App Store ($29 IAP via
StoreKit).  That has three structural costs:

1. **Apple's 30 % cut** on a $29 SKU = $8.70 / sale.  At $20.30 net,
   the unit economics don't tolerate paid acquisition.
2. **Geographic exclusion.**  Several countries don't have MAS access
   for IAP receipts (Russia after 2022, Iran, Cuba, etc.).  A
   non-trivial subset of European-sovereignty enthusiasts live in
   Apple-restricted markets.
3. **Single-point-of-failure.**  If an MAS reviewer ever flags
   Splynek (e.g., Guideline 2.5.2 vibe-coding wave, NetworkExtension
   policy churn, or a future privacy-of-on-device-LLM rule), the
   product has zero revenue overnight.

A direct payment channel — Stripe Checkout for collection + a
self-hosted license server for issuance + Postmark for delivery —
de-risks all three.

## Architecture

```
   ┌──────────────────┐         ┌──────────────────┐
   │  splynek.app/pro │         │  Stripe Checkout │
   │  (existing page) │ ──────▶ │  (hosted by      │
   │  + "Buy Pro"     │         │   Stripe)        │
   │   button         │         └──────────────────┘
   └──────────────────┘                  │
                                          │ payment success
                                          ▼
   ┌──────────────────┐         ┌──────────────────┐
   │  Stripe webhook  │ ──────▶ │  License server  │
   │  (POST event)    │         │  (Cloudflare     │
   └──────────────────┘         │   Worker)        │
                                  │
                                  │ 1. parse customer email
                                  │ 2. mint HMAC license key
                                  │ 3. POST to Postmark API
                                  ▼
                       ┌──────────────────┐
                       │  Postmark        │
                       │  (transactional) │
                       └──────────────────┘
                                  │
                                  │ email with key + Splynek download
                                  ▼
                       ┌──────────────────┐
                       │  Customer's      │
                       │  inbox           │
                       └──────────────────┘
```

Key arrives in the customer's inbox with:

```
Subject: Your Splynek Pro license

Hi <name>,

Thanks for buying Splynek Pro.  Here's your license key:

  splynek-pro-xxxxx-xxxxx-xxxxx-xxxxx-xxxxx

Open Splynek → Settings → Direct License → paste key.

Splynek will validate locally — no network round-trip.

Need a fresh download?  https://splynek.app/download

— Paulo
```

## Pieces by domain

### Client-side (Splynek.app, DMG build only)

A revival of the v0.33–v0.43 HMAC license validator that was
deprecated in favour of MAS StoreKit.  The MAS build keeps StoreKit;
the DMG build adds **back** the HMAC path.

```swift
// Sources/SplynekCore/LicenseManagerHMAC.swift  (DMG-only)
@MainActor
final class LicenseManagerHMAC: LicenseManagerProtocol {
    /// `splynek-pro-XXXXX-XXXXX-XXXXX-XXXXX-XXXXX` form
    /// (5 groups of 5 base32 chars after the "splynek-pro-" prefix).
    func validate(_ raw: String) -> ValidationResult {
        // 1. Parse: extract the 25-char body + email
        // 2. Compute HMAC-SHA256(SECRET, email + plan + issued-at)
        // 3. Constant-time compare against the encoded checksum
        //    inside the key.
        // 4. Return .valid(email, plan, issuedAt) | .badFormat |
        //    .badSignature | .expired (if revoked-after-N-days policy)
    }
}
```

Same `isPro` / `licensedEmail` / `lastUnlockError` API surface as the
existing `LicenseManager` (StoreKit) so the SwiftUI bindings don't
change.  Settings UI gets a second card "Direct License" alongside
"Splynek Pro (Mac App Store)" when the build is the DMG variant.

### Server-side (license issuance)

**Cloudflare Worker** (recommended) — no provisioning, free for our
volume, runs the same JavaScript on every Cloudflare PoP.

```javascript
// workers/license-issuer/index.js
import { hmacSha256 } from './crypto.js';

export default {
  async fetch(req, env) {
    if (req.method !== 'POST') return new Response('Method not allowed', { status: 405 });
    if (!verifyStripeSignature(req, env.STRIPE_WEBHOOK_SECRET)) {
      return new Response('Bad signature', { status: 400 });
    }
    const event = await req.json();
    if (event.type !== 'checkout.session.completed') {
      return new Response('OK', { status: 200 });  // we only care about completed
    }
    const email = event.data.object.customer_details.email;
    const plan = 'pro-lifetime';
    const issuedAt = Math.floor(Date.now() / 1000);
    const key = mintHMACKey(env.LICENSE_HMAC_SECRET, email, plan, issuedAt);
    await sendPostmarkEmail(env.POSTMARK_TOKEN, email, key);
    return new Response('OK', { status: 200 });
  }
};
```

Two secrets in the Worker's KV:
- `STRIPE_WEBHOOK_SECRET` — to verify webhook signatures
- `LICENSE_HMAC_SECRET` — the same secret hashed into the client app's binary
- `POSTMARK_TOKEN` — Postmark server token for transactional sends

### Email delivery (Postmark)

Postmark is the right choice over SendGrid / Mailgun / SES because:
- $1.25 per 10,000 transactional emails — cheaper than alternatives
  at our volume.
- 1-touch SPF + DKIM + DMARC setup; deliverability ≈ enterprise SES
  without the AWS billing dance.
- Templates are trivial — no MJML required for a single transactional
  email.

One server token + one transactional template ("Splynek Pro license
delivery") — the Worker POSTs to `/email/withTemplate` with
`{ email, key, name }` substitutions.

## Operational checklist (maintainer-only)

These are the steps Paulo must take that **cannot** be done from a
Claude session:

### Stripe (1–2 hrs)

- [ ] Create Stripe account at `dashboard.stripe.com/register`.
      Use `paulo@splynek.app` (alias of `paulocgm@gmail.com`).  EU
      address → 0 % VAT pass-through (Stripe Tax handles VAT MOSS).
- [ ] Create Product: "Splynek Pro — Lifetime License".  $29 USD,
      one-time charge.  Description text from `MAS_LISTING.md`.
- [ ] Create Price: `price_1xxx...` — $29 USD lifetime.  Stripe
      auto-converts to local currency on Checkout.
- [ ] Enable Stripe Tax.  This auto-collects EU VAT (€5.49 in PT, etc.)
      on sales to EU customers, and remits via Stripe's quarterly
      filing.
- [ ] Configure webhook endpoint: `https://license.splynek.app/stripe`
      (subdomain you'll set up next), event filter:
      `checkout.session.completed`.
- [ ] Copy webhook signing secret → Cloudflare Worker KV
      `STRIPE_WEBHOOK_SECRET`.

### Postmark (30 min)

- [ ] Create Postmark account at `account.postmarkapp.com/sign_up`.
      First 100 emails free; then $1.25 / 10k.
- [ ] Verify `splynek.app` sender domain (DNS record changes for SPF
      + DKIM + Return-Path).
- [ ] Create transactional template "License Delivery" (template ID
      `<id>` — copy into Worker KV `POSTMARK_TEMPLATE_ID`).
- [ ] Generate Server token → KV `POSTMARK_TOKEN`.

### Cloudflare Worker (1 hr)

- [ ] `wrangler init license-issuer`
- [ ] Paste `index.js` skeleton from above + crypto helpers.
- [ ] Set KV bindings (Stripe webhook secret, license HMAC secret,
      Postmark token + template ID).
- [ ] Deploy: `wrangler deploy`.
- [ ] Add CNAME `license.splynek.app` → Worker route.
- [ ] Smoke test: trigger a Stripe webhook test event, verify
      Worker logs show success + Postmark sandbox sees the send.

### Splynek client (DMG build) — 1 day implementation

- [ ] `Sources/SplynekCore/LicenseManagerHMAC.swift` — the validator
      (resurrect from v0.43 git tag's `LicenseManager.swift`, adapt to
      the protocol surface).
- [ ] `Resources/Splynek-DMG.xcconfig` — bake the LICENSE_HMAC_SECRET
      hex into the binary (build-time; do NOT commit the secret).
- [ ] `Sources/SplynekCore/Views/SettingsView.swift` — add the "Direct
      License" card alongside the StoreKit card (visible only when
      `#if DMG_BUILD`).
- [ ] Tests: `Tests/SplynekTests/LicenseManagerHMACTests.swift` —
      validate happy path + bad-format + bad-sig + revoked-after-N-days.

### Landing page update

- [ ] `docs/index.html` — add "Buy direct (€29)" button next to the
      existing "Buy on Mac App Store" button.
- [ ] `docs/pro.html` — explain the two channels (one-line each) and
      let users pick.

## Cost projection

- Stripe: 2.9 % + €0.25 per sale = $1.09 on a $29 USD sale.  Net
  $27.91 vs MAS net $20.30 — **+$7.61 / sale = +37.5 % margin**.
- Cloudflare Worker: free under 100k requests/day (we're at <100/day).
- Postmark: $1.25 per 10k emails — at our volume, $1.25 / quarter.
- DNS / domain: already paid.
- **Total marginal cost: ~$1.10 / sale, vs MAS ~$8.70 / sale.**

## Open design questions

1. **Email-as-license-binding.**  The HMAC key embeds the buyer's
   email.  Validates locally without hitting the server.  Trade-off:
   if a customer changes email later, they need a re-issued key.
   Self-service: simple `support@splynek.app` reply.  Volume is
   manageable.
2. **Refunds.**  Stripe refunds are easy; revoking the issued license
   is harder (no central authority).  Decision: trust + light-touch
   blocklist.  If a customer chargebacks, manually add their key to
   a published blocklist that Splynek fetches on launch (list lives
   in `splynek.app/.well-known/splynek-revocations.txt`).  Volume
   should stay low.
3. **Pirated keys.**  Copying a key to a friend works; HMAC doesn't
   prevent it.  Same trust-based posture as v0.33–v0.43; per Sublime
   Text / 1Password and other indie shops, this is rarely material at
   our price point.
4. **EU VAT MOSS handling.**  Stripe Tax handles collection +
   quarterly filing in the maintainer's name.  $0 setup, ~5 % of
   transactions reported to local tax authority.
5. **Privacy.**  Stripe sees buyer email + name + IP (legal
   requirement).  Splynek sees nothing — the binary doesn't ping the
   license server post-purchase.  This is a stronger privacy stance
   than MAS where Apple sees Apple-ID + IP + device fingerprint.

## Why ship this BEFORE Apple v1.0 clears

Two reasons:

- The MAS submission is bottlenecked on Apple's reviewer cadence.
  The DMG build can ship today and start generating revenue.
- A working direct channel reduces the "what if Apple rejects" risk
  from ship-blocking to ship-delaying.

## Why NOT to ship this BEFORE Apple v1.0 clears

- Apple's MAS reviewers see the website.  If `splynek.app/pro` shows
  a "Buy direct" button alongside "Buy on MAS", they may flag Splynek
  under Guideline 3.1.1 ("If you want to use payment systems other
  than Apple's...  the SKU must use IAP for in-app purchases").  But
  the IAP rule applies to **in-app** payments — out-of-app purchases
  are explicitly allowed (and Spotify et al. do this).  Reviewer
  caution is to NOT mention the direct channel from inside the app
  itself; the website is in scope.
- The direct channel changes the unit economics.  At $1.10 / sale
  cost, it's tempting to lower the price (e.g. €25 direct, €29 MAS)
  to make the margin advantage more attractive to buyers.  But a
  price split also annoys MAS reviewers.  Decision: **same price
  both channels.**  Direct = better margin for Paulo, MAS =
  one-click ease for buyers.

## What to do today

Two non-blocking pre-flights so the maintainer can ship the channel
in a single sitting once Apple v1.0 clears:

1. Open Stripe + Postmark accounts (1.5 hrs total) — accounts can
   sit idle.  No fees until first sale.
2. Stand up the Cloudflare Worker (~1 hr) — costs $0 idle.

Then when ready: implement client-side LicenseManagerHMAC + ship.
1-day push.

## Open questions to resolve before implementation

- Use `paulo@splynek.app` (alias) or `paulocgm@gmail.com` directly?
  The alias gives more flexibility for handing off later.
- License key format: 25 base32 chars (existing v0.43 shape) or
  something more readable like `XXXXX-XXXXX-XXXXX-XXXXX-XXXXX`?
  v0.43 shape is faster to ship; readability is cosmetic.
- "License lookup" button (re-fetch your key from email) — worth
  building, or just direct customers to email search?  Latter is
  simpler.
