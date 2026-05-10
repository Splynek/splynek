# Landing-page v2 — announcement draft

> **What this is:** copy + structure for the splynek.app landing
> page update that announces v2.0 (the full PRO-PLUS-IPHONE arc).
> Drop into the `splynek-landing` repo — adapt to the existing
> Hugo/Pages structure as needed.  The headline shifts the marquee
> from "AI Concierge" to **Trust Watcher**, with **Pro on iPhone**
> as the second pillar.
>
> **Why now:** Sprint 1-6 of PRO-PLUS-IPHONE wrapped 2026-05-10
> with 28+ commits.  Existing landing copy still leads with
> Concierge, which is no longer the strongest defensible value
> per `STRATEGY-2026-PRO-PLUS-IPHONE.md` § "Risco competitivo
> não-óbvio".

---

## Hero — above the fold

### Headline (primary)

> **Splynek knows when your apps change their privacy policies.**

### Subhead

> Daily diff of Privacy Policies + Terms of Service for the apps you have installed. Push notifications on your iPhone the moment something changes. 100% local — we hash the public policy page and tell you when the hash changes. Splynek Pro.

### Buttons

- `Get Splynek Pro on the Mac App Store` — links to MAS listing
- `Try free first` — links to GitHub Releases DMG

### Hero image

Side-by-side mock:
- **Left**: Mac TrustView with the Trust Watcher card showing 3 alerts (Spotify Privacy Policy / Adobe ToS / Notion Privacy Policy)
- **Right**: iPhone lock screen showing the corresponding push notification "Spotify — Privacy Policy changed (notable). Tap to read what's different."

---

## Section 2 — "Buy once, your whole household has Pro on every device"

> Most Mac apps charge per device or per user.  Splynek Pro is one $29 purchase that covers **every Mac in your Family Sharing group + every iPhone they're paired with**.  No "Premium Plus" tier, no seat counting, no annual renewal.

Three columns:

1. **Trust Watcher** (icon: `bell.badge`)
   - "Daily diff of Privacy Policies + ToS for popular apps. Splynek hashes the public policy page; when the hash changes you'll see the alert here. Push to your iPhone."
2. **Sovereignty Migrate** (icon: `arrow.right.arrow.left`)
   - "One-click guided swap from a paid US-controlled app to a European or open-source alternative. Each step requires your explicit confirmation; nothing is deleted."
3. **API tokens for power users** (icon: `key.fill`)
   - "Mint persistent tokens for Raycast, Alfred, BetterTouchTool, or shell scripts. Two scopes (read-only / read+write); revoke any time."

---

## Section 3 — "Pro on iPhone"

> Every Pro feature on the Mac surfaces on your iPhone Companion via the relay endpoints.  Same purchase covers both surfaces.

Demo grid (5 tiles):

- **Hey Siri, send to Splynek** — App Intent, hands-free URL submission
- **Insights tab** — Sovereignty + Trust + Trust Watcher + Recent History from your default Mac, on the phone
- **Home-screen Widget** — Sovereignty score as a hero number, traffic-light tinted
- **Geo-fence** — auto-pause when you leave home, auto-resume when you arrive
- **Push notifications** — Trust Watcher alerts on your lock screen

---

## Section 4 — "Splynek as a programmable substrate"

> If you can write a `curl`, you can drive Splynek.  The same MCP server that talks to Claude Desktop also accepts persistent API tokens for shell scripts.

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

- **Raycast extension** → Extensions/Raycast/splynek (with screenshots)
- **CLI cookbook** → Extensions/CLI/README.md
- **MCP server** → MCP_SETUP.md

---

## Section 5 — "What's new in v2.0"

A compact changelog box with the PRO-PLUS-IPHONE arc highlights:

- **NEW:** Trust Watcher (Pro) — daily diff of policies for 12 seeded apps; CloudKit-driven push to your iPhone
- **NEW:** Sovereignty Migrate Wizard (Pro) — guided swap with per-step confirmation
- **NEW:** Pro on iPhone — Insights tab, Home Widget (small + medium), App Intents, geo-fence pause/resume
- **NEW:** Apple Watch app — tap-to-pause + complications
- **NEW:** API tokens (Pro) — persistent tokens for external scripting
- **NEW:** Concierge sequences — multi-step plans with explicit per-step confirmation
- **NEW:** Engagement counters — privacy through transparency; the user reads the same JSON the gate reads

Plus reaffirmation:

- 100% local detection (no LLM in the diff path; aligns with MAS-2.5.2)
- One-time $29; no subscription; lifetime updates for the v2.x line
- Family Sharing on the Mac App Store covers every device in your household — buy once, your whole household has Pro

---

## Section 6 — Privacy posture

> **One screenshot, three lines.**

Screenshot of the **Engagement viewer** in Settings — "Recording since 2026-04-12. Show JSON file."

> "We don't know how much you use Splynek.  We know you use it because we shipped a thing.  The local engagement counters live in `~/Library/Application Support/Splynek/engagement.json` — you read the same file we'd read.  We don't aggregate it.  We don't transmit it.  We don't have a server."

- **No telemetry.**  Ever.
- **No accounts.**  Pro license is StoreKit-validated; we never see your email except via the App Store receipt.
- **No cloud sync of your downloads.**  Everything stays on your Macs + your iPhone.
- **CloudKit relay** uses your **own** private iCloud database for over-cellular submission and Trust Watcher alerts.  Apple is the transport; Splynek never sees the records.

---

## Section 7 — FAQ

**Q: Is Trust+ a thing yet?**
A: No.  We're collecting interest via the `engagementGate` in Settings.  If 90+ days of telemetry shows real engagement, we may launch a $9/yr Trust+ tier with weekly catalog refreshes + acquisition radar.  Your existing Pro purchase keeps everything you have today regardless.

**Q: Does Splynek work on macOS 13?**
A: Yes — minimum target is macOS 13.0.  Some optional features (containerBackground in widgets) require 14+.

**Q: How do I revoke API tokens?**
A: Settings → API tokens → Revoke.  External clients using that token immediately get 401.

**Q: Can I migrate from another download manager?**
A: Splynek doesn't import from JDownloader / Folx / Transmission — your in-flight downloads stay where they are.  But everything new flows through Splynek's multi-interface aggregation.

**Q: What's the difference between Splynek and Splynek Pro?**
A: Free includes the full download engine — torrents, multi-interface HTTP, browser extension, App Intents.  Pro adds: Trust Watcher, Sovereignty Migrate Wizard, AI Concierge, AI history search, scheduled downloads, mobile dashboard, API tokens, fleet beyond 2 devices, scheduled downloads.

---

## Footer

- Mac App Store badge → https://apps.apple.com/app/splynek/<id>
- GitHub Releases → https://github.com/Splynek/splynek/releases
- Source code (free tier, MIT) → https://github.com/Splynek/splynek
- MCP setup guide → https://github.com/Splynek/splynek/blob/main/MCP_SETUP.md
- Privacy policy → /privacy

---

## Press kit (separate page or `/press`)

- 1200×1200 hero PNG (Trust Watcher card + iPhone push notification)
- Splynek logo (light + dark variants)
- 5 screenshots:
  1. Mac TrustView with Trust Watcher card
  2. Mac Sovereignty Migrate Wizard sheet
  3. iPhone Insights tab
  4. iPhone home-screen Widget (medium)
  5. Apple Watch face with Splynek complication
- 60s landing video script (storyboard):
  - 0-10s: pan across messy app icons; "All your apps trust YOU. Should you trust them back?"
  - 10-25s: Mac Trust Watcher firing alert; iPhone push lights up
  - 25-40s: Migrate Wizard walkthrough Spotify → Tidal
  - 40-55s: Hey Siri demo + Watch tap-to-pause + Raycast Submit URL
  - 55-60s: "Splynek Pro. $29 once. Buy on the Mac App Store." + logo + URL
- Press contact: hello@splynek.app

---

## Show HN draft

**Title:** Show HN: Splynek 2.0 — Mac download manager that audits your installed apps' privacy policies daily

**Body** (max 5 paragraphs, no marketing-speak):

> I've been building Splynek as a multi-interface download manager for two years.  v2.0 (shipped today) pivots the Pro tier from "AI Concierge" to **Trust Watcher**: a daily diff of the Privacy Policies + Terms of Service of popular apps you have installed.  When a vendor materially changes a document, the Mac app shows you the diff and your iPhone gets a push notification.  100% local detection — we hash the public policy page; no LLM in the diff path.
>
> Why this and not Concierge?  Apple Intelligence is going to subsume Concierge-style features.  Trust Watcher is a *catalog* problem, not an LLM problem — and we've been building catalogs (Sovereignty, Trust) for two years.  Defensibility comes from the data we have, not the model we use.
>
> The iPhone Companion is a free download with the same Pro features as the Mac.  Geo-fence pause/resume, App Intents (Hey Siri, send to Splynek), home-screen widget with Sovereignty score, push notifications when ToS changes happen.  One-time $29 covers every Mac in your Family Sharing group AND their iPhones.
>
> The whole thing is privacy-pristine: no telemetry, no accounts (Pro is StoreKit-validated), CloudKit relay uses your own private iCloud database.  We even ship an "Engagement viewer" in Settings that shows you the only data Splynek collects locally — same JSON the future Trust+ gate would read.  You decide.
>
> Free tier on GitHub: <repo URL>.  $29 Pro on the Mac App Store: <URL>.  Source for the free tier is MIT.  Happy to answer questions.

---

## Maintainer adaptation notes

- The splynek-landing repo uses Hugo / GitHub Pages (per `HANDOFF.md`).  Sections 1-6 map roughly to existing sections; reword for the prevailing voice if it's tighter than this draft.
- Hero screenshots can be generated via `Scripts/capture-screenshots.sh` once the app is built; the current capture script may need a refresh for the new Trust Watcher + Insights surfaces.
- Press kit images: maintainer needs to capture or commission these.  60-second video is the highest-leverage marketing artifact per MONETIZATION.md § "What makes this work".
- Show HN draft: aim for Tuesday or Wednesday 15:00 UTC.  Cross-post r/macapps + r/selfhosted.
- Email a dozen Mac-app bloggers (MacStories, One Mac Developer, ATP, macrumors) with the press kit URL.

---

## When to publish

After:
- [ ] Mac App Store v2.0 review clears (Trust Watcher + API tokens require new review)
- [ ] DMG cut + notarized + uploaded to GitHub Releases
- [ ] Homebrew Cask PR refreshed with v2.0 SHA-256
- [ ] CloudKit `SplynekTrustWatchAlert` schema promoted to Production
- [ ] `SMOKE-TEST-RUNBOOK.md` walked end-to-end with sign-off

Coordinate with HN / PH submission — same week, ideally same day as the MAS clearance email.
