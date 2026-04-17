# Splynek handoff

Native macOS multi-interface download aggregator. Pure Swift, zero
third-party deps. SwiftUI app + SPM executable target, ~9,500 LOC across
~33 files.

**Working directory:** `/Users/pcgm/Claude Code`
**Build:** `./Scripts/build.sh` → `build/Splynek.app` (ad-hoc signed)
**Run:** `open build/Splynek.app`
**Compile-check only:** `swift build -c release`

**Current version:** 0.31 (see README.md top of feature log)

The README has an exhaustive, reverse-chronological "What's new in v0.N"
log for every feature pass. Read it for context. This file is the
"what a fresh agent needs to be productive" briefing.

## Architecture invariants

These are load-bearing; don't break them without intent.

1. **Interface binding.** Every outbound data socket is pinned to a
   `NWInterface` via `NWParameters.requiredInterface` (Apple's wrapper
   for `IP_BOUND_IF`). DNS for each lane optionally goes through the
   same interface via `DoHResolver` (Cloudflare 1.1.1.1, JSON format).
   Tracker announces for torrents use `HTTPTrackerOverNW` so tracker
   DNS obeys the interface too.
2. **Zero third-party dependencies.** `Package.swift` must stay empty
   of external products. BitTorrent, DHT, DoH, Metalink XML — all
   hand-rolled against Foundation / Network.framework / CryptoKit.
3. **ViewModel owns shared mutable state.** `SplynekViewModel` (main
   actor `ObservableObject`) holds `activeJobs: [DownloadJob]`,
   `sharedBuckets: [String: TokenBucket]`, `queue`, `history`,
   `torrentProgress`, and all `@AppStorage`-backed preferences. Each
   `DownloadJob` owns its own `DownloadEngine` + `DownloadProgress`.
   Engines never touch `DockBadge` or UI directly — the VM's 1 Hz
   timer reads aggregate state and drives the badge + menu-bar item.
4. **Session state** lives in `~/Library/Application Support/Splynek/`:
   - `history.json` — completed downloads (last 500)
   - `queue.json` — persistent URL queue
   - `session.json` — `SessionSnapshot v2`: in-flight jobs + last
     torrent (magnet / .torrent path)
   - `dht-routing.json` — 200 most-recent DHT good nodes
   - Per-download: `<output>.splynek` sidecar with completed chunk IDs
5. **`splynek://` is the one ingress.** Drag-and-drop, `open
   splynek://…` from Terminal, Shortcuts intents, `File → Open Recent`,
   and the AppIntentsProvider all route through either
   `handleDrop(providers:)` or `application(_:open:)` → same code
   path. Don't add parallel ingress points.
6. **Tests** as of v0.26: a self-hosted Swift harness (`Tests/SplynekTests/`)
   runs via `swift run splynek-test`. No XCTest / Swift Testing — CLT
   ships neither cleanly without Xcode, so we built a 60-LOC assertion
   runner instead. 47 tests cover Merkle math, Bencode, BEP 52 verify,
   magnet parsing, duplicate detection, path-traversal sanitization,
   web-dashboard HTML contract, and QR generation. Add suites by writing
   a new file under `Tests/SplynekTests/` with a `static func run()`
   and wiring it into `main.swift`.

## File map (key files only)

```
Sources/Splynek/
  SplynekApp.swift              # @main, AppDelegate, dock menu, scheme, ⌘L
  ContentView.swift             # thin wrapper → RootView
  ViewModel.swift               # shared mutable state, start/cancel/pause/resume
  DownloadJob.swift             # per-download lifecycle + snapshot
  DownloadEngine.swift          # HTTP engine + LaneStats + DownloadProgress
  LaneConnection.swift          # keep-alive HTTP/1.1 over NWConnection + DoH
  Probe.swift                   # URLSession HEAD / ranged-GET
  InterfaceDiscovery.swift      # getifaddrs × NWPathMonitor
  Models.swift                  # shared types
  Sanitize.swift Quarantine.swift GatekeeperVerify.swift
  DownloadHistory.swift DownloadQueue.swift SessionStore.swift
  MerkleTree.swift Metalink.swift DoHResolver.swift LANPeer.swift
  Notifications.swift DockBadge.swift MenuBarController.swift
  GlobalHotkey.swift CurlExport.swift
  AppIntentsProvider.swift      # Download / Queue / Magnet / GetProgress
  SplynekSpotlight.swift        # CoreSpotlight history indexing
  Torrent/
    Bencode.swift TorrentFile.swift MagnetLink.swift
    TrackerClient.swift HTTPTrackerOverNW.swift UDPTracker.swift
    TorrentWriter.swift PeerWire.swift DHT.swift DHTServer.swift
    SeedingService.swift TorrentEngine.swift
  Views/
    RootView.swift Sidebar.swift
    DownloadView.swift TorrentView.swift QueueView.swift
    HistoryView.swift AboutView.swift
    Components.swift InterfaceComponents.swift ThroughputChartView.swift
Resources/
  Info.plist                    # scheme, doc types, NSPrincipalClass
  Splynek.entitlements          # optional sandbox (unused by default build)
Scripts/
  build.sh                      # SPM build → .app → codesign
```

## Declined items (engineering reasons, not capacity)

Keep these out of scope unless the user explicitly asks:

- **uTP (BEP 29)** — LEDBAT congestion control is days of real work
- **MSE encryption** — known weaknesses in RC4 negotiation; low ROI
- **HTTP/3 / QUIC** — `NWProtocolQUIC`'s public API is too limited to
  build a correct H3 client on top
- **Reed-Solomon erasure coding** — ~20% overhead bet that touches
  every piece of the engine
- **Notarization / Mac App Store / browser-extension binaries** —
  need the user's Apple Developer account

## Natural next bites

Ordered by impact × tractability. Items marked ✓ below were landed in
v0.14 and moved out of this list.

- ~~Download speed tit-for-tat in BT seeding~~ ✓ v0.14
- ~~Per-host bandwidth budget~~ → shipped as **cellular-kind** daily
  budget (simpler model); a per-host variant is still open
- ~~AppleScript `.sdef`~~ — *declined*, superseded by App Intents
- ~~In-app update check~~ ✓ v0.14 (self-served JSON feed)
- ~~Right-click → Quick Look~~ ✓ v0.14

Remaining candidates:

1. ~~Per-host daily byte caps~~ ✓ v0.16
2. ~~Lane health + auto-failover~~ ✓ v0.17
3. ~~Per-download performance report~~ ✓ v0.17
4. ~~Time-saved lifetime counter~~ ✓ v0.17
5. ~~Interface preference learning~~ ✓ v0.17
6. ~~Connection-path transparency (remote IP per lane)~~ ✓ v0.17
7. ~~Publish `.splynek-manifest` from local file~~ ✓ v0.17
8. ~~Benchmark panel~~ ✓ v0.18
9. ~~BitTorrent v2 (BEP 52)~~ ✓ v0.19 (parser + SHA-256 Merkle verify;
   `hash_request` peer messages still TODO for magnet-without-layers)
10. ~~Per-device fleet orchestration~~ ✓ v0.19 (discovery + completed
    mirrors), extended in v0.20 with content-addressed `/content/<hex>`
    endpoint, cooperative partial-chunk trading (`/fetch` returns 416
    gracefully; engine treats 416 as per-mirror requeue), and
    unconditional SHA-256 computation on all completions.
11. ~~Browser extensions~~ ✓ v0.21 — Chrome extension (Manifest V3,
    load-unpacked) + Safari bookmarklets, both bundled into the .app
    and revealed from AboutView. A proper Safari App Extension
    (`.appex`) still requires the SPM→Xcode migration, tracked below.
12. **Apple Watch complication** — needs an Xcode project with a Watch
    target (SPM can't produce a `.appex`)
13. **Safari App Extension (`.appex`)** — would replace the v0.21
    bookmarklets with a native extension sharing Splynek's UI
    language. Same SPM→Xcode prerequisite.
12. **Safari/Chrome Share-sheet extension** — same; needs `.appex`
13. Session restore for torrents (HTTP side works; BT needs piece
    scan on resume)
14. Full auto-update installer (v0.15 download-and-reveal works;
    full flow would mount DMG + copy + relaunch — needs notarization)
15. Unified peer pool for BT (merge outbound `PeerCoordinator` with
    inbound `SeedingService` for cross-direction tit-for-tat)
16. Finer Gatekeeper signature panel (show Developer ID, team,
    notarization status as individual fields in the verdict row)
17. CSV export of HostUsage / CellularBudget history for audits

## Working conventions seen across the session

- Each feature pass ends with a `## What's new in v0.N` README section
  in reverse order at the top of the feature log.
- Build is verified with `./Scripts/build.sh` + `open build/Splynek.app`
  + `osascript 'tell application "Splynek" to quit'` (standard triple).
- Warnings are treated as errors — aim for zero before shipping.
- `@MainActor` isolation is consistent; cross-actor work happens via
  `Task { @MainActor in … }` blocks or actor hops.
- SwiftUI views are ~ 200–500 LOC each; broken into Section cards
  backed by `TitledCard` + `StatusPill` + `MetricView` from
  `Views/Components.swift`.
- Swift 6 concurrency warnings are actively cleaned up — don't
  introduce captured-var mutations or non-Sendable closures.

## How to start the next session

Two tool calls:

1. `Read HANDOFF.md` (this file)
2. `Read README.md` (top 100 lines is enough for latest features)

Then ask the user what to build. Don't invent work — there's a natural
next-bites list above and at the end of the latest README section.
