# Splynek handoff

Native macOS multi-interface download aggregator. Pure Swift, zero
third-party deps. Public free-tier repo (MIT) + private Pro-tier repo.
~12k LOC across ~55 files.

**Working directory:** `/Users/pcgm/Claude Code`
**Public repo:** [github.com/Splynek/splynek](https://github.com/Splynek/splynek) — MIT, remote is `origin`, tags `v0.31` + `v0.43` + `v0.44` pushed.
**Private repo:** [github.com/Splynek/splynek-pro](https://github.com/Splynek/splynek-pro) — closed-source, expected at `../splynek-pro` (sibling checkout).
**Live site:** [https://splynek.app](https://splynek.app) with `/pro`, `/support`, `/privacy`. HTTPS via Let's Encrypt (auto-renews); DNS at Cloudflare, Pages served by GitHub.
**Domain:** splynek.app (owned, CNAME'd via `docs/CNAME`).
**Build (DMG ad-hoc):** `./Scripts/build.sh` → `build/Splynek.app`
**Build (DMG Developer-ID, for notarisation):**
```
SIGN_IDENTITY="Developer ID Application: Paulo Moura (58C6YC5GB5)" \
  ENTITLEMENTS="Resources/Splynek.entitlements" ./Scripts/build.sh
./Scripts/dmg.sh
xcrun notarytool submit build/Splynek.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple build/Splynek.dmg
```
**Build (MAS):** `./Scripts/build-mas.sh` → `build/Splynek-MAS.xcarchive` + `build/Splynek-MAS-Export/Splynek.pkg`
**Tests:** `swift run splynek-test` (117 tests, all green)
**CLI:** `swift run splynek-cli version`

**Current version:** 0.47 — P1+P2+P3 QA polish pass before first App Store submission. 16 real bugs fixed + tooltips added to jargon controls + Queue Summary card redesigned. Three working build paths: SPM (`swift build`), Xcode DMG (`xcodebuild -scheme Splynek`), Xcode MAS (`xcodebuild -scheme Splynek-MAS`). The MAS .pkg is signed with Apple Distribution and ready for ASC upload. The DMG is notarised + stapled and sits on the GitHub v0.44 Release as the public download (SHA-256 `cdcbbaeac8d0bb41f60dd8e3ff0aeb76f1d680200e4ae2c5a3f786820adfe664`).

**What's DONE on the commercial/distribution side (was blocked last session):**

- Apple Developer Program enrolled (€99, Team ID `58C6YC5GB5`)
- App ID registered: `app.splynek.Splynek` with `In-App Purchase` capability
- Apple Distribution + Developer ID Application certs in keychain
- App Store Connect app record created (macOS app "Splynek", bundle `app.splynek.Splynek`, SKU `splynek-mac`)
- Paid Apps Agreement signed (19/04/2026 – 19/04/2027)
- Tax forms submitted + active (W-8BEN + U.S. Foreign Status)
- DSA (EU Digital Services Act) declaration filed as trader via `TraditioneForAll, Lda` contact details (Em revisão)
- ASC version page filled: subtitle, description (2.2k chars), keywords, promo, URLs, copyright, review notes (3.3k chars), contact info
- App Privacy card published: 14× Data Not Collected + privacy URL
- Age rating: 4+
- Categories: Utilities (primary) + Productivity (secondary)
- Content rights declared: no third-party content
- `notarytool` keychain profile saved: `AC_PASSWORD`

**What's STILL user-side pending** (end of the v0.47 session):

1. Re-upload the v0.47 MAS `.pkg` via Xcode Organizer:
   `open "/Users/pcgm/Claude Code/build/Splynek-MAS.xcarchive"` → Distribute App → App Store Connect → Upload.
2. On ASC version page: update Versão to `0.47`, attach build `0.47 (47)`.
3. Upload screenshots (user has 5+ Retina screenshots already captured; see `MAS_LISTING.md § Screenshots plan`).
4. Click **Adicionar para revisão** (Submit for Review).
5. Respond to Apple if they reject — review notes cover the likely concerns (network.server, Ollama dependency, BitTorrent).

**Dev override for Pro features** (ADDED v0.47):
```
defaults write app.splynek.Splynek splynekDevProUnlocked -bool YES
```
Relaunch the MAS build — Assistant + Recipes tabs appear, Pro = ACTIVE. Short-circuits StoreKit in `splynek-pro/Sources/SplynekPro/LicenseManager.swift`. Clear with `defaults delete app.splynek.Splynek splynekDevProUnlocked`.

**v0.45 summary (for context):** MAS build infrastructure.
Xcode project (`project.yml` → XcodeGen), sandbox entitlements,
StoreKit 2 integration in `splynek-pro`, `#if MAS_BUILD` guards on
GlobalHotkey + UpdateChecker. MAS target expects `splynek-pro` as
a sibling checkout at `../splynek-pro`. See README § 0.45.

**v0.44 summary (for context):** the public/private split. Pro
modules (AI Concierge, Recipes, Scheduling, LAN-exposed Fleet,
HMAC license) moved to `Splynek/splynek-pro`. Public ships
free core + API-compatible stubs (`Sources/SplynekCore/ProStubs.swift`).
117 tests (was 165; 48 moved). Free DMG: 2.3 MB.

**v0.46 summary (for context):** 6 P1 bugs fixed + 7 P2 polish
items. Pause no longer looks cancelled. Phase strip resets on
pause/cancel. Trash icon works on paused jobs. Bad-URL error
visible inline. Throughput clamped to 0.5 s min window (no more
fantasy GB/s spikes). Phase pills readable (icon-only non-current).
iPhone USB tether detected + labeled correctly. Wi-Fi icon blue
(not yellow). Queue 3-dots menu enriched. Duplicate toolbar icons
removed. Benchmark Run button surfaced inline. About logo shrunk.

**v0.47 summary (this session):** P3 polish. Queue Summary card
redesigned (hero count + state dots + bulk action bar with
Retry-all-failed + Clear-finished). Tooltips pass — ~12 new
`.help()` on jargon controls (Connections per interface,
Per-interface DoH, Load Metalink, Load Merkle). New
`labelWithInfo(_:tooltip:)` helper in DownloadView. Dev-override
flag for Pro audit added to splynek-pro's LicenseManager.

**D1 split invariants (v0.44+):**
- Free-tier `isPro = false` is compile-time-enforced — it's a
  stubbed class, not a runtime-toggled flag (MAS build excludes the
  stubs and links splynek-pro's real implementations).
- New Pro functionality lands in `Splynek/splynek-pro`, NOT in the
  public repo. If it needs to compile in the free build, the stub
  in `ProStubs.swift` must also gain a corresponding API-compatible
  no-op.
- Views gate Pro tabs at the sidebar level (not inside the body).

**Architectural invariant (v0.43+):** Do NOT put a top-level
conditional `if/else` that returns structurally different view
subtrees inside a `some View` body used as a `NavigationSplitView`
destination. macOS 14's split-view layout fails in a way that
requires full-restart recovery. Gate at the sidebar level instead
(show/hide the tab) or use a fully stable outer shape.

---

## Start-of-session ritual

1. `Read HANDOFF.md` (this file)
2. `Read README.md` (top 200 lines covers the latest few releases)
3. Check `git status` + `git log --oneline -10` in BOTH repos:
   - `/Users/pcgm/Claude Code` (public)
   - `/Users/pcgm/splynek-pro` (private; sibling checkout)
4. Check ASC submission state if the task is MAS-related:
   `gh api /repos/Splynek/splynek/pages/builds/latest --jq .status`
   (Pages state — not the same as ASC review state).
5. Ask the user what to build. Don't invent work — the
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
   `sharedBuckets`, `queue`, `history`, `torrentProgress`, Pro state
   (via stubs or real impl), fleet integration, and preferences.
   Engines publish to it via `@Published`; engines never touch
   `DockBadge` or UI directly.
4. **Session state** lives in `~/Library/Application Support/Splynek/`
   (DMG build) or `~/Library/Containers/app.splynek.Splynek/Data/Library/Application Support/Splynek/` (MAS build):
   - `history.json` — completed downloads (last 500, with SHA-256)
   - `queue.json` — persistent URL queue
   - `session.json` — jobs + last torrent snapshot
   - `dht-routing.json` — 200 most-recent DHT good nodes
   - `host-usage.json` — per-host bytes-today tally
   - `cellular-budget.json` — cellular daily budget
   - `fleet.json` — CLI/Raycast/Alfred discovery descriptor (port + token)
   - `schedule.json` — global download schedule (window + weekdays) [Pro]
   - `recipes.json` — recent agentic recipes (capped at 20) [Pro]
   - `host-usage-history.json` — frozen daily snapshots (v0.37+)
   - `cellular-budget-history.json` — frozen daily cellular totals (v0.37+)
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
   `expectEqual`). 117 tests (post-v0.44 split; 48 Pro-tests moved
   to `splynek-pro/Tests/SplynekProTests/`).
8. **Release builds use the live icon.** Hero views in About +
   Downloads strip load `Splynek.icns` directly from
   `Bundle.main.resourceURL.appendingPathComponent("Splynek.icns")`,
   bypassing `NSApp.applicationIconImage` which on recent macOS
   wraps icons in a generic-app white frame when LaunchServices
   is stale.
9. **MAS build excludes stubs + includes splynek-pro.** In
   `project.yml`, the `Splynek-MAS` target's `sources:` has
   `Sources/SplynekCore` with `excludes: [ProStubs.swift, Views/ConciergeView.swift, Views/RecipeView.swift, Views/ProLockedView.swift]` AND adds `../splynek-pro/Sources/SplynekPro`. Compiling both into
   the same target module means the Pro types internal-import
   freely; no cross-module public-access refactor needed.
10. **Throughput calc clamps min-window to 0.5 s (v0.46).** In
    `DownloadEngine.swift::LaneStats.record()`. Prior 0.001 s
    clamp produced fantasy "5 GB/s" on the first chunk landing.
11. **NavigationSplitView detail panes on macOS 26 need belt +
    suspenders sizing.** `GeometryReader { geo in … .frame(width:
    geo.size.width, height: geo.size.height) }` is mandatory, not
    optional, whenever a detail view's inner `@ViewBuilder`
    produces branches with different intrinsic widths (e.g.
    empty-state ↔ ScrollView). `.frame(maxWidth: .infinity)` alone
    is NOT enough — it's the accept-ceiling, not the report-up
    value. Related: chat/transcript state belongs in its own
    ObservableObject, not on the root VM, so sibling re-renders
    don't collide on a layout change. `LanguageModelSession` must
    be created on `@MainActor` per WWDC25 session 286. Full story
    in [POSTMORTEM-Concierge-Blank.md](POSTMORTEM-Concierge-Blank.md) — v1.1
    shipped without any of these three protections and the
    Concierge blanked the whole window on first chip click.

---

## Package / target layout

```
Package.swift                         # SPM: Splynek + splynek-cli + splynek-test + SplynekCore library
project.yml                           # XcodeGen spec → Splynek.xcodeproj (DMG + MAS targets)
Splynek.xcodeproj                     # generated; gitignored
Scripts/
  build.sh                            # SPM → .app → codesign (ad-hoc by default)
  dmg.sh                              # .app → compressed .dmg
  build-mas.sh                        # xcodegen + xcodebuild archive → .xcarchive (MAS)
  export-options-mas.plist            # -exportArchive plist for MAS pkg
  integration-test.sh / .py           # local HTTP server + REST API test
Sources/Splynek/main.swift            # 3-line shim w/ canImport(SplynekCore) guard
Sources/splynek-cli/main.swift        # CLI talking to live app via REST
Sources/SplynekCore/
  Bootstrap.swift                     # entry wrapper
  SplynekApp.swift                    # @App, AppDelegate, dock menu, scheme
  ContentView.swift                   # thin wrapper → RootView
  ViewModel.swift                     # shared mutable state (~1300 LOC)
  DownloadJob.swift                   # per-download lifecycle + snapshot
  DownloadEngine.swift                # HTTP engine + LaneStats + DownloadProgress
                                      # + Phase enum (Probing→Done)
  LaneConnection.swift                # keep-alive HTTP/1.1 + DoH + 416 handling
  Probe.swift                         # URLSession HEAD / ranged-GET
  InterfaceDiscovery.swift            # getifaddrs × NWPathMonitor (+ iPhoneUSB detection v0.46)
  Models.swift                        # shared types (+ .iPhoneUSB Kind v0.46)
  ProStubs.swift                      # v0.44: free-tier stubs (MAS excludes these)
  Sanitize.swift Quarantine.swift GatekeeperVerify.swift
  DownloadHistory.swift DownloadQueue.swift SessionStore.swift
  DownloadRecipe.swift                # stub (real impl in splynek-pro)
  DownloadSchedule.swift              # stub (real impl in splynek-pro)
  MerkleTree.swift Metalink.swift DoHResolver.swift LANPeer.swift
  Notifications.swift DockBadge.swift MenuBarController.swift
  GlobalHotkey.swift                  # #if !MAS_BUILD guarded
  UpdateChecker.swift                 # #if !MAS_BUILD guarded
  CurlExport.swift
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
  AIAssistant.swift                   # stub (real impl in splynek-pro)
  Enrichment.swift                    # sibling HEAD probes + duplicate match
  CellularBudget.swift HostUsage.swift
  BackgroundMode.swift                # menu-bar-only + login-item (SMAppService)
  WatchedFolder.swift                 # folder-drop ingestion (v0.34)
  UsageCSV.swift UsageTimeline.swift  # exports + chart data (v0.37/v0.38)
  Torrent/
    Bencode.swift TorrentFile.swift TorrentV2Verify.swift MagnetLink.swift
    TrackerClient.swift HTTPTrackerOverNW.swift UDPTracker.swift
    TorrentWriter.swift PeerWire.swift DHT.swift DHTServer.swift
    SeedingService.swift TorrentEngine.swift
    PieceVerifier.swift TorrentResume.swift  # v0.40 resume
  Views/
    RootView.swift Sidebar.swift
    DownloadView.swift TorrentView.swift QueueView.swift
    HistoryView.swift HistoryDetailSheet.swift
    FleetView.swift BenchmarkView.swift LiveView.swift
    ConciergeView.swift RecipeView.swift ProLockedView.swift  # STUBS — MAS excludes these
    SettingsView.swift LegalView.swift AboutView.swift
    UsageTimelineView.swift
    Components.swift InterfaceComponents.swift ThroughputChartView.swift
Tests/SplynekTests/
  Harness.swift main.swift (117 tests; 48 moved to splynek-pro v0.44)
Resources/
  Info.plist                          # scheme, doc types, CFBundleIconFile
  Splynek.icns                        # canonical app icon (from SVG)
  Splynek.entitlements                # DMG target's optional sandbox
  Splynek-MAS.entitlements            # v0.45 MAS sandbox + network.server + IAP
  Splynek.storekit                    # v0.45 local StoreKit test config
  Generated-Info.plist                # xcodegen output (gitignored)
  Generated-Info-MAS.plist            # xcodegen output (gitignored)
  Legal/
    EULA.md PRIVACY.md AUP.md         # bundled for offline viewing in LegalView
Packaging/
  splynek.rb                          # Homebrew cask template
Extensions/
  Chrome/                             # Manifest V3 extension
  Safari/bookmarklets.html            # drag-to-bookmarks-bar page
  Raycast/                            # TypeScript extension
  Alfred/Splynek.alfredworkflow/      # info.plist (w/ CFBundleIdentifier for MAS) + splynek.sh
Branding/
  Splynek-logo.svg                    # canonical vector source (user-designed)
  rasterize.swift generate_logo.py
  Splynek.icns icon.iconset/ flat/
docs/
  index.html                          # GitHub Pages landing
  pro.html                            # v0.45 Pro tier landing
  support.html                        # v0.45 support page
  privacy.html                        # v0.45 privacy policy (ASC-required)
  icon-256.png icon-1024.png
  CNAME                               # splynek.app binding
LICENSE                               # MIT
CONTRIBUTING.md                       # onramp + invariants + style
SHOW_HN.md                            # launch-post draft + pre-seeded replies
LANDING.md                            # long-form landing copy (pre-docs/)
MONETIZATION.md                       # tiers, pricing, distribution
SECURITY.md                           # threat model + controls (v0.28)
DESIGN_BRIEF.md                       # logo design spec (pre user SVG)
MAS_LISTING.md                        # v0.45 paste-ready App Store Connect material
CHANGELOG.md                          # condensed per-release log
.gitignore
```

Adjacent private repo layout (checkout at `../splynek-pro`):
```
splynek-pro/
  Package.swift                       # library target SplynekPro
  Sources/SplynekPro/
    LicenseManager.swift              # StoreKit 2 (v0.45+) + dev override (v0.47)
    AIAssistant.swift                 # Ollama client (real impl)
    AIConcierge.swift
    DownloadRecipe.swift
    DownloadSchedule.swift
    Views/ConciergeView.swift
    Views/RecipeView.swift
    Views/ProLockedView.swift         # real paywall UI
  Tests/SplynekProTests/              # 48 tests moved from public repo
  Scripts/gen-license.py              # obsolete HMAC issuer (kept for archaeology)
  SANDBOX_AUDIT.md                    # v0.44 MAS sandbox migration notes
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

## Apple Developer Program — DONE

Previously listed as "blocked on €99 spend." As of the v0.46 session
the full enrolment is complete; Team ID `58C6YC5GB5`, Paid Apps
Agreement active, tax forms submitted, ASC app record created, builds
uploaded. Notarisation + MAS distribution are unlocked. Safari App
Extension (.appex) and Apple Watch complication are still open as
future work — not blocked, just not prioritised.

---

## Natural next bites (ordered queue)

### A — Ship the MAS submission

Only user-side actions remain (see the user-side pending list at the
top). After v0.47 `.pkg` re-upload + build attach + screenshots +
Submit-for-Review, Apple typically responds within 24–72 hours. Any
rejection-response iteration belongs to the next session. If Apple
asks about network.server or Ollama, the review notes already
pre-address those — just point them at the relevant paragraph.

### B — Pro-tier audit (user is doing this right now)

User has the dev override on. Any P1/P2/P3 bugs found in Concierge,
Recipes, Schedule editor, or LAN web dashboard — triage like v0.46:
P1 must-fix before submission, P2 polish before screenshots, P3
deferred to next update. The Pro views live in
`splynek-pro/Sources/SplynekPro/Views/`.

### C — Stripe + Postmark wire-up (if going beyond MAS-only)

MONETIZATION.md describes a dual-channel plan: MAS (Apple takes 15%
under SBP) + direct Stripe (full revenue). `Scripts/gen-license.py`
is still around but obsolete; Stripe success webhook would instead
push a StoreKit offer-code redemption OR gate a DMG Developer-ID
build. Open question — not started.

### D — Post-launch cleanup

- Bundle `splynek-cli` inside the MAS .app (sandbox-compatible CLI).
  Currently MAS build simply omits the CLI; DMG users retain it.
- Data migration DMG→MAS on first launch (see SANDBOX_AUDIT.md §4).
- Full auto-update installer for DMG users (mount DMG + copy +
  relaunch; needs the notarised build which v0.46 now provides).
- `hash_request` / `hashes` peer messages for pure-v2 magnet
  metadata (current v2 verify works for magnets that ship piece
  layers).
- Unified peer pool for BT (merge outbound `PeerCoordinator` with
  inbound `SeedingService` for cross-direction tit-for-tat).

### E — Marketing

- Show HN (draft at `SHOW_HN.md`). Best done after MAS goes live.
- Product Hunt. Same timing.
- Homebrew cask template at `Packaging/splynek.rb`. Update SHA when
  v0.47 DMG lands on the Release asset (SHA is already current —
  see top of this file).

---

## Working conventions

- Each feature pass ends with a `## What's new in v0.N` README
  section at the top of the reverse-chronological log.
- Build is verified with three paths:
  - `./Scripts/build.sh` → SPM DMG
  - `xcodebuild -project Splynek.xcodeproj -scheme Splynek build` → DMG via Xcode
  - `xcodebuild -project Splynek.xcodeproj -scheme Splynek-MAS build` → MAS
  - Plus `swift run splynek-test` (117 green).
- MAS archive + notarise verified before shipping an update:
  `./Scripts/build-mas.sh` for MAS + the Developer-ID flow above for DMG.
- Warnings treated as errors — aim for zero before shipping.
- `@MainActor` isolation is consistent; cross-actor work happens
  via `Task { @MainActor in … }` or explicit actor hops.
- SwiftUI views are ~200–700 LOC each, broken into Section cards
  backed by `TitledCard` + `StatusPill` + `MetricView` + `PageHeader`
  from `Views/Components.swift`.
- Swift 6 concurrency warnings are actively cleaned up — don't
  introduce captured-var mutations or non-Sendable closures.
- Commit messages: imperative, short, explain *why* over *what*.
  Co-authored-by tag reserved for actual human contributors, not
  tooling.
- Version bumps: update `project.yml` (`MARKETING_VERSION` + `CURRENT_PROJECT_VERSION`) AND `Extensions/Alfred/Splynek.alfredworkflow/info.plist` (`CFBundleShortVersionString`) together. XcodeGen regenerates `Resources/Generated-Info*.plist` from the `project.yml`.

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
- **Xcode archive fails with "No Accounts".** Apple ID isn't in
  Xcode → Settings → Accounts. Re-add it; automatic signing picks
  up from there.
- **`xcodebuild archive` fails with "conflicting provisioning
  settings".** `project.yml` has `CODE_SIGN_IDENTITY` set manually
  but `CODE_SIGN_STYLE: Automatic`. Remove the identity override
  (automatic signing picks Apple Development for build, Apple
  Distribution for archive).
- **`altool --upload-package` says "Failed to find item
  AC_PASSWORD".** Expected — `altool` and `notarytool` use
  different keychain formats. Use Xcode Organizer's Upload button
  instead (signs in via Xcode's signed-in Apple ID directly), or
  set up an App Store Connect API Key (.p8) and use JWT auth.
- **Throughput briefly reads 0 MB/s after starting.** v0.46 clamps
  the sample window to 500 ms minimum to prevent 5 GB/s spikes;
  during the first 500 ms the reported throughput under-reads by
  up to 2× before converging. Intentional; don't "fix" by dropping
  the clamp.
- **MAS build Assistant + Recipes tabs missing.** Either (a)
  `splynekDevProUnlocked` isn't set (flip it with
  `defaults write app.splynek.Splynek splynekDevProUnlocked -bool YES`),
  or (b) the real StoreKit purchase hasn't completed / isn't
  visible — check `Transaction.currentEntitlements` with
  `xcrun storekit-test`.
- **iPhone tether shows as ETH instead of iPhone.** v0.46 fix
  relies on the 172.20.10.0/28 IP range. If the iPhone hands out
  a different range (rare), the detection misses. Extend the
  condition in `InterfaceDiscovery.swift` near the `// v0.46:
  iPhone USB Personal Hotspot` marker.
