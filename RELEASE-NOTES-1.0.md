# Splynek 1.0 — release notes

> **Released 2026-06-08.**  Direct from splynek.app.  Mac App Store
> version coming when Apple's review queue clears.  iPhone
> Companion coming as a free v1.1 update with the iOS App Store
> approval.
>
> One-time **$24 launch week** ($29 thereafter).  Lifetime updates
> for the v1.x line.  No account.  No subscription.

---

## The headline

**Splynek tells you when your apps change their privacy policies.**

Daily diff of Privacy Policies + Terms of Service for popular apps
you have installed.  100% local — Splynek hashes the public policy
page; when the hash changes, the inbox flags it for you to read.

---

## Everything in v1.0

### The download engine (free + open source — MIT)

- **Multi-interface aggregation.**  Wi-Fi + Ethernet + cellular
  hotspot bonded into a single stream.  Per-interface throughput
  pinned in the menu bar.
- **Unbreakable Resume.**  Path-flip pause/resume with sidecar
  continuity.  Curated mirror failover for the major Linux distros.
- **Torrents** (BitTorrent, magnet, metainfo) with full Bencode +
  DHT + WebSeeds.
- **yt-dlp swallow.**  Splynek dispatches to your installed yt-dlp
  for YouTube / Twitch / Instagram / TikTok / X / Vimeo / Bilibili.
- **Browser Accelerator.**  Chrome + Safari WebExtensions redirect
  large downloads + HLS manifests through Splynek for the bonded
  fetch.
- **File Witness.**  Every completed download produces an Ed25519-
  signed receipt: SHA-256 of the bytes, source URL, host, timestamp.
  Standalone CLI verifier ships alongside.
- **Fleet 2.0.**  LAN peer cache with auto-join + household swarm
  token.  Up to 2 devices in the free tier; unlimited in Pro.

### Sovereignty + Trust (free)

- **Sovereignty viewer.**  Scores every app on your Mac for data
  sovereignty (where they're incorporated, where they store data,
  what regulators they answer to).  Surfaces EU + open-source
  alternatives.
- **Trust scores.**  4-axis breakdown (privacy, telemetry, vendor
  longevity, abandonment risk) for ~95% of typical-Mac installed
  apps.
- **Spotlight deep links.**  `splynek://sovereignty/<bundle-id>`
  and `splynek://trust/<bundle-id>` jump straight to the focused
  bundle from the system search bar.

### Trust Watcher (Pro)

- **Daily SHA-256 diff** of the Privacy Policy + Terms of Service
  URLs for installed apps in the Splynek catalog.
- **Material-change alerts** in a dedicated inbox under My Apps.
- **No LLM in the diff path** — Splynek hashes the public policy
  page; if the hash changes, the alert fires.  Aligns with the
  "no telemetry" posture.

### Sovereignty Migrate Wizard (Pro)

- **Guided one-click swap** from a paid US-controlled app to a
  European or open-source alternative.
- **Per-step confirmation.**  Nothing is deleted; the original app
  stays put unless you uninstall it manually.
- **Plan first, run second.**  See every step before any of them
  executes.

### Concierge + automation (Pro)

- **API tokens.**  Mint persistent tokens for Raycast, Alfred,
  BetterTouchTool, or shell scripts.  Two scopes (read-only /
  read+write); revoke any time.
- **MCP server.**  Same wire format that talks to Claude Desktop,
  consumable by any MCP client.
- **App Intents.**  "Hey Siri, send to Splynek" routing for
  Shortcuts.
- **Scheduled downloads.**  Run only inside a window you define;
  rules by day of the week + no-mobile-data option.

### Information architecture (the visible Phase v2)

- **Four lifecycle tabs**: Discover → Download → My Apps →
  Coordinate.  Each tab carries its own tint colour (blue /
  purple / pink / orange — drawn from the Splynek logo).
- **Floating-card sidebar** with the macOS 14+ NavigationSplitView
  chrome: traffic lights + sidebar toggle visually inside the
  pane.
- **First-run welcome card** with 4 colored story tiles — one per
  lifecycle moment.
- **Concierge as a sheet** ("Ask Splynek" pill on Discover + My
  Apps) — floats over context, doesn't replace it.
- **Settings / Legal / About as a gear-sheet** — Apple's macOS
  convention.
- **Installed inventory** under My Apps: every installed app, with
  Sovereignty + Trust + available updates + Trust Watcher alerts
  in one row-per-app view.

---

## What's new since the v0.x line

If you've been running an early v0.x DMG, here's the short list:

- **The whole UI was rebuilt** around the 4-tab lifecycle.  Tabs
  now teach you the workflow by their order.
- **Trust Watcher** is the new Pro centrepiece (replaces the older
  "AI Concierge" framing).
- **Fleet 2.0** + **File Witness** + **Unbreakable Resume** +
  **Browser Accelerator** all landed in the 2026 Bets sprint.
- **Pro is now a `.splynekkey` licence file** you double-click to
  activate.  No StoreKit, no account.
- **220 new translations** across pt-PT / es / fr / de / it.  L10n
  catalog at 100% coverage (948 strings × 5 locales).

---

## Privacy posture

- **No telemetry.**  Ever.
- **No accounts.**  Pro is a signed file; we never see your email
  except via your LemonSqueezy purchase record (which they manage,
  not us).
- **No cloud sync of your downloads.**  Everything stays on your
  Macs.
- **Engagement viewer** in Settings shows the only data Splynek
  collects locally — same JSON the future Trust+ gate would read.
  You see exactly what we'd see.

---

## How to upgrade from v0.x

1. Buy at https://splynek.app/pro (or skip — free tier still does
   the full multi-interface download engine + Sovereignty +
   Browser Accelerator + File Witness).
2. Within 60 seconds, you'll get an email with a `.splynekkey`
   attachment.
3. Double-click it.  Splynek activates Pro.  Done.
4. Updates flow via the new "Check for Updates…" menu item or
   automatically via Sparkle.

Already running v0.x via Homebrew?  `brew upgrade --cask splynek`
after the Cask formula PR merges (within 1-2 days of release).

---

## System requirements

- macOS 13.0 or later
- ~100 MB disk for the app + caches
- Network access for downloads (obviously) + a one-time check
  against the appcast on update polls

---

## What's still coming

- **Mac App Store version** — same product, same $29 price, when
  Apple's review queue clears.  Both channels will stay live.
- **iPhone Companion** — Share Extension, Live Activity download
  progress, Trust Watcher push notifications, home-screen widget,
  App Intents.  Built + tested; waiting on Apple's iOS App Store
  queue.  Free upgrade for every Pro buyer when it ships.
- **Apple Watch app** — tap-to-pause + complications.  Bundled with
  iPhone Companion.
- **Splynek Pro+** ($10/year add-on, post-launch) — Concierge LLM
  for natural-language queries against the catalog.  Optional,
  separate from the lifetime $29 Pro.

---

## Thanks

To everyone who ran the v0.x DMGs and filed bug reports.  To the
maintainers of Sparkle, CryptoKit, and the wider Swift Mac
ecosystem.  To the Apple reviewers who'll eventually clear the MAS
queue.  And to anyone who's ever ranted at a download manager for
losing a 4 GB ISO on a flaky hotel Wi-Fi — that's the bug we set
out to fix.

— Paulo
