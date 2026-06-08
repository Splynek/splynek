# MAINTAINER-LAUNCH-CHECKLIST.md

> Everything the maintainer must do **outside the codebase** to
> launch Splynek 3.0 direct-sale on Mon 2026-06-08.  Items here are
> tasks Claude can't do — account signups, KYC, secret pasting,
> domain DNS, payment-card test, press emails.
>
> Pair this with `LAUNCH-WITHOUT-APPLE.md` (the strategy doc) and
> `LAUNCH-3.0-COPY.md` (the public copy).
>
> **Target ship dates**:
>   - **D-2** = Mon 2026-06-08 (soft launch via splynek.app + Twitter
>     + Bluesky + Discord + email list)
>   - **D-0** = Wed 2026-06-10 (Show HN drops at 06:00 PT)

---

## Phase A — Accounts + secrets (D-14 to D-7 — start this week)

Allow 1-3 days for LemonSqueezy KYC.  Some items have hard
dependencies on others, marked with `→`.

### A1. LemonSqueezy account

1. Sign up at https://lemonsqueezy.com → "Sell digital products".
2. Complete the KYC flow.  Personal info, tax forms (W-8BEN for
   non-US sellers; LemonSqueezy is the merchant-of-record so they
   handle the actual 1099-K filings).
3. Add a payout method (bank account; SEPA for EU sellers).
4. Stripe-connect optional — only needed if you opt out of the MoR
   model.  We keep MoR; skip.

→ Output: LemonSqueezy account verified, payout configured.

### A2. LemonSqueezy product setup

1. Dashboard → Products → New Product
2. Name: **Splynek Pro**
3. Tagline: "Daily privacy-policy diffs for the apps you have
   installed.  Lifetime."
4. Description: copy from `LAUNCH-3.0-COPY.md` § Section 1 + 4
5. Pricing model: **One-time payment**
6. Price: **$29 USD** (we'll discount to $24 via a launch-week
   coupon — see A3)
7. Upload a 1200×1200 product image (use the Trust Watcher hero
   screenshot from the press kit)
8. Variants: optional — leave a single "Lifetime" variant for v3.0
9. Inventory: Unlimited
10. Customer note: "Your licence file will arrive by email within 1
    minute.  Double-click the `.splynekkey` attachment to activate
    Splynek Pro on your Mac."

→ Output: Live product URL (e.g.
  `https://splynek.lemonsqueezy.com/checkout/buy/<uuid>`).  Paste
  this into `LAUNCH-3.0-COPY.md`'s "Buy Splynek Pro" CTA target.

### A3. Launch-week coupon

1. Dashboard → Discounts → New discount code
2. Code: `LAUNCH1` (case-insensitive in checkout)
3. Type: **Fixed amount**, **$5 off**
4. Applies to: Splynek Pro
5. Max redemptions: **1000**
6. Expires: 2026-07-08 (30 days post-launch)
7. Optional: auto-apply via URL parameter `?coupon=LAUNCH1` so the
   landing-page CTA passes it directly without users having to type
   the code

→ Output: Checkout URL with `?coupon=LAUNCH1` parameter.  Use that
  as the actual landing-page CTA target for the first 30 days; swap
  back to the bare checkout URL on 2026-07-08.

### A4. Webhook secret

1. Dashboard → Settings → Webhooks → Add endpoint
2. URL: (placeholder; you'll fill this in after deploying the
   Worker in Phase B) `https://splynek-license-server.<your-cf>.workers.dev/api/license/lemonsqueezy-webhook`
3. Events: tick **order_created** + (optional)
   **subscription_payment_success**
4. Click "Add endpoint"; LemonSqueezy generates a **signing
   secret** — copy this immediately, it shows once

→ Output: webhook signing secret in clipboard.  Used in B3 below.

### A5. Resend account (for transactional email)

Or your preferred provider — Postmark, SendGrid, SES.  Resend is
the simplest.

1. Sign up at https://resend.com
2. Add your domain `splynek.app` and complete DNS verification (SPF
   + DKIM TXT records via Cloudflare).
3. Generate an API key with **Sender** scope
4. Set up sender identity: `licenses@splynek.app`

→ Output: Resend API key.  Used in B3 below.

---

## Phase B — Worker deploy (D-10 to D-5)

### B1. Generate the Ed25519 licence-signing keypair

Run this on a trusted local Mac.  The PRIVATE key never goes into
git or any cloud-synced location.

```bash
swift -e '
import CryptoKit
let k = Curve25519.Signing.PrivateKey()
print("PRIVATE (Worker secret):", k.rawRepresentation.base64EncodedString())
print("PUBLIC  (bake into app):", k.publicKey.rawRepresentation.base64EncodedString())
'
```

→ Output: two base64 strings, one private, one public.

1. Paste the **PRIVATE** string into 1Password (or hardware key
   backup) under "Splynek Pro — Licence Signing Private Key".
2. Open `Sources/SplynekCore/ProStubs.swift` and replace
   `REPLACE_ME_WITH_LAUNCH_PUBLIC_KEY` with the **PUBLIC** string.
   Commit + push.

### B2. Generate the Sparkle EdDSA keypair

Different key from B1.  Sparkle has its own signing for DMG
integrity, separate from licences.

1. Clone Sparkle's repo or grab the prebuilt:
   `https://github.com/sparkle-project/Sparkle/releases`
2. Use the bundled `generate_keys` tool:
   ```bash
   ./bin/generate_keys
   # → A keychain entry is created + the public key is printed.
   ```
3. Open `Resources/Info.plist` and replace
   `REPLACE_ME_WITH_SPARKLE_EDDSA_PUBLIC_KEY` with the printed
   public key.  Commit + push.

The private key stays in your Mac keychain; Sparkle's `sign_update`
tool will pick it up automatically when you sign each release DMG.

### B3. Deploy the Cloudflare Worker

```bash
cd Worker/
npm install -g wrangler@latest
wrangler login

# Paste the LICENCE signing private key from B1
wrangler secret put LICENSE_SIGNING_PRIVATE_KEY

# Paste the LemonSqueezy webhook secret from A4
wrangler secret put LEMONSQUEEZY_WEBHOOK_SECRET

# Paste the Resend API key from A5
wrangler secret put RESEND_API_KEY

wrangler deploy
```

→ Output: live Worker URL like
  `https://splynek-license-server.<your-cf>.workers.dev`.

Test health: `curl https://<your-worker>.workers.dev/api/license/health`
should return `{"status":"ok","product":"splynek-pro"}`.

### B4. Wire the webhook URL back into LemonSqueezy

Return to LemonSqueezy → Settings → Webhooks → edit the endpoint
you created in A4.  Replace the placeholder URL with the real
Worker URL from B3.  Hit "Send test webhook" to confirm a 200
response.

### B5. Optional: route splynek.app/api/license/* to the Worker

Cleaner URL than `.workers.dev`.  Requires the splynek.app zone to
be on Cloudflare:

1. Cloudflare dashboard → splynek.app zone → Workers Routes
2. Add: `splynek.app/api/license/*` → `splynek-license-server`
3. Update the LemonSqueezy webhook endpoint to
   `https://splynek.app/api/license/lemonsqueezy-webhook`

Not strictly required for launch — `.workers.dev` URL works fine.

---

## Phase C — Build + sign (D-5 to D-3)

### C1. Verify both placeholders are replaced

```bash
grep -rn "REPLACE_ME" Sources/ Resources/
# Should return ZERO matches.
```

If any matches remain, the corresponding system fails silently in
production (Sparkle won't verify update signatures; licence
verification will reject every signed file).

### C2. Build the launch DMG

```bash
SIGN_IDENTITY="Developer ID Application: Paulo Moura (58C6YC5GB5)" \
ENTITLEMENTS="Resources/Splynek-DirectSale.entitlements" \
  ./Scripts/build.sh release
```

### C3. Bundle the DMG

```bash
./Scripts/dmg.sh
# → build/Splynek.dmg (rename to Splynek-3.0.0.dmg)
mv build/Splynek.dmg build/Splynek-3.0.0.dmg
```

### C4. Notarize + staple

```bash
xcrun notarytool submit build/Splynek-3.0.0.dmg \
    --keychain-profile AC_PASSWORD --wait
xcrun stapler staple build/Splynek-3.0.0.dmg
```

### C5. Sign the appcast entry

```bash
# From Sparkle's tools directory:
./bin/sign_update build/Splynek-3.0.0.dmg
# → Prints: sparkle:edSignature="<base64>" length="<bytes>"
```

Paste those two attributes + the `<enclosure url>`'s byte count
into `Worker/appcast.template.xml`'s placeholder fields.  Commit
the resulting `appcast.xml` into docs/ in this repo
(Cloudflare Pages auto-deploys to `splynek.app/appcast.xml`).

### C6. Verify the DMG launches

```bash
./Scripts/release-smoke.sh
```

Must report `✓✓✓ release-smoke PASSED` before tagging.

### C7. SHA-256 + Homebrew Cask

```bash
shasum -a 256 build/Splynek-3.0.0.dmg
```

Update `Packaging/splynek.rb`:
- `version "1.0"`
- `sha256 "<from above>"`
- `url "https://splynek.app/download/Splynek-3.0.0.dmg"`

Open a PR against `homebrew/homebrew-cask`.  Allow 1-2 days for
review + merge.

### C8. Tag + GitHub Release

```bash
git tag -a v3.0.0 -m "Splynek 3.0 — direct-sale ship"
git push origin v3.0.0

# Create GitHub Release:
gh release create v3.0.0 \
    --title "Splynek 3.0" \
    --notes-file RELEASE-NOTES-3.0.md \
    build/Splynek-3.0.0.dmg
```

(Maintainer drafts `RELEASE-NOTES-3.0.md` from the
`LAUNCH-3.0-COPY.md` § 4 list.)

---

## Phase D — Landing page (D-3 to D-2)

### D1. Update splynek.app (in-repo `docs/`)

The landing page is **`docs/` in THIS repo** (GitHub Pages with
`docs/CNAME`).  No separate `splynek-landing` repo exists.

Two v3.0 drafts are pre-staged:
  - `docs/index.v3.0.html.draft`   (main landing — hero, features,
    privacy posture, FAQ; ~590 lines, adapted from index.html)
  - `docs/pro.v3.0.html.draft`     (Splynek Pro page — 3
    `LEMONSQUEEZY_CHECKOUT_URL_GOES_HERE` placeholders for the Buy
    CTA)

Steps:

```bash
# 1. Fill in the LemonSqueezy checkout URL (from Phase A2).
#    Use the URL with ?coupon=LAUNCH1 for the first 30 days; drop
#    the coupon parameter on 2026-07-08.
sed -i '' \
    "s|LEMONSQUEEZY_CHECKOUT_URL_GOES_HERE|https://YOUR-CHECKOUT-URL?coupon=LAUNCH1|g" \
    docs/pro.v3.0.html.draft

# 2. Sanity-check: zero placeholders remain.
grep -n "LEMONSQUEEZY_CHECKOUT_URL" docs/pro.v3.0.html.draft  # must print nothing

# 3. Swap into place.
mv docs/index.html  docs/index.v2.0.1.html.archived
mv docs/pro.html    docs/pro.v2.0.1.html.archived
mv docs/index.v3.0.html.draft docs/index.html
mv docs/pro.v3.0.html.draft   docs/pro.html

# 4. Commit + push.  GitHub Pages auto-deploys (allow ~60 s).
git add docs/
git commit -m "Landing → v3.0 direct-sale launch"
git push
```

### D2. Deploy + verify

GitHub Pages auto-deploys on push to `main`.
Verify:
- https://splynek.app/ shows the new hero + the launch-window
  banner
- https://splynek.app/pro CTA opens LemonSqueezy checkout
- https://splynek.app/download/Splynek-3.0.0.dmg redirects to the
  GitHub Release asset
- https://splynek.app/appcast.xml returns the signed appcast XML

### D3. Test purchase end-to-end with a real card

Use a real card (you'll refund yourself immediately):

1. Click the CTA → LemonSqueezy checkout
2. Pay $24 (LAUNCH1 coupon applied)
3. Within 60 seconds, your email should have a `.splynekkey`
   attachment
4. Download the attachment + double-click
5. Splynek.app should activate Pro (sidebar "PRO" badge appears,
   Trust Watcher unlocks)
6. Refund yourself via LemonSqueezy dashboard → Orders → Refund

If any step fails, fix before launch.  Common issues:
- Webhook 401 → wrong LEMONSQUEEZY_WEBHOOK_SECRET in B3
- Email never arrives → check Resend dashboard for delivery /
  bounce; verify DKIM in A5
- Splynek rejects the file → public key placeholder wasn't
  replaced in C1

---

## Phase E — Soft launch (D-2 = Mon 2026-06-08)

### E1. Twitter / Bluesky / Discord posts

Post the threads from `LAUNCH-3.0-COPY.md` § "Twitter / Bluesky
launch thread" at 09:00 your local time.

### E2. Email the v0.x users

Send the email template from `LAUNCH-3.0-COPY.md` § "Email to
existing v0.x DMG users" to the consent-based list.  Use Resend
(reuses the API key from A5).

### E3. Press tier-1 cold emails

Personal note + press kit URL to:
- Federico Viticci (MacStories)
- Christian Tietze (One Mac Developer)
- Bradley Chambers (Sweet Setup)
- Jason Snell (Six Colors)

Subject line template: "Splynek 3.0 — privacy-policy auditor for
Mac, shipped direct from splynek.app today"

---

## Phase F — Show HN (D-0 = Wed 2026-06-10)

### F1. Post at 06:00 PT (= 14:00 BST = 13:00 UTC)

Use the title + body from `LAUNCH-3.0-COPY.md` § "Show HN draft".

### F2. Engage all day

Respond to comments within 15 minutes.  Don't get defensive about
the "why not MAS" framing — the audience understands.

### F3. Cross-posts at 08:00 PT

- r/macapps
- r/selfhosted
- r/privacy (if the Trust Watcher framing lands cleanly)

Wait at least 24 hours before posting to Lobsters.

### F4. End-of-day numbers report

Post a thread later that night with:
- Show HN position at peak
- # purchases (LemonSqueezy dashboard)
- # GitHub stars
- Bug reports (if any) + how you fixed them

---

## Phase G — Post-launch (D+1 to D+30)

### G1. Daily Sparkle update on errors

If anyone reports a bug, fix → bump to v3.0.1 → notarize → sign
appcast entry → push appcast.xml.  Sparkle will distribute within
the user's auto-check interval.

### G2. Weekly recap (D+7, D+14, D+21, D+28)

Blog post.  Numbers (purchases, refunds, support load).  Lessons.
Plans for v3.1 (the iPhone Companion when Apple eventually clears
+ the Concierge LLM wiring).

### G3. Coupon sunset (D+30 = Wed 2026-07-08)

Coupon expires automatically.  Update splynek.app/pro CTA to drop
the `?coupon=LAUNCH1` parameter.  Update the landing-page banner
text from "Launch week" to "Lifetime $29 once."

### G4. When MAS finally clears

1. Submit the MAS .pkg from `Scripts/build-mas.sh` to Apple
2. Once approved, add the MAS badge to splynek.app's footer +
   confirm parity ($29 same price, same features)
3. Email Pro buyers: "Splynek is now on the Mac App Store too,
   same price.  If you'd prefer auto-update via Apple instead of
   Sparkle, here's a free MAS promo code."
4. iPhone Companion: submit to iOS App Store the same week.  When
   approved, push out the v3.1 announcement.

---

## Phase H — If something goes wrong

### H1. Worker is down

Symptom: LemonSqueezy webhook deliveries failing; buyers don't get
emails.

Triage:
1. Cloudflare dashboard → Workers → splynek-license-server →
   "Logs" tab.  Look for stack traces.
2. Common cause: a secret got rotated by mistake.  `wrangler
   secret put <name>` to repaste.
3. Fallback: manually mint a licence for any waiting buyer.  Run
   the Worker source locally with `wrangler dev`, post the test
   webhook payload, email yourself the file, forward to the
   buyer.  Document in a "Splynek Pro support log" 1Password
   note.

### H2. License signature stops verifying for everyone

Symptom: buyers report "Licence signature didn't verify" after
activation.

Almost certainly a public-key mismatch between
`ProStubs.swift` (baked into the app) and what the Worker is
signing with.  Verify with:

```bash
# In the Worker secret (printed by wrangler secret list):
wrangler secret list

# In the binary:
grep -A 1 "publicKeyBase64 =" Sources/SplynekCore/ProStubs.swift
```

Fix: ensure the public-key constant in ProStubs.swift was generated
from the SAME keypair as the Worker private secret.  If you
re-generated by accident, you need to ship a point release with
the new public key.  Old buyers stay activated (their licence file
verifies against the embedded key in the version they have); new
buyers need to re-download the app.

### H3. Sparkle update breaks for someone

Symptom: a user reports "Update failed: signature didn't verify"
in a 1.0.1+ update.

Same root cause class as H2 but for Sparkle's EdDSA key.  Verify
the SUPublicEDKey in Info.plist matches the key
`sign_update` used.  If you regenerated, the user has to manually
download Splynek-3.0.0.1.dmg from splynek.app.

### H4. LemonSqueezy account is restricted

Rare but possible.  Activate the Stripe backup payment path:

1. Create Stripe account + Stripe Tax subscription
2. Replicate the LemonSqueezy product + webhook in Stripe
3. Worker has a `/api/license/stripe-webhook` route already
   scaffolded (currently 503; fill in)
4. Update splynek.app/pro CTA to point at the Stripe checkout
5. ETA from incident to switchover: 8 hours if all artifacts are
   pre-built

---

## Status tracking

Tick items as you complete them:

- [ ] A1. LemonSqueezy account verified
- [ ] A2. Splynek Pro product live in LemonSqueezy
- [ ] A3. LAUNCH1 coupon configured
- [ ] A4. Webhook signing secret captured
- [ ] A5. Resend domain + API key live
- [ ] B1. Ed25519 licence-signing keypair generated, public key in ProStubs.swift, private key backed up
- [ ] B2. Sparkle EdDSA keypair generated, public key in Info.plist
- [ ] B3. Cloudflare Worker deployed with all 3 secrets
- [ ] B4. LemonSqueezy webhook URL updated to point at Worker
- [ ] B5. (Optional) splynek.app/api/license/* routed to Worker
- [ ] C1. `grep REPLACE_ME` returns zero matches
- [ ] C2. Release DMG built
- [ ] C3. DMG bundled + renamed Splynek-3.0.0.dmg
- [ ] C4. Notarized + stapled
- [ ] C5. appcast.xml signed + deployed to splynek.app
- [ ] C6. release-smoke.sh passes
- [ ] C7. Homebrew Cask PR opened
- [ ] C8. Git tag v3.0.0 pushed + GitHub Release published
- [ ] D1. docs/index.v3.0.html.draft + docs/pro.v3.0.html.draft swapped + pushed
- [ ] D2. splynek.app deployment verified
- [ ] D3. Test purchase end-to-end passes
- [ ] E1. Twitter / Bluesky / Discord soft launch
- [ ] E2. Email to v0.x users sent
- [ ] E3. Press tier-1 cold emails sent
- [ ] F1. Show HN posted at 06:00 PT
- [ ] F2. Show HN comments engaged all day
- [ ] F3. r/macapps + r/selfhosted cross-posts at 08:00 PT
- [ ] F4. End-of-day numbers thread

**When all boxes are ticked, the launch is done.**
