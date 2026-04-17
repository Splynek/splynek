# Splynek handoff

Native macOS multi-interface download aggregator. Pure Swift, zero
third-party deps. SPM package with three executable targets
(`Splynek` app, `splynek-cli`, `splynek-test`) + one library
(`SplynekCore`). ~12k LOC across ~55 files.

**Working directory:** `/Users/pcgm/Claude Code`
**Git:** initialised locally on `main`. Tag `v0.31` exists. **No remote
set — nothing pushed yet.** Working tree is clean at the top of
every session.
**Build:** `./Scripts/build.sh` → `build/Splynek.app` (ad-hoc signed)
**DMG:** `./Scripts/dmg.sh` → `build/Splynek.dmg` (ad-hoc signed, ~2 MB)
**Run:** `open build/Splynek.app`
**Tests:** `swift run splynek-test` (58+ tests, all green)
**CLI:** `swift run splynek-cli version`

**Current version:** 0.32 — distribution pass (git + LICENSE +
CONTRIBUTING + `docs/index.html` + `SHOW_HN.md` + DMG + tag). See
README.md for the full reverse-chronological feature log from
v0.1 to v0.32.

---

## Start-of-session ritual

1. `Read HANDOFF.md` (this file)
2. `Read README.md` (top 200 lines covers the latest few releases)
3. Check `git status` + `git log --oneline -10` to see any
   uncommitted / unpushed work.
4. Ask the user what to build. Don't invent work — the
   **Natural next bites** section below has an ordered queue.

---

## Architecture invariants

Load-bearing; don't break them without explicit intent.

1. **Interface binding.** Every outbound data socket is pinned to a
   `NWInterface` via `NWParameters.requiredInterface` (Apple's
   wrapper for `IP_BOUND_IF`). DoH for each lane optionally goes
   through the same interface via `DoHResolver` (Cloudflare
   1.1.1.1, JSON format). Tracker announces for torrents use
   `HTTPTrackerOverNW` so tracker DNS obeys the interface too.
2. **Zero third-party Swift dependencies.** `Package.swift` has
   no external products. BitTorrent, DHT, DoH, Metalink XML, the
   test harness, the SVG rasteriser, PNG generation — all
   hand-rolled against Foundation, Network.framework, CryptoKit,
   AppKit, CoreImage.
3. **ViewModel owns shared mutable state.** `SplynekViewModel`
   (`@MainActor ObservableObject`) holds `activeJobs`,
   `sharedBuckets`, `queue`, `history`, `torrentProgress`, AI
   state, Concierge chat, fleet integration, and preferences.
   Engines publish to it via `@Published`; engines never touch
   `DockBadge` or UI directly.
4. **Session state** lives in `~/Library/Application Support/Splynek/`:
   - `history.json` — completed downloads (last 500, with SHA-256)
   - `queue.json` — persistent URL queue
   - `session.json` — jobs + last torrent snapshot
   - `dht-routing.json` — 200 most-recent DHT good nodes
   - `host-usage.json` — per-host bytes-today tally
   - `cellular-budget.json` — cellular daily budget
   - `fleet.json` — CLI/Raycast/Alfred discovery descriptor (port + token)
   - Per-download: `<output>.splynek` sidecar
5. **`splynek://` is the one ingress.** Drag-drop, Shortcuts,
   browser extensions, menu-bar popover, Chrome extension, CLI,
   web dashboard — they ALL construct `splynek://` URLs or call
   the REST API. No parallel ingress points.
6. **Build.sh builds only the `Splynek` product.**
   `swift build -c release --product Splynek`. Tests live at
   `swift run splynek-test`. Don't revert this — building the
   whole package under `-c release` fails (test target's
   `@testable import SplynekCore` requires debug) and the old
   script silently shipped stale binaries.
7. **Tests** self-hosted. `Tests/SplynekTests/` runs via
   `swift run splynek-test`. No XCTest, no Swift Testing — both
   are flaky on Command Line Tools without Xcode. 60-LOC
   assertion harness (`TestHarness.suite`/`test`, `expect`/
   `expectEqual`). 58 tests cover Merkle, Bencode, BEP 52,
   magnets, duplicate detection, sanitization, web dashboard
   HTML contract, QR, OpenAPI spec shape, fleet descriptor
   round-trip, Concierge actions. Add suites by writing a new
   file under `Tests/SplynekTests/` with a `static func run()`
   and wiring it into `main.swift`.
8. **Release builds use the live icon.** Hero views in About +
   Downloads strip load `Splynek.icns` directly from
   `Bundle.main.resourceURL.appendingPathComponent("Splynek.icns")`,
   bypassing `NSApp.applicationIconImage` which on recent macOS
   wraps icons in a generic-app white frame when LaunchServices
   is stale.

---

## Package / target layout

```
Package.swift                         # 3 targets: Splynek, splynek-cli,
                                       # splynek-test + library SplynekCore
Sources/Splynek/main.swift            # 3-line shim → SplynekBootstrap.run()
Sources/splynek-cli/main.swift        # CLI talking to live app via REST
Sources/SplynekCore/
  Bootstrap.swift                     # entry wrapper
  SplynekApp.swift                    # @App, AppDelegate, dock menu, scheme
  ContentView.swift                   # thin wrapper → RootView
  ViewModel.swift                     # shared mutable state (~1200 LOC)
  DownloadJob.swift                   # per-download lifecycle + snapshot
  DownloadEngine.swift                # HTTP engine + LaneStats + DownloadProgress
                                      # + Phase enum (Probing→Done)
  LaneConnection.swift                # keep-alive HTTP/1.1 + DoH + 416 handling
  Probe.swift                         # URLSession HEAD / ranged-GET
  InterfaceDiscovery.swift            # getifaddrs × NWPathMonitor
  Models.swift                        # shared types
  Sanitize.swift Quarantine.swift GatekeeperVerify.swift
  DownloadHistory.swift DownloadQueue.swift SessionStore.swift
  MerkleTree.swift Metalink.swift DoHResolver.swift LANPeer.swift
  Notifications.swift DockBadge.swift MenuBarController.swift
  GlobalHotkey.swift CurlExport.swift
  AppIntentsProvider.swift            # 7 intents: Download / Queue / Magnet /
                                      # GetProgress / CancelAll / PauseAll /
                                      # ListRecentHistory
  SplynekSpotlight.swift              # CoreSpotlight history indexing
  BenchmarkRunner.swift               # sequential single vs multi probe
  BenchmarkImage.swift                # shareable OG-size PNG
  FleetCoordinator.swift              # Bonjour + REST API server
                                      # (/status /fetch /content /api/* /ui*)
  WebDashboard.swift                  # embedded HTML dashboard
  OpenAPI.swift                       # embedded OpenAPI 3.1 spec
  QRCode.swift                        # CIQRCodeGenerator wrapper
  AIAssistant.swift                   # Ollama client: detect + URL resolve
                                      # + history search
  AIConcierge.swift                   # action-routing concierge prompt
  Enrichment.swift                    # sibling HEAD probes + duplicate match
  CellularBudget.swift HostUsage.swift
  UpdateChecker.swift
  BackgroundMode.swift                # menu-bar-only + login-item (SMAppService)
  Torrent/
    Bencode.swift TorrentFile.swift TorrentV2Verify.swift MagnetLink.swift
    TrackerClient.swift HTTPTrackerOverNW.swift UDPTracker.swift
    TorrentWriter.swift PeerWire.swift DHT.swift DHTServer.swift
    SeedingService.swift TorrentEngine.swift
  Views/
    RootView.swift Sidebar.swift
    DownloadView.swift TorrentView.swift QueueView.swift
    HistoryView.swift HistoryDetailSheet.swift
    FleetView.swift BenchmarkView.swift ConciergeView.swift LiveView.swift
    SettingsView.swift LegalView.swift AboutView.swift
    Components.swift InterfaceComponents.swift ThroughputChartView.swift
Tests/SplynekTests/
  Harness.swift main.swift
  MerkleTreeTests.swift BencodeTests.swift MagnetTests.swift
  TorrentV2VerifyTests.swift DuplicateTests.swift SanitizeTests.swift
  WebDashboardTests.swift QRCodeTests.swift
  OpenAPITests.swift FleetDescriptorTests.swift ConciergeTests.swift
Resources/
  Info.plist                          # scheme, doc types, CFBundleIconFile
  Splynek.icns                        # canonical app icon (from SVG)
  Splynek.entitlements                # optional sandbox (unused by default)
  Legal/
    EULA.md PRIVACY.md AUP.md         # bundled for offline viewing in LegalView
Scripts/
  build.sh                            # SPM build → .app → codesign
  dmg.sh                              # .app → compressed .dmg
Packaging/
  splynek.rb                          # Homebrew cask template
Extensions/
  Chrome/                             # Manifest V3 extension
  Safari/bookmarklets.html            # drag-to-bookmarks-bar page
  Raycast/                            # TypeScript extension
  Alfred/Splynek.alfredworkflow/      # info.plist + splynek.sh
Branding/
  Splynek-logo.svg                    # canonical vector source (user-designed)
  rasterize.swift                     # swift helper: SVG → PNG at any size
  generate_logo.py                    # older vector-logo generator (unused)
  Splynek.icns                        # master bundle
  icon.iconset/                       # .iconset intermediate
  flat/                               # per-size PNGs for Chrome/Raycast/README
docs/
  index.html                          # GitHub Pages landing (dark theme)
  icon-256.png icon-1024.png
LICENSE                               # MIT
CONTRIBUTING.md                       # onramp + invariants + style
SHOW_HN.md                            # launch-post draft + pre-seeded replies
LANDING.md                            # long-form landing copy (pre-docs/)
MONETIZATION.md                       # tiers, pricing, distribution, €99 case
SECURITY.md                           # threat model + controls (v0.28)
DESIGN_BRIEF.md                       # logo design spec (pre user SVG)
CHANGELOG.md                          # condensed per-release log
.gitignore
```

---

## Declined items (engineering reasons)

- **uTP (BEP 29)** — LEDBAT congestion control, days of work, marginal value
- **MSE encryption** — weak RC4 key exchange, low ROI in 2026
- **HTTP/3 / QUIC** — `NWProtocolQUIC` public API too limited; QPACK
  implementation is weeks of work
- **Reed-Solomon erasure coding** — 20% bandwidth tax, solves a problem
  we don't have given origin servers always have full content
- **Public fleet / global P2P cache** — legal + moderation + operational
  exposure (DMCA, CSAM reporting, infrastructure). See SECURITY.md
  and MONETIZATION.md for the full argument.

## Blocked on €99 Apple Developer account

- **Notarization** — unlocks double-click launch everywhere
- **Mac App Store distribution** — Pro-tier revenue channel
- **Safari App Extension (`.appex`)** — replaces v0.21 bookmarklets
- **Apple Watch complication** — needs Watch target in Xcode

User has explicitly stated "zero risk" / no €99 spend. All
MONETIZATION-plan revenue paths require the €99. If the decision
changes, re-read MONETIZATION.md § "First 90 days plan."

---

## Natural next bites (ordered queue)

Everything below is CLEARLY SCOPED and can be picked up without
context from the current session. The top four (B/C/D/E) were
enumerated as the "do them all" plan; only A landed in v0.32.

### B — Torrent side of the Live dashboard  *(tractable, ~30 min)*
`LiveView` currently iterates `vm.activeJobs` (HTTP only).
`vm.isTorrenting` + `vm.torrentProgress` are orthogonal. Add a
`TorrentLiveCard` that appears when `isTorrenting`, with torrent-
appropriate metrics (peers, pieces done, endgame pill) and a
phase strip fed by the existing `TorrentProgress.phase: String`.
Shared pipeline vocabulary: Announcing → Fetching metadata →
Connecting to peers → Downloading → Seeding → Done.

### C — Scheduled downloads  *(~2 hrs)*
New `DownloadSchedule` model — time window rules (start hour,
end hour, days-of-week) + interface-gated rules ("only when Wi-Fi
is selected", "never on cellular > 500 MB"). Persist to
`schedules.json`. VM scheduler loop polls pending jobs, starts
those whose window has opened. UI: Settings card for rule
editor; "Waiting until 02:00" state on pending queue entries.
Justifies the Pro-tier gate in MONETIZATION.md.

### D — Integration tests  *(~1.5 hrs)*
Python script that: (1) spins up a local HTTP server serving a
known-bytes file, (2) launches `Splynek.app`, (3) submits the
download via the REST API (`POST /api/download?t=<token>`),
(4) polls `/api/jobs` until complete, (5) compares output bytes,
(6) asserts phase transitions fired in order (Probing → Planning
→ Connecting → Downloading → Verifying → Gatekeeper → Done).
Would have caught v0.27's silent-stale-binary regression.
`Scripts/integration-test.sh` as the entry point.

### E — Watched-folder ingestion  *(~1 hr)*
`~/Splynek/Watch/` monitored via `DispatchSourceTimer` (5s poll —
simpler than FSEvents and good enough). Parse dropped `.txt`
(line-by-line URLs), `.torrent`, `.metalink`. UI: Settings card
for enable + folder picker. Skip RSS in this pass — watched
folders alone is the 80/20.

### Lower-priority items from earlier natural-next-bites

- Session restore for torrents (HTTP works; BT needs piece scan on resume)
- Unified peer pool for BT (merge outbound `PeerCoordinator` with
  inbound `SeedingService` for cross-direction tit-for-tat)
- Finer Gatekeeper signature panel (Developer ID, team, notarisation
  status as individual fields)
- CSV export of `HostUsage` / `CellularBudget` history
- Full auto-update installer (mount DMG + copy + relaunch;
  requires notarization)
- `hash_request` / `hashes` peer messages for pure-v2 magnet
  metadata (current v2 verify works for magnets that ship piece
  layers)

---

## Working conventions

- Each feature pass ends with a `## What's new in v0.N` README
  section at the top of the reverse-chronological log.
- Build is verified with `./Scripts/build.sh` + `open build/Splynek.app`
  + smoke-click through the tabs + `osascript -e 'tell application
  "Splynek" to quit'`. Triple.
- Warnings treated as errors — aim for zero before shipping.
- `@MainActor` isolation is consistent; cross-actor work happens
  via `Task { @MainActor in … }` or explicit actor hops.
- SwiftUI views are ~200–500 LOC each, broken into Section cards
  backed by `TitledCard` + `StatusPill` + `MetricView` + the new
  v0.30 `PageHeader` from `Views/Components.swift`.
- Swift 6 concurrency warnings are actively cleaned up — don't
  introduce captured-var mutations or non-Sendable closures.
- Commit messages: imperative, short, explain *why* over *what*.
  Co-authored-by tag reserved for actual human contributors, not
  tooling.

---

## If something looks off

- **App icon shows a generic white frame.** LaunchServices icon
  cache is stale. `killall Dock` after `lsregister -f build/Splynek.app`.
- **build/Splynek.app is outdated after a source change.** Check
  that `./Scripts/build.sh` used `--product Splynek` (it does since
  v0.27; see invariant #6).
- **Tests silently don't run.** Touch `Tests/SplynekTests/main.swift`
  to force SPM to rebuild the test target.
- **fleet.json not appearing in release builds.** Release-optimiser
  had a history of eliding the `stateUpdateHandler` callback.
  Fixed in v0.27 by calling `persistDescriptor()` from every VM
  `publishFleetState()` tick AND the listener-ready hook.
- **`Image(systemName:)` with `.foregroundStyle(.accentColor)`
  fails to compile.** Use `Color.accentColor` instead — the
  `ShapeStyle` case-access only works for some SF-symbol sites.
