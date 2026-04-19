# Splynek changelog

A condensed one-line-per-release log. For details, see the relevant
`## What's new in v0.N` section in [README.md](README.md).

## v0.47 — P3 polish + tooltips pass (2026-04-19)

- **Queue → Summary card redesigned.** Hero count (40pt) + state-
  aware subtitle + colour-dot pills + contextual action bar
  (Retry all failed / Clear finished). New `vm.retryAllFailed()`
  method saves click-through after Wi-Fi blips kill a batch.
- **Tooltips pass** — 12 new `.help()` strings on jargon controls.
  "Connections per interface" + ⓘ icon explains the 1–8 trade-off.
  "Per-interface DoH" gets a full paragraph on what DNS-over-HTTPS-
  per-interface actually buys. Metalink / Merkle buttons explain
  file-format semantics.
- **New `labelWithInfo(_:tooltip:)` helper** in DownloadView —
  caption label + small ⓘ icon with hover tooltip. Drop-in for
  future tooltip additions.
- **Dev-override flag for Pro audit.** `splynekDevProUnlocked`
  UserDefaults key bypasses the StoreKit gate in
  splynek-pro/LicenseManager. Lets reviewers + QA test Pro features
  without a real $29 sandbox IAP. Documented in ASC review notes.

## v0.46 — P1 + P2 pre-submission QA (2026-04-19)

P1 bugs (would have earned an App Review rejection):

- **Pause no longer looks cancelled.** Clear errorMessage on the
  paused branch of `DownloadJob.settleAfterRun()`.
- **Phase resets on pause/cancel.** `progress.phase = .pending` on
  every non-completed exit.
- **Trash icon works on paused jobs.** `removeJob()` cancels the
  engine inline and removes regardless of isActive state.
- **Bad-URL error visible.** Moved inline into Source card, below
  Start button. Probe errors get human-actionable hints
  ("HTTP 404 — the file doesn't exist at that URL.").
- **Throughput no longer fantasy GB/s.** Clamped LaneStats window
  divisor to 0.5 s minimum (was 0.001 s).

P2 polish:

- **Phase pills readable.** Icon-only for past/future, icon + label
  for current; `.help()` tooltip on every pill.
- **iPhone USB tether detected + labeled.** New `.iPhoneUSB`
  interface Kind, detected by 172.20.10.0/28 IP range. Icon
  `iphone`, label `iPhone`, cyan tint. Metered for cellular budget.
- **Wi-Fi icon blue (was yellow).** Matches macOS Wi-Fi styling.
- **Queue 3-dots menu enriched.** Retry / Open URL / Copy URL /
  Remove per state (previously often one item → looked empty).
- **Duplicate Start/Queue toolbar buttons removed.** Keyboard
  shortcuts moved to the Source card buttons.
- **Benchmark Run button surfaced inline.** Below the target URL,
  not tucked in the toolbar.
- **History row actions 3 → 2 icons.** Details + Reveal; Quick Look
  in context menu only.
- **Fleet per-file "Stop sharing"** button + persisted exclusion
  list + "Restore all" link.
- **About logo shrunk** 128 → 88 px.

Notarisation shipped:

- Apple Distribution + Developer ID Application certificates in
  keychain.
- `notarytool` keychain profile `AC_PASSWORD` set up.
- DMG re-signed with Developer ID, notarised, stapled, uploaded as
  the GitHub Release asset. No more right-click-to-open dance.
- MAS .pkg built + Apple-Distribution-signed + uploadable via
  Xcode Organizer.

## v0.45 — MAS build infrastructure (2026-04-19)

- **Xcode project** (`project.yml` → `xcodegen generate` → `Splynek.xcodeproj`)
  with two targets: `Splynek` (DMG) + `Splynek-MAS` (sandboxed).
- **Direct-source compilation** in the MAS target: excludes stubs,
  includes sibling private `splynek-pro/Sources/SplynekPro/`. No
  cross-module public-access refactor needed.
- **Sandbox entitlements** (`Resources/Splynek-MAS.entitlements`):
  app-sandbox + network.client + network.server + file pickers +
  bookmarks.app-scope.
- **StoreKit 2 LicenseManager** (in splynek-pro): replaces HMAC with
  Apple-enforced IAP. `Transaction.updates` listener; refund-aware;
  offline-usable via cached entitlements.
- **MAS-specific Pro card** in SettingsView (`#if MAS_BUILD`):
  StoreKit "Buy — $29" + "Restore Purchase" replace the email+key form.
  DMG build's free-tier card now points at the Mac App Store.
- **`#if !MAS_BUILD` guards** on `GlobalHotkey` + `UpdateChecker` —
  both rejected for MAS sandbox; no-op stubs keep call sites clean.
- **Local StoreKit test config** (`Resources/Splynek.storekit`)
  simulates the $29 IAP for dev without submitting to ASC.
- **`Scripts/build-mas.sh`** — one-command MAS archive build with
  prerequisite checks + `Scripts/export-options-mas.plist`.
- **New docs pages**: `docs/support.html`, `docs/privacy.html`,
  `docs/pro.html`. Required URLs for ASC submission.
- **`MAS_LISTING.md`** — copy-paste ASC submission material: 2.2k-char
  description, keywords, review notes, privacy labels, 15-item
  submission checklist.
- Three build paths all pass 117 tests: SPM, Xcode DMG, Xcode MAS.

MAS v1 limitations (tracked for v0.46+): no global hotkey, no
`splynek-cli` helper, no self-update banner, no DMG→MAS data
migration on first launch. DMG users keep all four.

## v0.44 — Public/private split (2026-04-18)

- **Pro code moved to private `Splynek/splynek-pro` repo**: closes
  the bypass vector where anyone could clone the MIT repo and edit
  `isPro = true`. Future Pro features land in the private repo.
- Moved: `LicenseManager`, `AIConcierge`, `AIAssistant`,
  `DownloadRecipe`, `DownloadSchedule`, `ConciergeView`,
  `RecipeView`, `ProLockedView`, `Scripts/gen-license.py`,
  4 test suites.
- **`Sources/SplynekCore/ProStubs.swift`** provides API-compatible
  free-tier stubs: `isPro` always false, AI methods throw,
  schedule always `.allowed`, recipe store is empty no-op.
- Public build compiles identically against stubs; MAS build swaps
  them for real implementations at Xcode-target-exclusion level.
- **`splynek-pro/SANDBOX_AUDIT.md`** — six code changes needed for
  MAS review (global hotkey, CLI, Fleet entitlement, data migration,
  watched folder bookmarks, UpdateChecker).
- Tests: 165 → 117 (48 moved to private repo).
- DMG: 2.5 MB → 2.3 MB (~1,400 LOC lighter).

## v0.43 — QA pass (2026-04-18)

- **P1**: Assistant + Recipes tabs wedged NavigationSplitView (blank
  detail + empty sidebar, full-restart required). Root cause:
  SwiftUI on macOS 14 miscomputes layout when a destination view's
  body has a top-level conditional with structurally different
  subtrees. Fix: move Pro gate to sidebar — tabs don't render for
  free users; "Unlock AI tools" row jumps to Settings.
- **P1**: `RecipeParser.isNonDownloadableHost(...)` rejects App
  Store / iTunes / Play Store / MS Store URLs client-side + prompt
  explicitly forbids them. Was causing silent queue failures.
- Goal text clears after successful recipe generation.
- Queue rows: COMPLETED shows `"took Xs"`, FAILED/CANCELLED hide
  the clock, PENDING/RUNNING keep "added X ago".
- Queue Summary icon: `chart.bar` → `list.clipboard` (was reading
  as Wi-Fi signal strength).
- `formatRelative(_:)` clamps sub-minute to "just now"; forces
  `en_US_POSIX` locale so abbreviations don't mix with
  system-locale connectors.
- Magnet display names: `+` → space before percent decode;
  `%2B` still round-trips as literal `+`.
- `DownloadEngine` reconciles `HostUsage.credit` on completion if
  lane-level crediting undercounted.
- Usage-timeline chart: private IPs render as "LAN (x.x.x.x)".
- Launch-at-login error rewritten to actionable guidance.
- Toolbar `.help(...)` tooltips on every Downloads toolbar button.
- Inline Start / Queue buttons in the Downloads source card.
- 5 new tests + 1 fixture updated. Suite at 165 green.

## v0.42 — Agentic Download Recipes (2026-04-18)

- `DownloadRecipe` + `RecipeItem` — structured plan output from the
  local LLM: name, url, homepage, sha256, sizeHint, rationale,
  confidence (0–1), selected.
- `AIAssistant.generateRecipe(goal:)` — few-shot prompted, JSON-
  formatted, temperature 0.2, 90s timeout. Returns a parsed recipe.
- `RecipeParser` — tolerant of markdown fences + LLM prose; strict
  about URL scheme, required fields, confidence clamping, SHA-256
  format. Invalid items dropped; all-invalid throws `.noItems`.
- `RecipeStore` — persisted recent recipes (capped at 20) under
  `~/Library/Application Support/Splynek/recipes.json`.
- `RecipeView` — new sidebar tab between Assistant and Queue.
  Goal editor + generated checklist + recent-recipes history.
  Pro-gated.
- 19 new tests in `RecipeParserTests`. Suite now at 162 green.
- End-to-end verified against `llama3.2:3b`: 4 items for iOS dev
  setup in 12 s; 3 items for Ubuntu + VS Code + Docker in 7 s.

## v0.41 — Pro license gating (2026-04-18)

- `LicenseValidator` pure offline HMAC-SHA256 key issuance +
  validation. `SPLYNEK-AAAA-BBBB-CCCC-DDDD-EEEE` format.
- `LicenseManager` ObservableObject persists the key + email,
  re-validates on launch, ignores hand-edited invalid persistence.
- `ProLockedView` — reusable paywall card.
- Gates at four call sites: scheduled downloads, AI Concierge, AI
  history search (HistoryView + DownloadView rows), LAN web
  dashboard (FleetCoordinator `proGateForcesLoopback`).
- Splynek Pro settings card at the top of Settings — Buy / activate
  / deactivate flow.
- `Scripts/gen-license.py` — server-side key issuance tool that
  matches Swift byte-for-byte (pinned by a test fixture).
- 13 new tests in `LicenseValidatorTests`. Suite now at 146 green.
- Fleet 2-device cap + MAS StoreKit IAP deferred to v0.42.

## v0.40 — Torrent session restore (2026-04-18)

- `TorrentWriter.preallocate()` is now idempotent — preserves
  existing bytes on disk. Fixes silent partial-progress loss across
  app restarts.
- `PieceVerifier` extracted from `PeerCoordinator.acceptPiece` with
  a `resumeMode` flag. Shared between the swarm and the resume
  scanner.
- `TorrentResume.scan(info:rootDirectory:)` — pure piece-by-piece
  disk verifier returning verified indices + bytes recovered. New
  Sendable-friendly `TorrentWriter.read(...)` static helper so the
  scan dispatches cleanly to a background queue.
- `TorrentEngine.run()` inserts a `"Verifying existing pieces…"`
  phase between announce and swarm. Fully-restored torrents skip
  the swarm entirely and go straight to completion + optional seed.
- Cancel flag polled between pieces so abort is prompt.
- 9 new tests in `TorrentResumeTests`. Suite now at 133 green.

## v0.39 — Finer Gatekeeper signature panel (2026-04-18)

- `GatekeeperDetail` struct + pure `parseDetail(...)` over spctl /
  codesign / stapler merged output. Extracts source, origin,
  authority chain, team ID, CDHash, and notarization-stapled state
  (with nil for offline-inconclusive).
- `evaluateDetail(_:)` async wrapper runs the three tools and
  returns the parsed struct (nil for non-evaluable file types).
- Signature card in HistoryDetailSheet (only for .app/.pkg/.dmg/.mpkg):
  named fields + ACCEPTED / REJECTED pill + raw-output disclosure.
- 7 new tests in `GatekeeperDetailTests` pin the field extraction
  against realistic canned tool outputs.
- Suite now at 124 green.

## v0.38 — Usage timeline chart (2026-04-18)

- `UsageTimeline` — pure data-shaping helpers; top-N hosts across
  the window with alphabetical tiebreak, `"Other"` rollup, today-
  first ordering. Cellular variant splits over-cap days into a
  separate series colour.
- `UsageTimelineView` — SwiftUI Charts stacked bar chart with a
  Host / Cellular segmented picker, a window-days menu (7/14/30/60/90),
  CSV export button. Today's bar draws at full opacity; history at
  0.78.
- Wired into HistoryView between the Lifetime summary and the
  Today-by-host card.
- 10 new tests in `UsageTimelineTests`. Suite now at 117 green.

## v0.37 — CSV export (2026-04-18)

- `HostUsage` + `CellularBudget` now snapshot yesterday's counters
  into per-domain history logs before the midnight roll-over.
  `host-usage-history.json` and `cellular-budget-history.json` both
  cap at 365 days.
- `UsageCSV` — pure RFC 4180 formatter with proper comma / quote /
  newline quoting. Today's state first, history reverse-chronological,
  hosts sorted by bytes desc within a day.
- Export buttons on the Today-by-host card (History view) and the
  cellular budget row (Downloads view). NSSavePanel with dated
  filenames.
- 18 new tests in `UsageCSVTests`. Suite now at 107 green.

## v0.36 — Phase over REST (2026-04-18)

- `LocalState.ActiveJob.phase` — new String field sourced from
  `DownloadProgress.Phase.rawValue`. Exposed on `/splynek/v1/api/jobs`.
- Per-job Combine subscription on `$phase` republishes fleet state on
  each transition so fast loopback downloads don't compress through
  the 2 Hz timer.
- OpenAPI spec lists `phase` as required on ActiveJob with an enum
  of all eight canonical values.
- CLI `splynek status` gains a PHASE column; decodes phase as optional
  so it stays compatible with pre-v0.36 Splyneks.
- `Scripts/integration-test.py` now asserts the phase trail is a
  monotonic subsequence of the canonical pipeline; 100 ms poll.
- 4 new tests in `PhaseOverRESTTests`. Suite now at 94 green.

## v0.35 — Integration tests + Watched folder (2026-04-18)

- `Scripts/integration-test.{sh,py}` — end-to-end REST test: stdlib
  HTTP server → POST `/api/download` → poll jobs + history → SHA-256
  compare. Binds server to primary LAN IP so Splynek's
  `requiredInterface`-pinned outbound request hairpins correctly.
- `WatchedFolder` polled ingester (5 s Timer, 2 s file-age floor)
  with `processed/` move-on-handle. Accepts `.txt` (one URL /
  magnet per line, `#` comments), `.torrent`, `.metalink` / `.meta4`.
- Settings card for watched folder: toggle, folder picker,
  Reveal-in-Finder.
- `watchEnabled` / `watchFolderPath` persist in UserDefaults; init
  resumes the watcher so toggle-on survives restarts.
- 8 new tests in `WatchedFolderTests` for the pure `.txt` parser.
  Suite now at 90 green.

## v0.34 — Scheduled downloads (2026-04-18)

- `DownloadSchedule` model — enabled + start/end hour + weekday set +
  pauseOnCellular. Persisted as `schedule.json`.
- Pure `evaluate(...)` → `.allowed` / `.blocked(reason, nextAllowed)`
  handles simple windows, midnight-wrapping windows, weekday masks,
  and cellular pausing.
- `runNextInQueue()` gates on the schedule; a 60-second retry timer
  wakes the queue automatically when the window opens.
- Settings card with hour pickers, weekday chips (Mon→Sun ordering),
  cellular-pause toggle, and a live "window is open / next opening
  in 3h" status row.
- Queue view badges the head-of-queue entry with WAITING + "Next
  opening in 4h" when the schedule is blocking.
- 16 new tests in `DownloadScheduleTests` pin every evaluator branch
  in a timezone-independent UTC calendar. Suite now at 82 green.

## v0.33 — Torrent Live (2026-04-18)

- `TorrentLiveCard` on the Live dashboard: 72-pt throughput headline,
  canonical six-phase pipeline strip (announcing → fetchingMetadata →
  connecting → downloading → seeding → done), pieces / peers metrics,
  ENDGAME + SEEDING pills, inline seeding strip (port / leechers /
  uploaded / uptime), cancel control.
- `TorrentLivePhase.infer(...)` — pure phase-mapper collapsing the
  engine's freeform `progress.phase` strings (plus piece/finished/
  seeding state) onto the pill set; fully unit-tested.
- `TorrentRateSampler` — 1-Hz sampler over an 8 s rolling window
  derives a smoothed bytes/sec from `progress.downloaded` deltas.
- Live view empty state now keys on HTTP + torrent activity jointly.
- 10 new tests in `LiveTorrentPhaseTests`; suite now at 66 green.

## v0.27 — Platform pass (2026-04-17)

- Documented REST API at `/splynek/v1/api/*` with embedded OpenAPI
  3.1 spec at `/splynek/v1/openapi.yaml`.
- `splynek` CLI binary (new SPM target `splynek-cli`) with
  `download`, `queue`, `status`, `history`, `cancel`, `openapi`,
  `version` subcommands.
- Raycast extension (`Extensions/Raycast/`) — three commands.
- Alfred workflow (`Extensions/Alfred/`) — `dl`, `dlq`, `dlstatus`.
- Three new App Intents: `CancelAllDownloads`, `PauseAllDownloads`,
  `ListRecentHistory`.
- AI history search — natural-language query via Ollama, ranks
  entries by relevance.
- Benchmark panel *Save image…* button — 1200×630 PNG OG-card.
- Distribution: `Scripts/dmg.sh` for DMG build; Homebrew cask
  template at `Packaging/splynek.rb`; `LANDING.md` + `CHANGELOG.md`.
- Fleet descriptor (`~/Library/Application Support/Splynek/fleet.json`)
  written on listener-bind so the CLI / Raycast / Alfred discover
  port + token without env-var plumbing.

## v0.26 — Credibility sprint

- Self-hosted test runner (no XCTest dep); 47 tests across Merkle,
  Bencode, magnet parsing, BEP 52 verification, duplicate
  detection, sanitization, web dashboard, QR codes.
- Package split into `SplynekCore` library + `Splynek` executable
  shim so tests can `@testable import`.

## v0.25 — Local-AI download assistant

- Ollama detection + natural-language URL resolution in the
  Download view.

## v0.24 — Web dashboard (the splash)

- Mobile-friendly HTML dashboard served from the fleet HTTP port.
- QR-code pairing via `About → Web dashboard`.
- `POST /splynek/v1/ui/submit?t=<token>` endpoint.

## v0.23 — Smart enrichment

- Pre-start duplicate detection.
- Seven parallel sibling HEAD probes (`.sha256`, `.asc`, `.sig`,
  `.torrent`, `.metalink`, `.meta4`, `.splynek-manifest`).
- Auto-apply `.metalink` + `.splynek-manifest` when found.

## v0.22 — Background-first

- Menu-bar-only mode (`NSApp.setActivationPolicy(.accessory)`).
- Launch at login via `SMAppService`.
- Menu-bar quick-drop popover + drag-to-icon.

## v0.21 — Browser-scale distribution

- Chrome extension (Manifest V3) + Safari bookmarklets.
- Bundled into `.app` + revealed from AboutView.

## v0.20 — LAN content cache

- Unconditional SHA-256 on completion.
- `/splynek/v1/content/<hex>` content-addressed endpoint.
- Cooperative partial-chunk trading between in-flight downloads.
- Engine handles 416 as per-mirror requeue (no lane health hit).

## v0.19 — BitTorrent v2 + fleet

- BEP 52 parser + SHA-256 Merkle piece verification.
- `urn:btmh:1220<hex>` magnet support.
- `FleetCoordinator` — Bonjour discovery + `/status` + `/fetch`.

## v0.18 — Benchmark panel

- Side-by-side single-path vs multi-path bar chart.

## v0.17 — "Flaky internet rescue"

- Lane auto-failover on healthScore decay.
- Per-download speedup report.
- Lifetime time-saved counter.
- Interface preference learning.
- Connection-path transparency.
- `.splynek-manifest` publisher.

## v0.16 — Per-host daily caps

- Editable GB-per-day caps per host; enforced at spawn time.

## v0.15 — Self-download for updates + per-host tally

## v0.14 — Quick Look + update check + BT tit-for-tat + cellular budget

## v0.13 — `GetDownloadProgress` intent + Spotlight + BT choking + torrent resume

## v0.12 — App Intents + per-lane RTT + seeding keepalives

## v0.11 — Session restore + queue export/import + ⌘L

## v0.10 — Shared per-interface bandwidth buckets

## v0.9 — Concurrent downloads

## v0.8 and earlier — foundational pass

- Multi-interface aggregation, NWConnection-bound lanes
- Chunked range GETs, keep-alive reuse
- Gatekeeper + quarantine
- HTTP + UDP trackers, DHT, PEX, magnet (BEP 3/6/9/10/11)
- Seeding service
- Metalink mirrors
- DoH per-lane
