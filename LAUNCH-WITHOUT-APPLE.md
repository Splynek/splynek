# LAUNCH-WITHOUT-APPLE.md

> **Strategic plan for shipping Splynek 1.0 outside the Mac App Store
> while Apple's review queue stalls past day 30.**
>
> Drafted 2026-05-24.  **APPROVED 2026-05-24** by maintainer.
> All five decisions in Section 13 locked.  This doc is now the
> canonical reference for the direct-sale launch; the technical
> execution starts immediately.
>
> **Locked decisions:**
>   1. Direction — APPROVED.  Ship Mac direct; iPhone follows.
>   2. Merchant — LemonSqueezy (merchant-of-record).
>   3. Pricing — $24 launch-window for first 30 days, then $29.
>   4. Ship dates — **Soft launch Mon 2026-06-08, Show HN Wed 2026-06-10.**
>   5. Public iPhone-delay messaging — APPROVED as drafted.

---

## 1. The TL;DR

We have **everything we need** to ship Splynek 1.0 today via direct
download + Stripe (or LemonSqueezy) for Pro purchases, with two
caveats:

1. **The iPhone Companion is App-Store-locked**, full stop.  iOS
   sideloading isn't an option for the general public.  We ship the
   Mac product now and the iPhone Companion **becomes a post-launch
   add-on** that lights up when Apple eventually clears.
2. **CloudKit-fallback over cellular** for Share Extension submits
   is App-Store-tied too (same iOS constraint).  Ship LAN-only
   pairing for the launch; CloudKit fallback re-enables when iPhone
   ships.

Everything else — sandbox-free DMG, Sparkle auto-update,
Stripe/Paddle/LemonSqueezy checkout, license keys, receipt
validation — is already a solved problem in the Mac indie
ecosystem.  We don't need MAS for the Mac side.

**Recommended path: LemonSqueezy** as merchant-of-record (handles
EU VAT + sales tax globally, 5% fee, decent UX).  Stripe is
cleaner technically but leaves us holding the VAT-compliance bag
for EU customers, which a solo dev should not be doing.

---

## 2. Why this is the right move now

- **Apple's queue is over a month deep with no human reply.**  Case
  20000113939741 was pinged 2026-05-10; today is 2026-05-24.  Day
  28+ of re-review with no signal.
- **The product is shipped.**  843 tests pass, MAS pkg + DMG both
  build clean, Mac side is feature-complete (Bet S2–S6 + IA v2 all
  landed).  We are sitting on a finished product because of a
  process we don't control.
- **Indie Mac apps have shipped outside MAS for 20 years.**  Sketch,
  Tower, Things (also offers MAS), Bartender, BetterTouchTool, the
  entire Setapp catalog.  Notarized Developer ID + Sparkle + Stripe
  is the well-trodden path.
- **Margins are dramatically better.**  MAS takes 30% (15% in year
  2 of subscriptions).  Stripe/LemonSqueezy takes 2.9% + 30¢ /
  ~5%.  On a $29 one-time purchase we keep $27.55 (LemonSqueezy)
  vs ~$20.30 (MAS).  **35% more revenue per sale.**
- **The MAS submission stays valid.**  When Apple eventually
  clears, we ship the MAS build as a parallel distribution channel
  (Tower / Things model).  No work is wasted.
- **The "100% local, no cloud, no account" pitch is strengthened**,
  not weakened, by selling direct.  Users who care enough about
  privacy to install Splynek often prefer NOT going through Apple
  ID for purchases.

---

## 3. What changes vs the current MAS plan

| Aspect | MAS plan | Direct-sale plan |
|---|---|---|
| Distribution | MAS .pkg (sandboxed) | Notarized DMG (no sandbox) + GitHub Release + Homebrew Cask + splynek.app/download |
| Pricing | $29 one-time (MAS IAP) | $29 one-time direct, or $39 with iPhone Companion later |
| Payment | StoreKit | LemonSqueezy (recommended) or Stripe |
| Receipt validation | Apple StoreKit receipts | Ed25519-signed license file (Bet S6 infrastructure already shipping) |
| Updates | MAS auto-update | Sparkle 2.x — already trivial to add |
| Refunds | Apple handles | We handle (LemonSqueezy automates 14-day refund flow) |
| Tax / VAT | Apple handles | LemonSqueezy as MoR handles all of it |
| Sandbox | Required by MAS | Off — full filesystem access, no provisioning-profile coherence pain |
| iCloud (Mac) | Available | OFF until iPhone Companion ships; doesn't affect Mac product |
| iPhone Companion | Bundles in MAS submission | **Deferred** — ships when Apple clears, as a free add-on for existing Pro license holders |
| Press / launch window | "Day Apple approves" | **We pick the date** |

---

## 4. Distribution architecture

### 4.1 Mac DMG (primary channel)

- **Build path** is already in place: `./Scripts/build.sh release`
  with the Developer ID signing identity + the right entitlements
  (NO sandbox, NO iCloud), then `./Scripts/dmg.sh`, then
  `xcrun notarytool submit` + `xcrun stapler staple`.  We've shipped
  via this path before (v1.4 / v1.5 / v1.6.2 dev builds).
- **Entitlements fork**: keep `Resources/Splynek.entitlements`
  (sandboxed, iCloud) for the future MAS build, and add
  `Resources/Splynek-DirectSale.entitlements` (un-sandboxed, no
  iCloud, Developer-ID-only).  `Scripts/build.sh` picks via env var.
- **Smoke**: `Scripts/release-smoke.sh` already verifies the .app
  launches end-to-end; that gate stays.
- **CDN**: GitHub Releases + Cloudflare Pages for the marketing
  site.  Free.  No infra to operate.

### 4.2 Homebrew Cask (secondary channel)

- `Packaging/splynek.rb` is already maintained and refreshed on
  every release.  PR it to `homebrew-cask` after each tag (same
  process the v2.0.0 prep did).
- This gives `brew install --cask splynek` to the dev / power-user
  audience, which over-indexes on the Splynek target persona.

### 4.3 Mac App Store (parallel channel, when Apple clears)

- The MAS .pkg build path is preserved as-is.  When Apple finally
  approves v1.0, we tag a corresponding MAS release and submit.
- The MAS build is functionally identical except (a) sandboxed,
  (b) iCloud entitlements ON, (c) StoreKit license manager
  instead of file-license manager.  Same source tree, different
  build target.
- Pricing parity: $29 on both channels.  Users who already bought
  direct get a free promo code redemption on MAS if they want it
  for some reason (auto-update via Apple instead of Sparkle).

### 4.4 iPhone Companion (deferred)

- Cannot sideload on iOS for general users.
- Pre-announce as "iPhone Companion coming with v1.1 — free for
  every Pro user — pending Apple's iOS App Store approval."
- TestFlight beta for early adopters once the MAS Mac side clears
  (the two reviews are independent but the iCloud-container
  provisioning happens in the same Apple Developer console flow).

---

## 5. Payment + license architecture

### 5.1 Merchant: LemonSqueezy (recommended)

Why LemonSqueezy over Stripe:

- **Merchant-of-record**: they sell the product, we sell to them.
  All VAT / sales tax / 1099-K reporting is their problem.
  Critical for a solo dev with EU customers.
- **5% + 50¢ fee** vs Stripe's 2.9% + 30¢ — small premium for the
  tax + reporting handling.
- **Built-in license-key generation + delivery.**  We don't
  operate a license server.
- **Refunds, chargebacks, dunning** — all in their dashboard.
- **Webhook-based license delivery** — fits Splynek's "no account"
  positioning.  Email-only purchase, license file delivered as an
  attachment.

Stripe is fine if we want full control + are OK doing tax compliance
ourselves (Stripe Tax is a separate paid add-on, and for the EU we'd
need an OSS or equivalent setup).  Recommend LemonSqueezy v1; we can
always migrate later.

### 5.2 License file format

Use the **Ed25519 infrastructure from Bet S6 (File Witness)**.  We
already have:

- `Sources/SplynekCore/DeviceKeyManager.swift` — Ed25519 keypair
  per device.
- The signed-receipt format Bet S6 uses for download verification.

The same primitives sign **license files**:

```json
{
  "license_id": "lic_a1b2c3d4",
  "email": "buyer@example.com",
  "product": "splynek-pro",
  "purchased_at": "2026-06-01T12:00:00Z",
  "edition": "lifetime",
  "version_cap": null,
  "public_key": "ed25519:...",
  "signature": "..."
}
```

- **Signing key** lives on our build server (or a maintainer
  machine).  Public key is **baked into the Mac app binary** at
  build time.
- The app verifies the signature on the license file at activation
  + on every launch.  Cryptographically airtight, offline-only,
  doesn't violate "100% local, no cloud, no account."
- The license file ships as an email attachment from
  LemonSqueezy's webhook.  User double-clicks it; Splynek opens
  via a custom URL scheme + activates.

### 5.3 Activation flow

1. User buys at splynek.app → routed to LemonSqueezy checkout.
2. LemonSqueezy fires webhook → our license-server (Cloudflare
   Worker — free tier) signs the license JSON, emails it to the
   buyer.
3. Buyer double-clicks `splynek-license-XXX.splynekkey`.
4. Splynek verifies signature against the embedded public key,
   stores it in Application Support, flips `LicenseManager.isPro
   = true`.
5. Done.  No phone-home, no DRM, no license-server polling.

### 5.4 Anti-piracy posture

We are **explicitly not building hard DRM.**  The license file is
signed but not bound to hardware.  Anyone with a license file can
share it.  This is the **Sketch / Tower / Bartender model**, and it
works because:

- The audience that buys is not the audience that pirates.
- The cost of building strong DRM is way higher than the revenue
  lost to casual sharing.
- A trust-first product (Splynek) actively benefits from a
  trust-first license posture.

If we see meaningful piracy after launch, we add **license-server
revocation** (a worker call on every launch with a 30-day grace
window).  Not before.

### 5.5 Refunds

LemonSqueezy automates 14-day refunds.  Our policy: **no questions
asked within 14 days.**  Standard indie Mac policy.  Refund flow
revokes the license signature in our worker (if we add the
revocation list later) and credits the customer immediately.

---

## 6. Update mechanism

**Sparkle 2.x.**  It's the canonical Mac auto-update framework,
ships with EdDSA signing (compatible with our Ed25519 work), and
takes about a day to wire up.

- Appcast hosted at `https://splynek.app/appcast.xml`.
- Update payload: notarized DMG, Sparkle-signed.
- User-facing UX: standard "An update is available" sheet on
  launch; one-click install + relaunch.

For users who installed via Homebrew Cask, `brew upgrade splynek`
remains the canonical path.  Sparkle still offers updates but
defers to the package manager when it detects a Cask install (a
known Sparkle pattern).

---

## 7. Pricing

Recommended:

- **Splynek free** — current free tier (most of the product:
  multi-interface download, Sovereignty, Trust, Browser
  Accelerator, File Witness verification).
- **Splynek Pro — $29 one-time, lifetime** — Trust Watcher (daily
  diffs of Privacy Policy / ToS for installed apps), Concierge,
  Fleet 2.0, Migrate Wizard, plus everything in the existing Pro
  schedule.
- **Future**: Splynek Pro+ — Concierge LLM (when the
  splynek-pro/Concierge LLM wiring lands), priced at +$10/year
  subscription for the AI infra costs.  NOT in the v1.0 direct
  launch.

Match the MAS price exactly ($29) so when MAS clears we don't
have a parity awkwardness.  EU VAT lands on top via
LemonSqueezy's MoR pricing (€26.99 inclusive in DE, etc. — they
auto-format).

Optional: **launch-window discount.**  $24 for the first 30 days
post-launch as a "thanks for not waiting for Apple either" promo.
Helps the initial signal + Show HN narrative.

---

## 8. iPhone Companion — what to communicate

Honesty wins here.

**Public-facing message** (landing page + Show HN + press):

> "Splynek 1.0 ships for Mac today.  The iPhone Companion (Share
> Extension + Live Activity download progress + Trust Watcher push
> notifications) is built, tested, and waiting on Apple's iOS App
> Store queue.  When it ships, every existing Pro user gets it as a
> free update.  We're not waiting for Apple to launch the Mac
> product."

This is **technically true** (the iOS targets compile, the
Bonjour pairing works, the CloudKit fallback works — we just
can't distribute) and frames the Apple delay as Apple's fault, not
ours.

**Internally:** the iPhone Companion code stays in the rollup,
gets tagged as `v1.1-iphone-pending`, and ships as soon as iOS
review clears.

---

## 9. What's already in place that makes this trivial

The 2026-05-08 → 2026-05-10 sprint sequence already built:

- ✅ Notarized DMG pipeline (`Scripts/build.sh release` + dmg.sh
  + notarytool + stapler).
- ✅ Release smoke (`Scripts/release-smoke.sh` — verifies launch).
- ✅ Homebrew Cask formula (`Packaging/splynek.rb`).
- ✅ Ed25519 signing infrastructure (Bet S6 — DeviceKeyManager +
  receipt format).  Reusable for license signing.
- ✅ `LicenseManager` abstraction (`Sources/SplynekCore/
  ProStubs.swift`).  Already swappable — MAS build substitutes a
  StoreKit version; we add a DirectSale version.
- ✅ Marketing site (splynek.app with /pro, /support, /privacy).
- ✅ Landing-v2 announcement copy (`LANDING-V2-DRAFT.md` — 215
  lines, ready to adapt).
- ✅ Show HN draft + press-kit copy (also in LANDING-V2-DRAFT).
- ✅ Mac L10n catalog at 100% (948 strings × 5 locales).

What we'd build new:

- 🟡 Sparkle integration (~1 day, well-documented framework).
- 🟡 DirectSaleLicenseManager Swift class (~half day; uses the
  Ed25519 verification we already have).
- 🟡 Cloudflare Worker for LemonSqueezy webhook → email license
  (~half day).
- 🟡 LemonSqueezy product + checkout config + webhook secrets
  (~1 hour in their dashboard).
- 🟡 Landing page "Buy Splynek Pro" CTA → LemonSqueezy hosted
  checkout (~1 hour).
- 🟡 Splynek.entitlements fork for the un-sandboxed Direct Sale
  build (~1 hour).
- 🟡 Update LANDING-V2-DRAFT.md with the new launch framing
  ("ships today" instead of "waiting on Apple"), publish (~half
  day).

**Total new work: ~3-4 dev-days.**

---

## 10. Launch timeline

If approved this week:

| Day | What |
|---|---|
| **D+0** | Approve plan.  LemonSqueezy account + product setup. |
| **D+1** | Splynek.entitlements fork + un-sandboxed build path.  Smoke. |
| **D+2** | DirectSaleLicenseManager + Sparkle integration.  Tests. |
| **D+3** | Cloudflare Worker (LemonSqueezy webhook → signed license email).  Test the buy-flow end-to-end with a real card. |
| **D+4** | Landing page update + checkout CTA wiring.  Final smoke + DMG. |
| **D+5** | Soft launch: post to splynek.app, Twitter, Discord, BlueSky.  Email existing v0.x DMG users (consent-based list). |
| **D+6** | Show HN post (Tuesday or Wednesday morning, PT).  Press kit goes live. |
| **D+7-14** | Monitor.  Bug fixes via Sparkle.  Reply to Show HN. |
| **D+21** | First weekly recap blog post: "Week 1 numbers." |

**Ship date target: 2026-06-02 (Monday after Memorial Day).**

---

## 11. Risks + mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Apple clears MAS right after we launch direct | Medium | Low | We dual-channel; no work wasted; MAS becomes a third channel alongside DMG + Cask |
| LemonSqueezy outage during launch | Low | High | Stripe as backup checkout (1-day setup if needed); cached `lemon.fail` page that explains + offers email-purchase fallback |
| License key piracy at scale | Low | Medium | Add revocation list as a Cloudflare Worker if/when we see it.  Until then, lean into trust-first posture. |
| iPhone Companion never ships (Apple keeps rejecting) | Medium | Medium | Pre-built BlueSky / Discord narrative that the Mac product is the core; iPhone is a free add-on; users aren't paying *for* iPhone |
| Sparkle update breaks on a future macOS | Low | Medium | Sparkle 2.x is well-maintained; pin to a known-good release; staple a fallback "download v1.x manually" link in the update sheet |
| EU VAT mistake | Low (LemonSqueezy handles) | High | LemonSqueezy as MoR insulates us; review their compliance reports quarterly |
| Buyer can't open notarized DMG (Gatekeeper) | Very low (stapled notarization works) | Low | Document Gatekeeper-bypass steps in /support; release-smoke already verifies Gatekeeper accepts |
| Refund abuse | Low | Low | 14-day window; LemonSqueezy auto-handles; review monthly for patterns |

---

## 12. What stays ready for when Apple clears

- **MAS build path** stays in `Scripts/build-mas.sh` — no changes.
- **iCloud + sandbox entitlements** stay in
  `Resources/Splynek.entitlements` (the existing file).
- **StoreKit license manager** stays in the MAS-specific build
  flavor.  Free for MAS buyers; Direct-Sale buyers can optionally
  redeem a free MAS code if they want auto-update via Apple
  instead of Sparkle.
- **iPhone Companion** ships as v1.1 with the iOS App Store
  approval as the trigger.  Code already complete + tested in
  simulator.
- **CloudKit-fallback over cellular** re-enables when iPhone
  Companion ships.

**Nothing in the IA v2 / Bet S2–S6 / iPhone Companion work is
sacrificed.  It just ships in two waves instead of one.**

---

## 13. Decision points the maintainer owns

Before D+1:

1. **Approve the launch-without-Apple direction.** [yes / no]
2. **Confirm the merchant choice.** [LemonSqueezy / Stripe /
   Paddle / other]
3. **Confirm the launch-window pricing.** [$29 flat / $24
   launch-window / other]
4. **Pick the launch date.** [2026-06-02 / earlier / later]
5. **Approve the public messaging on the iPhone delay.** [as
   drafted above / variant]

---

## 14. Status

- **Drafted**: 2026-05-24
- **Author**: Splynek dev session
- **Pending**: maintainer decision on Section 13
- **Successor**: once approved, this doc becomes
  `LAUNCH-1.0-DIRECT.md` (or similar) and `IA-V2-MIGRATION-STATUS.md`
  + `HANDOFF.md` are updated to point at it
- **Owner of execution**: maintainer + (this) Claude session

---

## Appendix A — LemonSqueezy vs Stripe comparison

| Aspect | LemonSqueezy | Stripe |
|---|---|---|
| Merchant of record | ✅ Yes | ❌ You are |
| EU VAT | ✅ Auto | 🟡 Stripe Tax add-on |
| Worldwide sales tax | ✅ Auto | 🟡 You / Stripe Tax |
| 1099-K / IRS reporting | ✅ They issue | ❌ You |
| Checkout UX | Hosted, good | Hosted (Stripe Checkout) or custom |
| Fee | 5% + 50¢ | 2.9% + 30¢ |
| License key generation | ✅ Built-in | ❌ DIY |
| Refunds dashboard | ✅ Yes | ✅ Yes |
| Webhooks | ✅ Yes | ✅ Yes |
| Subscriptions | ✅ Yes | ✅ Yes |
| Free trial support | ✅ Yes | ✅ Yes |
| Solo-dev friendliness | ✅ High | 🟡 Medium |

**Recommendation: LemonSqueezy** for v1.  Migrate to Stripe later
if revenue scale justifies the tax-compliance overhead.

## Appendix B — Why not Paddle or Gumroad

- **Paddle**: also MoR, comparable fees (~5%), but historically
  more enterprise-focused.  Modern Paddle is fine.  LemonSqueezy
  has better indie ergonomics + a more pleasant dashboard for solo
  devs.
- **Gumroad**: simple but takes 10% (down from the historic 9%
  + 30¢; check current).  Higher cut for less feature set.  Fine
  for a digital product fire-and-forget, but light on the license
  + webhook infrastructure we'd want.

## Appendix C — Comparable shipping models

Indie Mac apps shipping direct + (optionally) MAS in parallel:

- **Tower** (git client) — direct sale via their site; not on MAS.
- **Sketch** — direct sale only; not on MAS.  Subscription model.
- **Bartender** — direct sale via the dev's website; not on MAS.
- **BetterTouchTool** — direct sale via the dev's website; not on
  MAS.
- **Things** — both: MAS for auto-update, direct for users who
  prefer it.  Same price.
- **Soulver** — both: MAS + direct, same price, same feature set.
- **Setapp** — entire subscription catalog of Mac apps,
  distributed outside MAS.

All of these have shipped for years, all are profitable, none have
suffered from being outside MAS.  The market is comfortable with
direct-purchase Mac apps.

---

**End of plan.**
