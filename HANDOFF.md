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

**Current version: v1.3 — shipped 2026-04-24.** Notarised DMG published on GitHub Releases. MAS archive built, waiting for v1.0 to clear App Store review before uploading v1.3 as the update. Full release history + download URLs under § Shipped releases below.

---

## Shipped releases (in order)

All Developer-ID-signed, notarised, stapled, and published at
<https://github.com/Splynek/splynek/releases>. SHA-256 hashes match the
release-notes bodies.

### v1.3 — Sovereignty catalog 2× + AI fallback (2026-04-24)
- **DMG**: [Splynek-1.3.dmg](https://github.com/Splynek/splynek/releases/download/v1.3/Splynek-1.3.dmg) — `d08ee9f5546aa96f1c66b1011508f76e2c6852f0275f66fe7e5817ec7d7c73d4`
- Sovereignty catalog 50 → 90 entries (new: Arc, Opera/CN, Superhuman, HEY, OmniFocus, TickTick/CN, Asana, Trello, Jira, Confluence, monday.com, Raycast, Magnet, Moom, Warp, Nova, Navicat/HK, Plex, Emby, NordVPN, ExpressVPN, Perplexity, Copilot, Steam + more)
- Thunderbird joins Firefox as one-click-Install alternatives
- **New: AI fallback for uncataloged apps.** Per-app Ask-AI button routes through the local LLM with a sovereignty-focused prompt. Results render inline. Gated on `vm.aiAvailable`.
- Related commits: `/Users/pcgm/Claude Code` @ `4c27964`, `/Users/pcgm/splynek-pro` @ `f62a2ed`

### v1.2 — Sovereignty tab (2026-04-24)
- **DMG**: [Splynek-1.2.dmg](https://github.com/Splynek/splynek/releases/download/v1.2/Splynek-1.2.dmg) — `e50cdf80366542300b300ea6708624edf660785f77291f04eb8f37cd2b8dc52d`
- New Sidebar tab **Sovereignty** (`shield.lefthalf.filled`, NEW badge) — scans installed apps locally and surfaces European or open-source alternatives
- Framing is explicitly **pro-EU-sovereignty, not anti-any-country.** Target apps show their origin as a neutral grey badge (US / CN / RU / OTHER); alternatives show EU / OSS / EU+OSS coloured badges. The `Origin.isRecommendable` property enforces that alternatives can only be European or OSS.
- 50-entry seed catalog covering common US/CN/RU/OTHER apps
- Filter chips: All alternatives / European only / Open-source only
- One-click "Install" button for alternatives with stable download URLs (Firefox v1.2; Thunderbird added v1.3)
- Community-contribution guide at [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md)
- Concierge regex short-circuit for cancel/pause commands (10–17 s → microseconds)
- Apple Intelligence `session.prewarm()` on input-focus
- Related commits: `/Users/pcgm/Claude Code` @ `e09d69a`, `/Users/pcgm/splynek-pro` @ `ca38159`

### v1.1.1 — Concierge blank-state hotfix (2026-04-23)
- **DMG**: [Splynek-1.1.1.dmg](https://github.com/Splynek/splynek/releases/download/v1.1.1/Splynek-1.1.1.dmg) — `f114345f690f30acbdc546f14da6d09999a82f93514a4f83122c0fa4501d3a79`
- v1.1 shipped with a **macOS 26 SwiftUI regression** that blanked the entire NavigationSplitView the instant a user clicked a Concierge suggestion chip. Fixed in v1.1.1 via **three combined changes** (all load-bearing; see POSTMORTEM).
- `@MainActor AppleIntelligenceDriver` enum wraps `LanguageModelSession` per Apple's WWDC25 session 286 canonical pattern — keeps `Observation.Observable` notifications on MainActor so SwiftUI narrows invalidation correctly.
- Dedicated `ConciergeState: ObservableObject` holds `chat` + `thinking`. Scopes re-renders to `ConciergeView` only — not Sidebar + RootView.
- `GeometryReader` + explicit `.frame(width: geo.size.width, height: geo.size.height)` in `ConciergeView.body`. Pins the detail column so `NavigationSplitView` can't shrink it below `min: 640` during a ViewBuilder branch swap.
- Plus Concierge upgrades: **probe-validator** (every AI-suggested URL runs through `Probe.run` before Concierge surfaces `.download` / `.queue`), **multi-candidate retry** (model returns `candidates: [String]` — we probe in order, first success wins), **solution-oriented fallback** (when every URL fails, render the model's `alternatives: [String]` project names instead of an error message), **tolerant JSON extractor** (handles markdown fences + prose-wrapped output).
- Full write-up in [POSTMORTEM-Concierge-Blank.md](POSTMORTEM-Concierge-Blank.md) — four dead-end debugging paths, the clinching diagnostic, six rules-of-thumb for `NavigationSplitView` detail panes on macOS 26. **Required reading for anyone touching the Concierge or adding a new detail view.**
- Related commits: `/Users/pcgm/Claude Code` @ `15b1645`/`17e2597`, `/Users/pcgm/splynek-pro` @ `eebc756`

### v1.1 — Apple Intelligence Concierge (2026-04-21)
- Apple Foundation Models as the primary AI provider on macOS 26+. Ollama + LM Studio remain as fallback / pre-macOS-26 path. `AIAssistant.detect()` probes Apple Intelligence first, then LM Studio, then Ollama — first ready wins.
- Zero-install on eligible Macs. Footer reads "Using Apple on-device model via Apple Intelligence".
- **Shipped with the blank-state bug** — superseded by v1.1.1.

### v1.0 — Launch (2026-04-21)
- First stable App Store candidate. Same binary as v0.50.4 with `MARKETING_VERSION` bumped to 1.0.
- Still in App Store review (v1.0 submitted; not yet Ready for Sale as of 2026-04-24).

### Pre-1.0 context

**v0.47** — P1+P2+P3 QA polish pass. 16 bugs fixed. Tooltips added to jargon controls. Queue Summary card redesigned.
**v0.46** — 6 P1 bugs fixed + 7 P2 polish items. Throughput clamped to 0.5 s min window.
**v0.45** — MAS build infrastructure. XcodeGen, sandbox entitlements, StoreKit 2.
**v0.44** — Public/private split. Pro modules moved to `splynek-pro`. Public ships stubs.
**v0.40** — BitTorrent v2, DHT, persistent resume.
**v0.30–0.43** — LAN fleet, Bonjour discovery, REST API, web dashboard, metalink, merkle.

---

## MAS submission status (as of 2026-04-24)

- Apple Developer Program enrolled (€99, Team ID `58C6YC5GB5`)
- App ID registered: `app.splynek.Splynek` with `In-App Purchase` capability
- Apple Distribution + Developer ID Application certs in keychain
- App Store Connect app record created (macOS app "Splynek", SKU `splynek-mac`)
- Paid Apps Agreement signed (19/04/2026 – 19/04/2027)
- Tax forms submitted + active (W-8BEN + U.S. Foreign Status)
- DSA (EU Digital Services Act) declaration filed as trader via `TraditioneForAll, Lda`
- ASC version page filled: subtitle, description, keywords, promo, URLs, copyright, review notes
- App Privacy card published: 14× Data Not Collected + privacy URL
- Age rating: 4+; Categories: Utilities (primary) + Productivity (secondary)
- `notarytool` keychain profile saved: `AC_PASSWORD`
- **v1.0 uploaded to ASC → still in review.** Once it clears to Ready for Sale, upload `build/Splynek-MAS.xcarchive` (currently v1.3) as the update via Xcode Organizer. Don't upload before v1.0 clears — it would invalidate the review.

**MAS_LISTING.md** holds the full listing copy and screenshot plan.

---

## Dev override for Pro features

```sh
defaults write app.splynek.Splynek splynekDevProUnlocked -bool YES
# Relaunch the MAS build — Concierge + Recipes tabs go from PRO-locked to unlocked.
defaults delete app.splynek.Splynek splynekDevProUnlocked
```

Short-circuits StoreKit. See `splynek-pro/Sources/SplynekPro/LicenseManager.swift::devOverrideKey`. Note: `vm.aiAvailable` is its own thing — it's true when any backend (Apple Intelligence / Ollama / LM Studio) is detected, regardless of Pro status.

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
12. **Sovereignty tab privacy contract.** `SovereigntyScanner` uses
    `FileManager.contentsOfDirectory` + `Bundle(url:)` against
    `/Applications`, `/Applications/Utilities`, and `~/Applications`.
    Sandbox-legal, no entitlements, no Spotlight daemon access. The
    privacy invariants are audited at the top of
    `Sources/SplynekCore/SovereigntyScanner.swift` — enumeration only
    (no content reads), stays on-device (no network), opt-in
    one-shot (no background scans, no persistence), filters system
    apps. **Do not add NSMetadataQuery, network calls, caching, or
    background scanning.** The tab is a statement of values; any
    code that breaks the audit trail undermines the statement.
    `SovereigntyCatalog` invariants: targets never use European /
    OSS origins; alternatives never use US / CN / RU. Enforce via
    the `Origin.isRecommendable` property.

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

### A — Ship v1.3 to the MAS when v1.0 clears review

The MAS pipeline is locked; only the state transition is blocking.
1. Monitor App Store Connect for v1.0 → Ready for Sale (or rejection).
2. When it clears: open `/Users/pcgm/Claude Code/build/Splynek-MAS.xcarchive` in Xcode Organizer → Distribute App → App Store Connect → Upload.
3. On ASC version page: update Versão to `1.3`, attach build `1.3 (1300)`, click Submit.
4. If Apple rejects v1.0, iterate on review notes (they already pre-address network.server, Ollama, BitTorrent); resubmit with v1.3 once resolved.

### B — Sovereignty catalog growth (community + manual)

Target: ~50 → 90 → 150+ entries. [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md)
is live so external PRs are possible. Manual next-pass:
- **More `downloadURL`s** for popular alternatives that have stable canonical URLs. Firefox + Thunderbird currently work via Mozilla's redirect service. Research: Signal's `updates.signal.org` pattern, VLC's `get.videolan.org`, Bitwarden's GitHub-releases/latest, LibreOffice's stable mirror. One afternoon of careful URL-verification per batch — prone to 404 rot if the author isn't careful.
- **More entries** for apps users actually have installed. Gap areas: graphics / illustration tools (Sketch, Procreate), DAWs (Logic Pro is built-in but Ableton is German), language IDEs (JetBrains suite — Czech), dev databases (Sequel Ace is OSS, TablePlus is Singapore-based), file-sync (Resilio Sync is US). When adding targets whose vendors are non-obvious, cite the source in the PR body.

### C — Sovereignty AI-fallback prompt tuning

Known issue: the 3B on-device model occasionally suggests US alternatives despite the strict "NEVER US/CN/RU" rule (in testing, Prime Video → YouTube/Netflix hallucination). Improvement path:
- Add 2–3 **bad-output examples** to the system prompt ("if the user has X, do NOT suggest Y because Y is also US-based").
- Consider running the AI response through a post-filter that rejects suggestions whose homepage TLD / registrar-country matches US / CN / RU. Brittle but catches the worst offenders.
- A/B test the improvements using `/tmp/concierge-ab/` harness (adapt it for the sovereignty prompt). Each candidate prompt gets N runs against a held-out test set.

### D — Localisation (FR / DE / ES / IT)

Sovereignty is the EU-market-credibility feature; shipping it only in English is a self-own. Start with the Sovereignty tab's strings (small surface area, ~30 localisable strings). Pattern:
- Add `Localizable.xcstrings` catalog under `Resources/`
- Extract `String` literals from `SovereigntyView.swift` into `String(localized:)` calls
- Machine-translate (DeepL / GPT) for first draft, flag for native-speaker review
- Start with FR (largest EU market) and DE (Splynek's sovereignty-forward audience)
- If well-received, roll the pattern out to Concierge + Recipes + Downloads

### E — Monetization / marketing (unchanged from prior sessions)

- **Stripe + Postmark direct channel** — dual-channel revenue (see MONETIZATION.md). Not blocked; not started.
- **Show HN** — draft at `SHOW_HN.md`. Best done after MAS goes live. Rewrite around the Sovereignty angle: "Splynek — a Mac download manager that also helps you audit your software supply chain. All local, all private."
- **Product Hunt** — same timing.
- **Homebrew cask** — template at `Packaging/splynek.rb`. Update SHA when new DMG lands on a Release asset. v1.3 SHA is `d08ee9f5546aa96f1c66b1011508f76e2c6852f0275f66fe7e5817ec7d7c73d4`.
- **EU press outreach** — Le Monde (FR), El País (ES), Der Spiegel (DE), Wired, FT. Hook: Sovereignty-tab scan video shot on a stock Mac. Co-ordinate with any MAS approval date to avoid review disruption.

### F — Future platform bets (scoped in STRATEGY-2026.md)

- **S2 — Unbreakable Resume** (HTTP Range + NWPathMonitor + curated mirror failover). Multi-week.
- **S5 — Splynek Accelerator** (browser extension + HLS pre-buffer). Multi-week.
- **iOS Companion** — Share Extension + Live Activity. Multi-week.

See [STRATEGY-2026.md](STRATEGY-2026.md) for the full frontier-memo.
Sovereignty itself was not in STRATEGY-2026.md's original six bets —
it emerged as a v1.2 side-bet after the user's framing-shift
conversation and turned out to be the most differentiating feature
Splynek now ships. Worth a strategic re-read.

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
