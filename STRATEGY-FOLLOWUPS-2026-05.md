# Strategy bets — post-rollup follow-ups

> Snapshot 2026-05-05.  Companion to STRATEGY-2026.md.  Captures
> where each strategy bet sits AFTER the v1.6.2 → next-release rollup
> arc, plus the concrete "what's next" per bet so a session can pick
> any one up cold.

## Status snapshot

| Bet | Description | Status |
|---|---|---|
| **S1** — Apple Foundation Models Concierge | On-device LLM as primary AI engine | ✅ **Shipped** v1.1+ + Concierge-as-Mac-Assistant in current rollup |
| **S2** — Unbreakable Resume + Mirror Failover | NWPathMonitor pause/resume + curated mirrors | ✅ **Shipped** in current rollup (PathMonitorObserver + MirrorManifest for Ubuntu/Debian/Fedora; resume-button bug fixed in `8a2940b`) |
| **S3** — yt-dlp swallow | Bundle yt-dlp + one-paste any-URL | 🟡 **Not started.** Pre-flight done in current rollup: PublisherPattern is the digest-extraction surface; yt-dlp invocation surface is separate. Most-feasible kickoff below. |
| **S4** — iPhone Companion | iOS Share Extension + Live Activity | 🔴 **Not started.** Needs new iOS Xcode project. Multi-week build. |
| **S5** — Splynek Accelerator (browser extension + HLS pre-buffer) | Multi-interface bonding for any browser big-download | 🔴 **Not started.** Browser extension stubs exist in `Resources/extensions/` but no Accelerator logic yet. |
| **S6** — File Witness (cryptographic receipts) | Per-download Ed25519-signed receipts | 🔴 **Not started.** Trust + Sovereignty exports cover adjacent territory. |
| **S7** — Sovereignty tab | App-origin scanner + EU/OSS alternatives | ✅ **Shipped** v1.2+, 1155-entry catalog, CSV export added in current rollup |

## What "started" looks like for each open bet

### S3 — yt-dlp swallow

Most-feasible kickoff:

- [x] **Detection probe.**  Add a `YtDlpProbe` that resolves `which
      yt-dlp` (or `~/.local/bin/yt-dlp`) and reads `--version` to
      detect a user-installed binary.  No bundling, no auto-update —
      just "if you have it, we use it; if not, we tell you how."
      One-day implementation, zero MAS-review risk.  Started 2026-05-05
      (see commit alongside this doc).
- [ ] **Dispatch wiring.**  When the user pastes a YouTube /
      Twitch / Instagram / TikTok URL and `YtDlpProbe.isAvailable`,
      route through yt-dlp instead of the direct-HTTP engine.  UI
      surface: Source view shows "Splynek detected: yt-dlp" badge.
- [ ] **Bundle path (MAS).**  yt-dlp is MIT-licensed, but bundling a
      Python binary inside a sandboxed MAS app requires (a) shipping
      a stripped-down Python runtime or (b) using yt-dlp's `pyinstaller`
      single-file build.  Either way Apple will scrutinize the
      additional binary at review.  Defer until DMG-build-only first.
- [ ] **Auto-update via Background Assets.**  yt-dlp ships ~weekly.
      `BackgroundAssets` is the right framework; no entitlement
      needed for app-bundled assets.

### S4 — iPhone Companion

Pre-flight:

- [ ] Create `Splynek-Companion.xcodeproj` (or extend the existing
      project as a second target) with iOS deployment target 17+.
- [ ] Implement Share Extension that publishes URLs to Splynek's
      Bonjour service (already running, port `webDashboardURL()`).
- [ ] Live Activity scaffold using ActivityKit.

Estimate: 3–4 weeks of focused iOS work.  Cannot be started without
a dedicated iOS development push.

### S5 — Splynek Accelerator

Pre-flight (already partly done):

- [x] `Resources/extensions/` skeleton exists (Chrome + Safari).
- [ ] Browser extension manifest needs the bonded-download intercept
      logic.  When user clicks a `Content-Length > 50 MB` link in a
      browser, redirect to `splynek://` URL handler.
- [ ] HLS pre-buffer is the harder piece — needs a local SOCKS-or-
      HTTP-proxy that rewrites manifests + serves segments from a
      ring buffer.

Estimate: 6–8 weeks for full S5 with HLS pre-buffer; 2 weeks for
just the "intercept big downloads in browser" part.

### S6 — File Witness

Smallest of the open bets:

- [ ] Generate per-device Ed25519 keypair (`CryptoKit` + Keychain).
- [ ] On every download `verify` phase, sign a JSON receipt
      `{url, sha256, size, timestamp, device_pubkey}` with the device
      private key.
- [ ] Add "Export receipt" action to `HistoryDetailSheet`.
- [ ] Trust catalog page documenting how to verify receipts (open-
      source verifier script).

Estimate: 3–5 days.  Could land in the next-release rollup if
prioritized.

## Recommendation

If picking ONE bet to push next: **S6 — File Witness** is the highest
value-per-effort.  3–5 days of focused work, single-developer feasible,
no operational dependencies, hits a real journalist/academic audience
that current Splynek under-serves.

S5's "intercept big browser downloads" first half is the next-most-
feasible: 2 weeks, uses existing browser-extension scaffolding, no
HLS-pre-buffer complexity.

S3's yt-dlp detection probe started in this commit-arc is the
no-risk pre-flight — when MAS reviews tighten, the DMG build can
ship the yt-dlp dispatch path independently.

S4 requires a deliberate iOS push and shouldn't be sprinkled in.

## What this doc replaces

- The "S2/S5 frontier bets" line in HANDOFF.md is now stale — S2
  is shipped.  HANDOFF should reference this doc instead of listing
  bet states inline (which drift).
- STRATEGY-2026.md covers the "why" each bet exists.  This doc covers
  the "where they are right now + how to start the next one."

## Versioning policy reminder

Per `splynek_versioning_policy.md` (set 2026-05-05): **don't open new
sub-version branches** for any of these bets.  When S3 / S4 / S5 / S6
ship, they pile into the existing "next-release rollup" until the
maintainer picks a tag.
