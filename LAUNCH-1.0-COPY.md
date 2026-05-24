# LAUNCH-1.0-COPY.md

> Public-facing copy for the 2026-06 direct-sale launch.  Adapted
> from `LANDING-V2-DRAFT.md` (which assumed MAS-first) to the
> direct-DMG path described in `LAUNCH-WITHOUT-APPLE.md`.
>
> **Launch window**: 2026-06-08 soft launch → 2026-06-10 Show HN.
> **Pricing**: $24 for the first 30 days, then $29 lifetime.
>
> All copy below is final-draft.  Maintainer adapts to the splynek-
> landing Hugo site's prevailing voice + drops the artwork in.

---

## Hero — above the fold

### Headline (primary)

> **Splynek knows when your apps change their privacy policies.**

### Subhead

> Multi-interface download manager + daily diff of Privacy Policies
> and Terms of Service for the apps you have installed.  100% local
> — we hash the public policy page and tell you when something
> changes.  No account.  No cloud.  No telemetry.

### Buttons

- `Buy Splynek Pro — $24` *(strike-through "$29" with a small "launch week" pill next to it)* — links to LemonSqueezy checkout
- `Get the free DMG` — links to GitHub Releases / `/download`

### Hero image

Side-by-side mock:
- **Left**: Mac TrustView showing the Trust Watcher card with 3
  alerts (Spotify Privacy Policy / Adobe ToS / Notion Privacy
  Policy)
- **Right**: an open Mail.app window with a `.splynekkey` attachment
  highlighted ("Your Splynek Pro licence — double-click to activate")

---

## Launch-window banner (top strip, dismissable)

> **Launch week: $24 for the first 1,000 buyers.**  Lifetime.  No
> account.  No renewals.  After 2026-07-08 the price returns to $29.
> [Buy now →]

---

## Section 1 — "Buy once, install everywhere"

> Splynek Pro is one purchase that covers every Mac you own.  No
> account, no seat counting, no annual renewal.

Three columns:

1. **Multi-interface download** (icon: `arrow.down.on.square`)
   - "Wi-Fi + Ethernet + cellular hotspot, all aggregated into one
     stream.  Survives bad networks, resumes across roams, verifies
     every byte against the publisher's checksum."
2. **Trust Watcher** (icon: `bell.badge`)
   - "Daily diff of Privacy Policies + ToS for popular apps.
     Material changes show up in the inbox.  Tap to read what
     changed."
3. **Sovereignty** (icon: `shield.lefthalf.filled`)
   - "Every app on your Mac, scored on data sovereignty.  See the
     EU + open-source alternatives.  Migrate Wizard walks you
     through the swap, one confirmed step at a time."

---

## Section 2 — "Coming soon: Splynek for iPhone"

> Every Pro feature on the Mac is going to surface on your iPhone
> Companion — Insights tab, home-screen widget, App Intents, push
> notifications when an app's policy changes.

> **The iPhone Companion is built, tested, and waiting on Apple's
> iOS App Store queue.**  When it ships, every existing Pro user
> gets it as a free update — no second purchase.

> We're not waiting for Apple to launch the Mac product.  But we
> won't ship to iOS until Apple's review clears.  That's a process
> they control.

---

## Section 3 — "Splynek as a programmable substrate"

> If you can write a `curl`, you can drive Splynek.  The same MCP
> server that talks to Claude Desktop also accepts persistent API
> tokens for shell scripts.

Code block (cookbook style):

```sh
# Queue a URL from anywhere on your LAN
curl -X POST -d '{"url":"https://example.com/file.iso"}' \
  "http://mac.local:55432/splynek/v1/api/queue?t=$SPLYNEK_TOKEN"

# Read your Sovereignty score
curl -s "http://mac.local:55432/splynek/v1/api/sovereignty/summary?t=$SPLYNEK_TOKEN" \
  | jq '.score'
```

Three cards linking to:

- **Raycast extension** → `Extensions/Raycast/splynek`
- **CLI cookbook** → `Extensions/CLI/README.md`
- **MCP server** → `MCP_SETUP.md`

---

## Section 4 — "What's in Splynek 1.0"

A compact list:

- **Multi-interface aggregation** — Wi-Fi + Ethernet + hotspot,
  bonded as a single download stream
- **Trust Watcher** (Pro) — daily diff of Privacy Policy / ToS for
  installed apps; inbox of material changes
- **Sovereignty** — score every app on your Mac; surface EU + open-
  source alternatives; Migrate Wizard with per-step confirmation
- **Browser Accelerator** — Chrome + Safari WebExtensions that
  redirect large downloads + HLS manifests through Splynek for the
  bonded fetch
- **yt-dlp swallow** — Splynek dispatches to your installed yt-dlp
  for YouTube/Twitch/Instagram/TikTok/X/Vimeo/Bilibili
- **File Witness receipts** — Ed25519-signed proof that a download
  happened on this Mac, with a standalone verifier
- **Fleet 2.0** — LAN peer cache with auto-join + household swarm
  token for fast intra-LAN propagation
- **Unbreakable Resume** — path-flip pause/resume with sidecar
  continuity + curated mirror failover for major Linux distros

Plus reaffirmation:

- **100% local detection** (no LLM in the diff path)
- **One-time $24** (launch week) / **$29** thereafter
- **No subscription**, lifetime updates for the v1.x line
- **No account** — Pro licence is a file you double-click
- **MIT free tier** — full multi-interface download is open source

---

## Section 5 — Privacy posture

> **One screenshot, three lines.**

Screenshot of the **Engagement viewer** in Settings — "Recording
since 2026-06-08.  Show JSON file."

> "We don't know how much you use Splynek.  We know you use it
> because we shipped a thing.  The local engagement counters live in
> `~/Library/Application Support/Splynek/engagement.json` — you
> read the same file we'd read.  We don't aggregate it.  We don't
> transmit it.  We don't have a server."

- **No telemetry.**  Ever.
- **No accounts.**  Pro is a signed file; we never see your email
  except via the LemonSqueezy purchase record (which they manage,
  not us).
- **No cloud sync of your downloads.**  Everything stays on your
  Macs.

---

## Section 6 — FAQ

**Q: How does activation work without an account?**
A: You buy at splynek.app → LemonSqueezy emails you a `.splynekkey`
file → you double-click it → Splynek verifies the Ed25519 signature
against the public key baked into the app + flips you to Pro.  No
phone-home, no DRM beyond signature verification.  Works on every
Mac you own — keep the email or 1Password the licence file.

**Q: Why direct, not the Mac App Store?**
A: Apple's v1.0 MAS re-review queue has been over a month with no
human reply.  The Mac product is finished and tested.  When Apple
clears, we'll ship to MAS as a parallel channel — but we're not
waiting for them to launch.

**Q: What about iPhone?**
A: iPhone Companion is built and tested.  Apple's iOS App Store
queue is the same bottleneck.  When it clears, every Pro buyer gets
it as a free update.

**Q: Does Splynek work on macOS 13?**
A: Yes — minimum target is macOS 13.0.

**Q: How do I get updates?**
A: Sparkle (the standard Mac auto-update framework) prompts you
when a new version ships from splynek.app.  You can also `brew
upgrade --cask splynek` if you installed via Homebrew.

**Q: Can I get a refund?**
A: Yes — 14 days, no questions asked, via the link in your purchase
email.  LemonSqueezy handles the refund flow.

**Q: What's the difference between Splynek and Splynek Pro?**
A: Free includes the full download engine — multi-interface,
torrents, browser extension, App Intents, Sovereignty viewer,
Browser Accelerator, File Witness verification.  Pro adds: Trust
Watcher (daily Privacy Policy diffs), Sovereignty Migrate Wizard,
AI Concierge, API tokens, Fleet beyond 2 devices, scheduled
downloads.

---

## Footer

- Buy at splynek.app/pro
- Free DMG → https://splynek.app/download
- Source code (free tier, MIT) → https://github.com/Splynek/splynek
- Homebrew → `brew install --cask splynek`
- MCP setup guide → https://github.com/Splynek/splynek/blob/main/MCP_SETUP.md
- Privacy policy → /privacy
- Refund policy → /refund
- Support → support@splynek.app

> Splynek Pro will be available on the Mac App Store too.  When it
> clears review.  Same price either way.

---

## Show HN draft

**Title (under 80 chars; HN trims long ones):**

> Show HN: Splynek 1.0 – Mac download manager that audits your apps' privacy policies daily

**Body** (4 paragraphs, no marketing-speak):

> I've been building Splynek as a multi-interface download manager
> for two years.  v1.0 ships today as a direct DMG download —
> Apple's MAS re-review queue went silent past day 30 and the
> product is finished, so we're shipping without them.  When MAS
> clears we'll add it as a parallel channel, but not before.
>
> The marquee feature is **Trust Watcher** (Pro): a daily diff of
> the Privacy Policies + Terms of Service of popular apps you have
> installed.  When a vendor materially changes a document, the
> Mac app shows you the diff.  100% local detection — we hash the
> public policy page, no LLM in the diff path.  Defensibility
> comes from the catalogs we've been building (Sovereignty +
> Trust), not from the model we use.
>
> The whole thing is privacy-pristine: no telemetry, no accounts,
> the Pro licence is a signed file you double-click.  Free tier is
> MIT-licensed on GitHub and includes the full multi-interface
> download engine, Browser Accelerator, Sovereignty viewer, and
> File Witness signed receipts.  Pro is a one-time $24 launch-week
> ($29 after) for the Trust Watcher + Migrate Wizard + API tokens +
> scheduled downloads + Fleet beyond 2 devices.
>
> iPhone Companion is built, tested, and waiting on Apple's iOS
> App Store queue (same bottleneck).  When it clears, every Pro
> buyer gets it free.  Happy to answer questions.

---

## Twitter / Bluesky launch thread (≤ 10 posts)

> 1. Splynek 1.0 ships today.  Mac download manager that aggregates
>    Wi-Fi + Ethernet + hotspot, audits your apps' privacy policies
>    daily, and verifies every byte with a signed receipt.  $24
>    launch week.  Direct download — Apple MAS still pending.
>    splynek.app
>
> 2. The marquee Pro feature is Trust Watcher.  Daily SHA-256 diff
>    of Privacy Policy + ToS for popular apps you have installed.
>    When Spotify quietly rewrites their data-collection clause,
>    you'll see it the next morning.  100% local, no LLM in the
>    diff path.
>
> 3. Why direct, not MAS?  Apple's review queue went silent past
>    day 30.  The product's finished.  We're not waiting.  When
>    MAS clears, parallel channel — same price either way.
>
> 4. Privacy posture: no telemetry, no accounts.  The Pro licence
>    is an Ed25519-signed file you double-click; we never see your
>    email.  Free tier is MIT on GitHub and includes the full
>    download engine.
>
> 5. Free tier on GitHub: github.com/Splynek/splynek.  $24 launch-
>    week Pro at splynek.app/pro.  iPhone Companion built, waiting
>    on Apple — free upgrade for Pro buyers when it ships.
>
> 6. Built solo in Swift, zero third-party deps.  843 tests pass,
>    catalogs cover ~95% of typical-Mac installed apps.  Show HN
>    drops Wednesday morning PT.

---

## Email to existing v0.x DMG users (consent-based list)

**Subject:** Splynek 1.0 — and a $24 launch-week price

> Hi,
>
> You installed an early version of Splynek some time in the last
> year or so.  We just shipped v1.0 and wanted to give you the
> heads-up before everyone else.
>
> What changed: the Pro tier is now anchored on Trust Watcher — a
> daily diff of the Privacy Policies + Terms of Service for the
> apps you have installed.  Same multi-interface download engine
> on the free side, but the privacy-audit Pro tier is the centre
> of the product now.
>
> What we're doing differently: instead of waiting another month
> for Apple to clear the Mac App Store review, we're shipping
> direct from splynek.app today.  $24 for the first 30 days
> (then $29), one-time payment, no account.  When MAS clears we'll
> add it as a parallel channel — but we're not waiting.
>
> If you want to upgrade: splynek.app/pro.  If you just want to
> auto-update the free tier: there's a Sparkle "Check for Updates"
> prompt in the new build.  If you bought a previous version
> through GitHub Sponsors and want a free Pro licence, just reply
> to this email.
>
> Thanks for being early.
>
> — Paulo

---

## Press contact list (cold-email order)

Tier 1 — high-signal Mac press:
- MacStories — Federico Viticci
- One Mac Developer — Christian Tietze
- The Sweet Setup — Bradley Chambers
- Six Colors — Jason Snell

Tier 2 — privacy-focused outlets:
- Ars Technica — Andrew Cunningham
- The Verge — Wes Davis
- 9to5Mac — Filipe Espósito

Tier 3 — community channels:
- r/macapps (post Tue/Wed morning PT)
- r/selfhosted (cross-post)
- r/privacy (cross-post if the Trust Watcher framing lands)
- Lobsters (only after Show HN, never both same day)

For each tier-1 contact, send a personal note + the press kit URL +
a 24-hour embargo offer if it's a slow news week.

---

## When to publish

**D-day = Wednesday 2026-06-10** (Show HN target day)

- D-2 (Mon 2026-06-08): soft launch via splynek.app, Twitter,
  Bluesky, Discord, email list above.  Press tier-1 cold emails go
  out.
- D-1 (Tue 2026-06-09): monitor.  Reply to early feedback.  Fix
  any landing-page bugs.
- D-0 (Wed 2026-06-10): Show HN goes live at 06:00 PT.  Engage
  thread all day.  Post to r/macapps + r/selfhosted at 08:00 PT.
- D+1: thank-you replies + bug-fix point release if needed.
- D+7: first weekly recap blog post: "Week 1 numbers."

All artifacts ready before D-2:
- [ ] `Sources/SplynekCore/ProStubs.swift` public-key placeholder replaced
- [ ] Worker deployed + LemonSqueezy webhook configured
- [ ] LemonSqueezy product + checkout URL live
- [ ] splynek.app/pro page updated with this copy
- [ ] `splynek.app/appcast.xml` deployed + signed
- [ ] Splynek-1.0.dmg notarized + uploaded to GitHub Releases
- [ ] Homebrew Cask PR submitted
- [ ] Test purchase end-to-end with a real card
- [ ] `Scripts/release-smoke.sh` passes on the final DMG
