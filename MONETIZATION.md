# Splynek monetization strategy

This document is an honest answer to "how does this make money?"
Written from the perspective of a single-developer Mac app in 2026.

## TL;DR

- **Model**: freemium with a one-time Pro unlock at **$29**, plus an
  optional **Splynek Teams** subscription at **$4 / user / month**
  (annual) for the small-studio / home-lab segment.
- **Distribution**: Mac App Store as the primary revenue channel
  (automated payments, refunds, updates) + direct DMG via a
  Stripe/Paddle checkout for users who avoid MAS.
- **Required investment**: **€99 Apple Developer fee** (mandatory
  for any of this — the previous "zero-risk" stance is incompatible
  with any revenue path). Domain + email: ~$30/year. Landing page:
  free via GitHub Pages. Stripe/Paddle: free at low volume, fees
  scale with sales.
- **Realistic y1 revenue**: **$5k – $40k** depending on how much
  launch signal the app gets (HN front page vs not, Product Hunt
  rank, Reddit/Twitter coverage).

## The target buyer — sharper than "power user"

I've argued across the session that the sharpest persona for Splynek
is the **small studio / home lab / multi-Mac household**: 3–10 Macs
on a LAN that routinely download the same files (Xcode, Docker
images, Ubuntu ISOs, LLM model weights, game / media builds). The
v0.20 LAN content cache was built for this buyer specifically.

Secondary personas:
- **Power developer on flaky Wi-Fi** — tethers iPhone + Wi-Fi
  simultaneously, values the multi-interface aggregation.
- **Digital creator / archivist** — downloads 50+ GB artifacts and
  wants reliability, verification, and history search.

## Pricing

### Free tier — "Splynek"

Everything we shipped up through v0.27, unlocked:
- Multi-interface aggregation (core value prop; must be visible for
  the pitch to land)
- BitTorrent v1 / v2 / hybrid
- LAN fleet cooperation + content cache (2-device limit in free —
  see below)
- Web dashboard on this Mac (no mobile access on free)
- CLI, Chrome extension, Safari bookmarklets, App Intents,
  background-first mode
- Smart enrichment + duplicate detection
- Local-AI URL resolution (if Ollama is installed)
- Benchmark panel + shareable images

Why not cripple the free tier harder? Because the app's *demo* IS
its marketing. Every running free copy is a billboard — screenshots
on Twitter, benchmark-image posts, HN threads. Paywalling the core
would kill organic spread.

### Pro tier — "Splynek Pro", $29 one-time

- **AI Concierge** — the natural-language chat interface (v0.28).
  This is new value, aligns with "AI" as the monetization hook, and
  is defensible (pulling it off well requires engineering skill the
  free competitors won't replicate quickly).
- **Mobile web dashboard** — the LAN dashboard accessible from any
  phone + QR pairing. Free tier is loopback-only.
- **Fleet beyond 2 devices** — free has a 2-device cap; Pro is
  unlimited. Small studios need ≥3.
- **Scheduled downloads** — "download between 2am and 6am", cron-
  style windows. (ships v0.29)
- **AI history search** with embeddings index (v0.29; v0.27 ships
  the in-context version for free).
- **Priority email support** — one-dev promise: answered within 48 h.
- **Lifetime updates** for the 0.x line; 1.x is a new purchase if/when.

One-time vs subscription: Mac indie buyers overwhelmingly prefer
one-time. Subscriptions work for apps with ongoing server costs
(Bear, 1Password) but Splynek has no cloud backend. Asking $29/yr
forever for a local app doesn't land.

### Team tier — "Splynek Teams", $4 / user / month annual

For the small-studio buyer specifically. Gates:
- **Shared library across Macs** — my colleague downloaded
  Xcode-16.3.dmg yesterday; my Splynek picks it up from hers
  instantly via the Team cache. Fleet-across-VPN via a
  rendezvous-server we host (requires the "private fleet" feature
  in MONETIZATION version; see the risks we flagged earlier).
- **Admin console** — per-user bandwidth caps, shared host caps,
  per-seat activity log.
- **SSO via Google Workspace + Okta** (SAML).

This tier needs operating infrastructure (rendezvous, billing,
admin) and is a v2 conversation, not v1. Target 6 months after Pro
launch.

## Distribution channels

### 1. Mac App Store — **primary**

- $29 one-time, `Pro` IAP unlocks a license key written to
  `UserDefaults[splynekPro]`.
- Apple takes 30% (15% via Small Business Program if eligible).
- Pros: automated refunds, family sharing, search, reviews, 2FA
  billing trust.
- Cons: review cycle, sandbox constraints. Splynek *will* need to
  adopt the App Sandbox entitlement for MAS — this means
  `com.apple.security.network.server` (for the fleet listener),
  `com.apple.security.network.client` (for downloads),
  `com.apple.security.files.user-selected.read-write` (for output
  directory picks), and **probably `com.apple.security.temporary-
  exception.mach-lookup.global-name`** for `com.apple.cfnetwork.AgentDictionary`
  if we keep DoH — this needs experimentation.
- The BitTorrent + fleet protocol may be a review blocker. Apple's
  history with BT clients is mixed (Transmission was pulled in
  2020). We may need to ship the MAS version **without BT +
  fleet** and keep those for the direct-DMG build only.

### 2. Direct DMG + Stripe / Paddle — **secondary**

- Landing page at splynek.app (or similar) with a Buy button.
- Stripe Checkout or Paddle — Paddle handles VAT for EU buyers,
  Stripe needs you to handle it (use Stripe Tax for +0.5%).
- License key emailed on purchase, entered in About → Unlock.
- 0% platform cut (Stripe: 2.9%+30¢, Paddle: ~5%).
- Buyers who rejected MAS (privacy-minded, want unsandboxed
  version) are the higher-LTV segment.

### 3. Homebrew cask — **free tier only**

- `brew install --cask splynek`
- Distribution via GitHub Releases. Cask template already at
  `Packaging/splynek.rb`.
- Drives install volume; conversion to Pro happens in-app.

### 4. Setapp — **optional, later**

- Setapp pays based on monthly active minutes. For a utility app
  that's occasionally-used, payout is small ($50-200/mo at most).
- Dilutes Pro sales (Setapp buyers already pay for the bundle).
- Revisit in year 2 if direct + MAS stagnate.

## Required investments (USD/EUR)

| Item | One-time | Yearly | Notes |
| --- | --- | --- | --- |
| Apple Developer Program | — | **€99** | Non-negotiable for any revenue |
| Domain (splynek.app) | — | $15–30 | .com is taken; .app is $15/yr |
| Transactional email (Postmark / Resend) | — | $15 | License emails at low volume |
| Landing page | — | **$0** | GitHub Pages |
| Stripe / Paddle | — | $0 | Flat % of sales |
| Code-signing cert | — | included in Dev Program | |
| Notarization | — | included | |
| **Total y1 out-of-pocket** | | **~€115** | |

## Realistic y1 revenue

Model a launch week + 52 weeks of residual:

**Pessimistic (no signal):**
- 2,000 installs over the year (organic + word of mouth)
- 2% convert to Pro: 40 sales × $29 = **$1,160**
- After MAS fee (30%): ~$800

**Median (decent HN + Product Hunt):**
- 25k installs y1
- 2% convert: 500 × $29 = **$14,500**
- Mix of MAS (70% of sales) + direct (30%):
  ($14.5k × 0.7 × 0.7) + ($14.5k × 0.3 × 0.97) = $7,100 + $4,220
  = **~$11,300 net**

**Good (HN front page + MacStories feature):**
- 100k installs y1
- 3% convert: 3,000 × $29 = **$87,000**
- Net ~$68,000 after platform fees.

Teams revenue on top (if shipped in y1):
- 10 teams × 5 seats × $48/yr = **$2,400/yr** at the low end.
- Needs the rendezvous infrastructure to be real before selling.

## First 90 days plan

**Day 0 (prerequisites):**
1. Pay the €99. Register as an Apple Developer.
2. Acquire domain, set up email, landing page.
3. Notarize a Developer-ID-signed build; verify right-click-Open is
   no longer needed.
4. Submit to homebrew-cask using the already-templated
   `Packaging/splynek.rb`.

**Week 1:**
- Cut a 0.29 release tagged in git, hosted on GitHub Releases.
- Publish LANDING.md content as splynek.app.
- Record a 45-second demo video (benchmark panel, fleet cache
  pairing, Concierge chat, phone scan of QR).
- Draft a Show HN post + Product Hunt launch.

**Week 2 — launch:**
- Show HN on a Tuesday or Wednesday at 15:00 UTC.
- Follow with r/macapps, r/selfhosted posts.
- Email a dozen Mac-app bloggers (MacStories, One Mac Developer,
  ATP, macrumors).
- Monitor traffic; fix what breaks in real time.

**Weeks 3–8:**
- Ship Pro gating + Stripe checkout.
- Submit to Mac App Store (will bounce once or twice; plan for
  review cycles of 2–5 days).
- Start a private beta of Teams with one friendly small studio.

**Weeks 9–12:**
- First retention / conversion data in hand.
- Price A/B test: $19 vs $29 vs $39 on the direct buyers.
- Decide whether to double-down on Teams or keep single-user focus.

## Risks / honest pitfalls

1. **The €99 → MAS review → BT-client-history rabbit hole.** Apple
   may reject the BT subsystem. Have a plan B: ship a "Splynek
   Lite" on MAS (no BT, no fleet — HTTP-only) and a "Splynek
   Full" direct-download that's the complete app.
2. **Conversion rate < 2%**. Free-to-paid conversion for
   developer tools runs 2–8%. Mac utility conversion runs 1–4%.
   If we hit <1% consistently, the free tier is too generous —
   move the web dashboard or the Concierge to Pro-only.
3. **Support load**. 500 paying customers = 10–30 support emails
   per week. At $29 one-time this barely covers the time. Team
   tier at $48/seat/yr is where the economics work for a
   single-developer-scale business.
4. **Sherlocking by Apple**. If macOS 16 ships a built-in
   multi-interface aggregator, Splynek's headline feature
   commoditizes. Defense: keep the Concierge + fleet + BT-v2
   depth as the moat.

## What makes this work — or doesn't

**Works if:** the HN + Product Hunt launch lands, a demo video goes
mildly viral, at least one Mac-focused publication writes about us.
$10–20k year-one net is very achievable.

**Fails if:** launch is quiet (no front page), no one in the press
picks it up, word of mouth doesn't compound. In that case y1 is a
rounding error and the path is either (a) iterate on ad spend,
(b) pivot harder to Teams, or (c) accept that Splynek is a portfolio
piece.

**The single most leveraged action** isn't another feature — it's
the launch video + Show HN post. Spend a week on them. Get the
motion right. The product already does the work.
