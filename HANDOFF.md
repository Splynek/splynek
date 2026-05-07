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
**Tests:** `swift run splynek-test` (648 tests, all green — was 552 before S4; +96 net) — `swift build` produces **0 warnings on clean rebuild**
**CLI:** `swift run splynek-cli version` (plus `sovereignty-dump` for catalog round-trip)

**Current version: v1.6.2 (Info.plist) / v1.5.3 (last pushed tag + uploaded DMG) — 2026-05-07.**
**Architectural state on `main`: next-release rollup ready** — single coherent forward release containing Concierge-as-Mac-Assistant, Verified Installer (osascript + SMJobBless paths), Fleet 2.0 LAN peer cache (with warm-cache, auto-join, household swarm token), **Bet S2 Unbreakable Resume** (path-flip pause/resume with sidecar continuity + curated mirror failover for Ubuntu/Debian/Fedora), **Bet S3 yt-dlp swallow** (DMG-only dispatch when user has yt-dlp installed; YouTube/Twitch/Instagram/TikTok/X/Vimeo/Bilibili route through it), **Bet S4 iPhone Companion full ship (2026-05-07)** — three iOS targets (SplynekCompanion app + SplynekShareExtension + SplynekCompanionWidgets), shared core exposed as `SplynekCompanionCore` SwiftPM library (now also depended on by SplynekCore so the Mac receiver shares the relay schema); pairing via Bonjour + QR-code or token-paste; Share Extension uses `submitWithRelay(...)` for LAN-first / **CloudKit-fallback over-cellular**; Live Activity for download progress with macOS-26 menu-bar mirror; CloudKit receiver polls every 60s on the Mac; iCloud entitlements live on Mac + iOS + Share Extension (container provisioning in App Store Connect is the only outstanding maintainer step); TestFlight gated on Apple v1.0 macOS clearance, **Bet S5 Browser Accelerator** (Chrome + Safari WebExtensions with `declarativeNetRequest` redirect; intercepts ≥50 MB downloads + HLS/DASH manifest URLs; HLSProxyServer rewrites segment URLs through localhost proxy + pre-buffers via BondedFetcher's multi-interface bonded Range fetch + LRU ring buffer), **Bet S6 File Witness** (Ed25519-signed download receipts with standalone verifier), **9 publisher patterns** (Mozilla/Apache/Debian/Ubuntu/Arch/GitHub/kernel.org/PyPI/Hugging Face) for digest auto-extraction, and the localization audit-script + CI guardrails (whole-file scan, scans both public + Pro repos).

**Versioning policy (set 2026-05-05):** stop opening new sub-version branches (no more v1.7.x, v1.8.x, v1.9.x, S2/S3/etc.) — all forward work piles into the single "next-release rollup" until tagged.  Sub-versions were useful as in-flight planning labels but became unmanageable proliferation; consolidate at land time.

**Code-completeness:** every architectural item is wired + tested in unit + live form, with one exception:
- **SMJobBless privileged-helper bundle** is fully wired in `project.yml` (target declared, Info.plist with SMAuthorizedClients, embedded copy step in main app, SMPrivilegedExecutables in main app's Info.plist), but its **activation gate is maintainer-only**: requires `xcodegen generate && xcodebuild -scheme SplynekHelper`, swapping the dev OU=58C6YC5GB5 anchor for the Apple Distribution leaf cert SubjectKeyIdentifier, and smoke-testing against a sample admin .pkg.  Until those steps complete the helper is unreachable + every install path falls back to the v1.8.1 osascript admin route (which works today and ships).  Not a code-fixable gap from a Claude session.

The `main` branch carries the v1.6.x localization rounds AND the rollup
architecture above.  Info.plist intentionally still says 1.6.2 because
the rollup hasn't been visually + binary-tested as a single release;
tagging happens after the maintainer picks a cut point.  Holding all
release gestures (push tag, cut DMG, deploy landing, push cask) until
Apple v1.0 clears Mac App Store re-review.

Catalog state on `main` (after v1.6.2 rounds 1–8 + v1.7→v1.9.7 i18n adds + audit-extension catch-up + 2026-05-06/07 UI/UX + catalog-coverage sweep + five-track polish 2026-05-07):
- Mac Localizable.xcstrings: **628 strings × 5 locales** (en/pt-PT/es/fr/de/it) = **3,140 translations**.
- iOS Localizable.xcstrings (NEW 2026-05-07): **51 strings × 5 locales** = **255 translations**.  Combined catalog total = **3,395 translations.**
- Trust catalog: **151 entries** (was 30 at v1.6.0 start; +121 across the v1.6.x sprint), **88 fallback alternatives** across 43 entries (was 2 across 2 entries; +86 inherited from Sovereignty 2026-05-07; 8 carry verified `downloadURL`).
- Sovereignty catalog: 1,155 entries (unchanged since v1.4); **3,194 alternatives** total of which **257 (8.0%) carry a verified direct `downloadURL`** for one-click install (was 7.0% / 223 pre-sweep; +34 in 2026-05-07 push across Proton Pass / TeamViewer / DBeaver / AnyDesk).  Coverage is auto-pruned weekly — the cron strips broken downloadURLs and opens a PR for review (see "URL verification automation" below).

The `main` branch carries v1.5.4 → v1.6.2 commits but **none are tagged or uploaded yet**. They're staged to ship as a single rolled-up `v1.6.2` release once Apple clears v1.0 (we hold the DMG cut so an Apple Reviewer who URL-spelunks doesn't pull in newer behaviour they didn't approve).

What's bundled:

- **v1.5.4** — Trust score weights UI (Settings → 4 sliders), per-axis score breakdown in TrustView, `InfoPlistSyncTests` invariant (caught real version-drift bug).
- **v1.5.5** — catalog debt clearance, dead BIS URL replaced, validator runs at zero warnings.
- **v1.5.6** — weekly workflow hardening: real-rot-vs-transient classification in `check-urls.swift`, `permissions: issues: write`, `swift run splynek-test` removed from lint job (OOM on the 22k-line generated catalog).
- **v1.5.6+** — hardening pass: `os.Logger` framework added, `LANPeer` GCD/Task tangle untangled, `FleetCoordinator` rate-limit GC moved off hot path, `WatchedFolder` reentrancy guard, `TorrentEngine` force-unwrap rewritten, accessibility pass on TrustView / SovereigntyView / SettingsView, release-coherence invariant test.
- **v1.6.0** — Splynek as a programmable platform: **MCP server** (8 tools, JSON-RPC 2.0 over POST, off by default, opt-in via Settings), **Spotlight catalog indexing** (Sovereignty + Trust now system-wide searchable), **3 new catalog-aware App Intents** (`LookupSovereigntyIntent`, `LookupTrustIntent`, `RunSovereigntyScanIntent`).  Setup docs in `MCP_SETUP.md`.
- **v1.6.1** — onboarding sheet (3-step first-run), audit hardening (validate-mcp.sh stdout fix, AppShortcut phrase repair, `SplynekVersion` single-source-of-truth, `Scripts/compile-xcstrings.py` for SwiftPM .xcstrings → .strings, `.lproj` mirroring in build.sh), Bundle.module → Bundle.main fix for SwiftUI Text resolution.
- **v1.6.2 round 1–6** — full localization sweep. Catalog grew **56 → 387 strings** (×7) across 6 rounds:
  - Round 1: long-tail sweep (139 → 194). Round 2: pt-PT critical pass + Trust 60→101 (194→221).  Round 3: Branding + docs (221→255 + Trust 101→151).  Round 4: 255→340 + 5 verbatim-Text code fixes (label two-builder form, MetricView caption, Markdown body keys with backticks/curly quotes).  Round 5: full audit fixes — EmptyStateView wrap, MetricView caption, ContextCard giant-rectangle bug.  Round 6: Frota column captions (ADVERTISED→ANUNCIADO etc.), 8 MCP tool descriptions, ~30 long-tail strings.
  - Patterns established: every `String` rendered as user text is now wrapped in `LocalizedStringKey` (`Text(LocalizedStringKey(s))`) — see `Components.swift::StatusPill / EmptyStateView / MetricView / TitledCard`. Catalog source-of-truth is `Scripts/regenerate-localizations.py`; never hand-edit `Localizable.xcstrings`. Audit script at `Scripts/find-missing-translations.py` flags any view-layer string literal not in the catalog.

- **v1.6.2 round 7–8** — closes the localization gap.  Round 7 absorbed
  the 42 plain long-tail strings (387→428).  Round 8 added 28 format-spec
  catalog entries for interpolated strings + upgraded the audit to be
  type-blind (handles `%@` ↔ `%lld` ambiguity) + paren-aware (balanced-
  paren scanner replaces the regex; correctly walks `\(formatDuration(
  finished.timeIntervalSince(started)))`).  Audit reports 0 missing.

- **2.5.2 defence packet** (no version bump — landed alongside round 8).
  Apple began enforcing App Store Review Guideline 2.5.2 against
  "vibe coding" apps in early 2026.  Splynek's vocabulary (Concierge,
  natural-language goals, local LLM, MCP) sits in that space, even
  though the architecture is distinct.  Shipped: `MAS-2.5.2-COMPLIANCE.md`
  (paste-into-Resolution-Center brief, 8 architectural invariants each
  anchored to file::identifier), `MAS_LISTING.md` review-notes update
  with proactive 2.5.2 disclosure, architectural-invariant header
  comments on `MCPTools.swift` / `MCPServer.swift` / `Probe.swift`,
  `SECURITY.md` "AI boundaries" section.

- **v1.7 — Concierge as Mac Assistant.**  The Concierge LLM picks among
  a fixed compile-time tool registry of 8 tools (`download_by_goal`,
  `search_history`, `disk_usage`, `installed_apps`, `sovereignty_report`,
  `trust_report`, `summarize_pdf`, `recent_activity`).  Output decoded
  through `Codable`, dispatched via `LiveConciergeBridge`, rendered in
  `ConciergeView` as multi-card chat output (`ConciergeCardView` in
  splynek-pro).  3 new App Intents (`SearchDownloadHistoryIntent`,
  `DiskUsageReportIntent`, `SummarizeFileIntent`) expose the same
  surface to Shortcuts.  Plus public-repo support types: `HistorySearch`
  (ranked tokenized history search), `DiskUsageScanner` (sandbox-safe
  top-N enumerator), `PDFSummarizer` (PDFKit text extraction with
  prompt builder).  ~300 lines in splynek-pro for `ConciergeMacAssistant`
  (the dispatcher).

- **v1.8 — Verified Installer.**  Drag a `.dmg` / `.zip` / `.app` onto
  the Install tab; Splynek runs the 7-stage pipeline (resolve →
  trustCheck → sovereigntyCheck → downloading → verifying →
  installing → registering).  Handlers: `AppMover` (FileManager copy),
  `DmgInstaller` (hdiutil mount/copy/unmount), `ZipInstaller` (ditto),
  `PkgInstaller` (user-domain installer(8); admin-domain deferred to
  v1.8.1 with Authorization framework).  `InstallVerification` streams
  SHA-256 + Gatekeeper verifies before any handler runs.
  `InstalledAppRegistry` persists what's installed.  `AutoUpdateScheduler`
  re-runs the pipeline every 6h against opted-in apps.  `InstallView`
  surfaces all of this with progress card + activity card +
  per-record auto-update toggles.

- **v1.7.x — Concierge input-bar routing polish** (2026-05-04).  Typed
  input now flows through the Mac-Assistant dispatcher (same path the
  v1.7 suggestion chips use).  Bridge surfaces a typed
  `ConciergeCard.downloadByGoal(goal:)` for download intents; Pro
  `conciergeAsk` intercepts that case and forwards to the legacy
  `ai.concierge(goal)` URL-resolution path so the user sees a real
  download offer, not a placeholder.  The legacy `conciergeSend` path
  stays for Spotlight + AppIntents + menu-bar callers (and for chips
  that explicitly want the chat-action behaviour).

- **v1.8.1 — `.pkg` admin-domain installs** (2026-05-04).  PkgInstaller
  gains `requireAdmin: Bool = false`.  When opted in, spawns
  `/usr/bin/osascript` with `do shell script "..." with administrator
  privileges`, surfacing macOS's standard authorization dialog (Touch
  ID / password).  Refuses non-user-domain targets with a clear
  `.requiresAdmin` error when `requireAdmin: false`.  Detects user-
  cancelled-the-dialog via osascript exit code -128 → typed
  `.adminDeclined`.  AppleScript fragment is hard-coded (no attacker-
  controlled string concat); .pkg path is shell-quoted defensively;
  .pkg has already been SHA-256 + Gatekeeper verified by the time
  this method runs.  SMJobBless privileged-helper bundle is the
  v1.8.2 path if osascript becomes flagged; design doc lives in
  `docs/SMJOB-BLESS-DESIGN.md` (see below).

- **v1.9.x — Warm-cache + household-swarm-token + LAN auto-join**
  (2026-05-03 → 2026-05-04).  Catches three more pieces of the v1.9
  story across follow-ups:
  - **Engine warm-cache (digest-based dup detection).**
    `Duplicate.findMatch(forDigest:)` + `Duplicate.warmCacheLookup(
    url:digest:)` — when the user pastes a URL + publisher SHA-256,
    or a v1.8 install spec / v1.9 swarm announce hands us a digest
    with no URL, the duplicate banner short-circuits the WAN
    download.  Digest match wins over URL match (more trusted; bytes
    are identical by definition).  Reveal-in-Finder + Re-download
    Anyway buttons preserved from the existing duplicate-banner UI.
  - **Household swarm token.**  Settings → "Household swarm token"
    SecureField.  Set the same string on every Mac in the household;
    SwarmCoordinator accepts it as a SECOND valid bearer on token-
    gated swarm routes.  Empty disables Mac-to-Mac auto-join (loop-
    back + phone-QR flows still work).  Trust model: token grants
    "ride along" power, not "tamper" power — every chunk is SHA-256-
    verified before disk write.
  - **Auto-join from `peerSwarms` updates.**  VM observer hands fresh
    listings to `autoJoinSwarms`; for each Listing whose
    contentDigest matches an active local job's `sha256Expected`,
    spawns a SwarmParticipant that pulls chunks via the household
    token + feeds them through DownloadEngine's new
    `ingestExternalChunk(index:bytes:)` port.

- **v1.7.x cont. — visual sweeps + audit-script extension** (2026-05-05).
  All 4 non-PT-PT locales (de / es / fr / it) walked end-to-end through
  Install + sidebar + content tabs.  3 InstallView strings caught
  + fixed in DE+FR pass.  `Scripts/find-missing-translations.py`
  extended with 6 component-builder regex patterns
  (ContextCard.subtitle, TitledCard.title, EmptyStateView.title +
  message, MetricView.caption, StatusPill.text) — surfaced 49 strings
  the audit was hiding across the full app.  Catalog 480 → 535
  strings × 5 locales = 2,675 translations.

- **v1.9.x cont. — PublisherPattern enrichment, 5 publishers**
  (2026-05-05).  Started with Mozilla as proof-of-concept; extended
  to Apache (per-file `.sha256` siblings on apache.org), Debian
  (per-release SHA256SUMS at cdimage.debian.org), Ubuntu (same
  shape on releases.ubuntu.com), Arch (`sha256sums.txt` lowercase
  on archlinux.org).  Shared `fetchAndParseSUMS` + `fetchSimpleSHA`
  helpers.  15 tests: host-matching, parser-edge-cases, registry-
  walk.  Triggers warm-cache short-circuits against publisher URLs
  alone (no manual SHA paste required).

- **v1.8.2 — SMJobBless privileged-helper bundle** (2026-05-05).
  Full implementation of the design in `docs/SMJOB-BLESS-DESIGN.md`:
    - `Sources/SplynekHelper/` — main.swift + HelperListenerDelegate
      + HelperService + Info.plist + launchd plist + entitlements.
      HelperService validates target ∈ {/, LocalSystem,
      CurrentUserHomeDirectory}, re-imports + verifies the
      Authorization right, spawns /usr/sbin/installer with hard-
      coded args.
    - `Sources/SplynekCore/Installer/PrivilegedHelperClient.swift`
      — activated.  SMAppService.daemon.register +
      AuthorizationCopyRights + NSXPCConnection + serialised
      AuthorizationExternalForm hop.  Gated `#if canImport(Service
      Management)` + `@available(macOS 13, *)` so SwiftPM tests
      + non-Apple builds keep returning .helperUnavailable.
    - `PkgInstaller.install(requireAdmin: true)` now tries the
      helper first; .helperUnavailable / .xpcConnectionFailed →
      falls back to v1.8.1's osascript-elevated installer(8) path.
    - `project.yml` declares the SplynekHelper target +
      Splynek-MAS's SMPrivilegedExecutables key + reciprocal
      code-signing requirement.

  **Activation gate (maintainer steps):** xcodegen generate +
  xcodebuild -scheme SplynekHelper + replace dev OU=58C6YC5GB5
  anchor strings with the Apple Distribution leaf-cert
  SubjectKeyIdentifier + smoke-test against a sample admin .pkg.
  Until those steps complete, the helper is unreachable + every
  .pkg admin install falls through to the v1.8.1 osascript path
  — zero behavioural change for users today.

- **v1.9 — Fleet 2.0 LAN peer cache.**  Two Macs configured with the
  same household swarm token (Settings → "Household swarm token") now
  auto-share download bytes over the LAN:
  - Engine fires `swarmHooks.register/markSeederCompleted/finished`
    at lifecycle points; SwarmCoordinator publishes `/splynek/v1/swarm/
    {jobID}/{manifest,chunks/N,contribute,leave}` over the existing
    fleet REST plumbing.
  - `SwarmContentCache` keeps completed downloads serveable past the
    job's lifetime via SHA-256 lookup.
  - Bonjour TXT advertises `swarm=1` capability flag.
    `/splynek/v1/swarm/list` (no auth) lists active swarms.
    `SwarmAnnouncementObserver` polls every 10s + populates
    `vm.peerSwarms`.
  - `autoJoinSwarms` matches peer-listing `contentDigest` against
    in-flight local jobs' `sha256Expected`; on hit, spawns
    `SwarmParticipant` which fetches manifest + chunks via the
    household token + verifies each chunk's SHA-256 + delivers via
    new engine port `ingestExternalChunk(index:bytes:)`.
  - Fleet UI badge (`N SWARM` + tooltip) per peer.

  No new entitlements (the existing `network.client` + `network.server`
  cover everything).  Trust model: household token grants "ride along"
  power, not "tamper" power — every chunk is SHA-256-verified before
  disk write, so a malicious peer with the token cannot inject corrupt
  bytes.  Per-chunk verification is non-negotiable.

Mac App Store v1.0 is in re-review since 2026-04-26 (resubmitted with Resolution Center reply + edit-and-save touch). **DO NOT `xcodebuild archive -scheme Splynek-MAS` and submit while v1.0 is in flight** — that replaces the in-queue binary with one carrying the v1.6 metadata Apple Reviewer would never have looked at. The DMG / Developer-ID stream (`./Scripts/build.sh`) is independent and safe to re-cut at any time.

**MCP / Spotlight / AppIntents safety story for App Review:**  no new entitlements (`network.server` already granted); MCP off by default and gated by an opt-in toggle; Spotlight catalog index uses public ship-with-the-app catalog data, not user-installed-app metadata; new App Intents read the same compile-time catalog the in-app tabs do.  Each surface is independently documented in code comments at its module head.

---

## ⚡ Audit + live-test pass (2026-05-04 evening)

A focused audit + live-driven UI test landed late in the day after the
S2 + UX-trio + engine-internal-restart + Fedora work.  Captured here
because the next session should know what was probed + what came back.

**Audit findings (5 issues, 3 fixed in `b9e4e97`):**

1. ✅ Fixed: `DownloadEngine.pathObserverTask` leaked on the
   exception path — the catch handler at the do/catch boundary only
   cleaned up `historyTimerTask`.  Replaced post-loop cancel with
   `defer { pathObserverTask?.cancel(); pathObserverTask = nil }`
   at the start of the active-phase block.
2. ✅ Fixed: VM `handlePathEvent` race — `job.pause()` is async +
   flips lifecycle to `.paused` only after engine.run() exits via
   settleAfterRun.  Rapid offline→online (~ms) could fire resume
   before lifecycle flipped → DownloadJob.resume() no-ops on active
   jobs → job stuck paused.  Fix: 250ms `Task.sleep` before resume.
3. ✅ Fixed: `MirrorManifest` Wayback URLs hardcoded `/web/2024/`
   across all 3 sets (Ubuntu, Debian, Fedora).  Drops with year
   to use Wayback's auto-resolve-latest-snapshot behaviour.
4. ⏸ Deferred: Trust PDF single-page render clips if catalog matches
   overflow US Letter — known limitation flagged at ship time.
5. ⏸ Deferred: Sovereignty CSV `#`-prefixed schema-version comment is
   non-RFC-4180.  Some strict parsers might choke; every tool we
   care about (Numbers, csv.reader, awk) tolerates.

**Live-test pass (built `./Scripts/build.sh debug`, drove via
computer-use under user's pt-PT locale):**

- ✅ Trust **Export PDF** — verified end-to-end.  Renders cleanly: title,
  date, methodology blurb naming source allowlist (Apple privacy
  labels / NVD / HIBP / FTC / SEC / EU DPA / vendor advisories),
  summary stats (1 reviewed / 0 severe / 1 high / 0 moderate / 0
  low), Chrome 75/100 with 3 cited concerns, footer slogan.
- ✅ Trust **Export PNG** — verified.  1200×1200, top-N=1 with
  Chrome card + footer slogan.  Note: PNG looks sparse with 1
  cataloged app + 9 empty rows of canvas — acceptable for a Mac
  with sparse Trust catalog hits, would be tighter with 5–10 apps.
- ✅ Sovereignty **Export CSV** — verified.  9 rows under sample
  `~/Documents/splynek-sovereignty-2026-05-04.csv`: 1Password →
  Bitwarden + KeePassXC, Claude Desktop → LM Studio + Mistral Le
  Chat, Chrome → Firefox + Vivaldi, Perplexity → Mistral Le Chat
  + LM Studio.  10 columns, RFC 4180 quoting working ("AGPL.
  Free tier generous, self-hostable via Vaultwarden." quoted),
  schema-version comment, ISO-8601 timestamps.
- 🔧 Live-test fix #1 (`b07d788`): SovereigntyView filterBar
  segmented-picker clipped pt-PT label — "Todas as alternativas"
  rendered as "…as as alternativas" because EN-sized
  `.frame(maxWidth: 320)` couldn't fit the +25% pt-PT length.
  ZStack-with-overlay restructure: Picker dead-center of pane,
  count overlaid trailing.  Works for every locale label length.
- 🔧 Live-test fix #2 (`b07d788`): NSSavePanel.message dropped from
  the 3 export panels.  Three lookup APIs (String(localized:bundle:),
  NSLocalizedString(_:bundle:), Bundle.module.localizedString
  (forKey:value:table:)) all returned English even though
  SwiftUI's Text(LocalizedStringKey) resolves correctly against
  the same Bundle.module + the .strings file has the pt-PT key
  byte-identical.  Likely a SwiftPM xcstrings→.strings pipeline
  quirk for AppKit-side lookup; not worth tracking down for a
  nice-to-have caption.  Save panels still work cleanly.
- ✅ Verified non-bug: Firefox "Instalar" button apparent-white-text
  reported as readability issue — confirmed live to be the standard
  macOS modal-dim state when NSSavePanel is foregrounded.

What's NOT yet live-tested (deferred):
- Concierge (Pro tab — locked-upsell branch was the only thing
  reachable on free-tier; the actual chat surface needs a Pro
  license to exercise)
- Install tab (drop targets need real .dmg / .pkg / .app to
  exercise; manual maintainer work)
- Downloads tab end-to-end (paste a URL + click Start; partial
  test would only show planning + not exercise the new S2 wire-up
  which needs network state changes mid-download)
- Concierge PDF drag-to-summarize (ConciergeView in Pro repo;
  not in the public-only debug build)

## ⚡ Session handoff — current state (2026-05-04)

**For a fresh session picking this up.** TL;DR: localization closed at
**535 strings × 5 locales = 2,675 translations** (audit-script
extension surfaced 49 hidden strings; all fixed; 0 missing).  **All 4
non-PT-PT locales (de/es/fr/it) walked end-to-end + verified clean.**
**Next-release rollup landed** — Concierge-as-Mac-Assistant with
unified typed-input routing + chat-history persistence across
launches (`ConciergeTranscriptStore`) + PDF drag-to-summarize on
the Concierge tab; Verified Installer with all 4 kind handlers
including admin-domain .pkg via osascript + SMJobBless privileged-
helper bundle wired (activation gate is maintainer-only: xcodegen
+ xcodebuild -scheme SplynekHelper + Apple Distribution leaf-SKID
swap + .pkg smoke test); Fleet 2.0 LAN peer cache with full
discovery + auto-join + warm-cache digest dup-detection;
PublisherPattern enrichment for 6 publishers (Mozilla / Apache /
Debian / Ubuntu / Arch / GitHub Releases); **Unbreakable Resume**
active end-to-end (`PathMonitorObserver` auto-pauses on Wi-Fi
drop + auto-resumes on Wi-Fi return; `MirrorManifest` injects
curated Tier-1 mirrors as parallel lanes alongside the primary URL,
sidecar preserves resume state across all of it; resume guard
fixed in `8a2940b` — bug had been there since v0.31).
**552 tests passing, 0 build warnings on clean rebuild.**  Apple v1.0 still
pending re-review (day 8 → maintainer should consider Resolution
Center escalation by day 10); ASC monitor running daily.  Marketing
still staged.  Nothing pushed, nothing tagged — `main` is hot but
uncommitted-to-release.

The natural release cut here is `v1.7` (or rolled-up v2.0 — maintainer's
call), gated on Apple's v1.0 clearing.

### Fresh-session quick-start

```bash
# 1. Cold-launch verify (confirms main still builds + tests + audit clean)
cd "/Users/pcgm/Claude Code"
git status                            # both repos must be clean
swift build                           # < 10s, must succeed
./.build/debug/splynek-test           # must show 552/552
python3 Scripts/find-missing-translations.py  # must show 0 missing

# 2. Read the latest 5 commits to see what just landed
git log --oneline -5

# 3. Check Apple v1.0 review status
open https://appstoreconnect.apple.com
# (ASC monitor cron also fires daily 09:00 UTC + sends notification)

# 4. Pick from the next-bites queue (later in this doc) or
#    ask the user what to work on.
```

If the user asks "what's left?", read SESSION-LOG.md (companion
doc that captures the full v1.6.2 → v1.9.7 + v1.8.2 arc with every
commit, every architectural decision, and every open position).

### What's running

| Track | State | Where |
|---|---|---|
| **Apple App Store v1.0 review** | ⏳ Resubmitted 2026-04-26 (VPN-clarification Resolution Center reply + App Review Notes update + clicked "Atualizar revisão"). Status as of 2026-05-04: still in re-review, **day 8** — at the upper edge of the typical 1-7 day window.  **Maintainer should consider Resolution Center escalation by day 10** if no movement.  Sample message ready: ask reviewer for an ETA, mention the v1.0 binary has been in queue since 2026-04-26 (8 days), reaffirm no VPN/NetworkExtension entitlement.  ASC monitor cron `trig_01FdTsuA5J9d85sknvtFZTHj` fires daily 09:00 UTC against iTunes Lookup API; will send HIGH-priority notification when the binary lands.  **The 2.5.2 defence packet is staged** — if Apple cites 2.5.2, paste `MAS-2.5.2-COMPLIANCE.md` into Resolution Center. | App Store Connect |
| **Sovereignty cron trigger** | ⏳ First fire **2026-05-01 09:00 UTC**. Public repo only; drafts up to 20 catalog entries from `Scripts/sources/*.json`, opens PR. | https://claude.ai/code/scheduled/trig_01JEuDpurUC21nHkumwdEfaB |
| **Trust cron trigger** | ⏳ First fire **2026-05-15 09:00 UTC**. Refreshes catalog entries with `lastReviewed > 90 days`, checks NVD + HIBP for new findings, opens PR. | https://claude.ai/code/scheduled/trig_01VZNTUM4ikbYH5XBtpnn1ER |
| **Quarterly audit cron** | ⏳ First fire **2026-06-01 09:00 UTC**. Audits a rotating area (Q1=networking, Q2=views, Q3=scripts, Q4=build), opens GitHub issue with `audit` label. | https://claude.ai/code/scheduled/trig_0161CxCRWwnG5F48ynpTaspi |
| **GitHub Actions weekly** | ✅ Live — runs Sovereignty validator + URL liveness check every Monday at 09:00 UTC.  **Plus auto-prune (added 2026-05-07):** Content-Type-aware verification of every `downloadURL` (a 200 OK that returns text/html is treated as broken because it's a landing page, not a binary installer); broken URLs auto-pruned + opened as a labeled PR for human review.  Never auto-merges. | `.github/workflows/sovereignty-weekly.yml` |
| **Homebrew tap** | ✅ Live at [`Splynek/homebrew-splynek`](https://github.com/Splynek/homebrew-splynek). Install: `brew install --cask Splynek/splynek/splynek`. | Self-hosted |
| **Upstream homebrew/cask** | ❌ PR #261294 auto-rejected (notability: 0 stars / 0 forks / 0 watchers vs ≥75 / ≥30 / ≥30 needed). Resubmit after Show HN drives stars. | https://github.com/Homebrew/homebrew-cask/pull/261294 |
| **splynek.app landing** | ⏸️ Still on v1.3 copy. New copy ready in `docs/index.v1.6.2.html.draft` (NOT live). Deploy: `mv docs/index.html docs/index.v1.4.previous.html && mv docs/index.v1.6.2.html.draft docs/index.html && git push` — **only after** v1.0 clears Apple. |
| **Press / Show HN / directory submissions** | ⏸️ All staged in `PRESS_KIT.md`, `SHOW_HN.md`, `DIRECTORIES.md`. Don't trigger before v1.0 clears (App reviewers may visit splynek.app and reject for marketing-vs-build inconsistency). |

### Repo state — both clean

| Repo | Branch | Latest commit | Status |
|---|---|---|---|
| `Splynek/splynek` (public) | `main` | `72e57b9` (Sovereignty: automate URL verification with Content-Type validation + auto-prune) — 99 commits ahead of origin | clean working tree |
| `Splynek/splynek-pro` (private) | `main` | `803b830` (ConciergeView layout fix — input bar via safeAreaInset) — 3 commits ahead of origin (commits: `c64deb1` PDF drag-to-summarize, `369a69d` MAS build fixes, `803b830` input bar fix) | clean |
| `Splynek/homebrew-splynek` (tap) | `main` | initial v1.5.3 cask | clean |

### Latest release artifact

- **DMG**: [Splynek-1.5.3.dmg](https://github.com/Splynek/splynek/releases/tag/v1.5.3) — 3.8 MB
- **SHA-256**: `4fe61bab5ee2eb847d789c7f8b2245bf6b180936ec231241284f20b968c0e6cb`
- **Notarised + stapled**: ✅ Apple notary status `Accepted`
- **Signed**: Developer ID Application: Paulo Moura (58C6YC5GB5)

### Critical files (don't break / always update together)

- **Version sources** (must stay in sync — `InfoPlistSyncTests` enforces):
  - `Resources/Info.plist` → `CFBundleShortVersionString`
  - `project.yml` → `MARKETING_VERSION`
  - `Extensions/Alfred/Splynek.alfredworkflow/info.plist` → `CFBundleShortVersionString`
- **Catalog generators** — never edit the generated `+Entries.swift` files directly:
  - `Scripts/sovereignty-catalog.json` → `Scripts/regenerate-sovereignty-catalog.swift` → `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`
  - `Scripts/trust-catalog.json` → `Scripts/regenerate-trust-catalog.swift` → `Sources/SplynekCore/TrustCatalog+Entries.swift`
- **Live website** — `docs/index.html` is what serves splynek.app. The `.draft` variant is staging.
- **Splynek.entitlements** — minimal entitlement set; do not add `NetworkExtension` (Apple reviewer specifically asked about VPN; we declared none).

### Common commands

```bash
# Build for testing
swift build --product Splynek                                 # debug, ~30s
.build/debug/Splynek                                          # run

# Build for release
SIGN_IDENTITY="Developer ID Application: Paulo Moura (58C6YC5GB5)" \
  ENTITLEMENTS="Resources/Splynek.entitlements" ./Scripts/build.sh
./Scripts/dmg.sh
xcrun notarytool submit build/Splynek.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple build/Splynek.dmg

# Tests + validators
swift run splynek-test                                        # 294 tests
swift Scripts/validate-catalog.swift                          # Sovereignty offline lint
swift Scripts/validate-trust-catalog.swift --strict           # Trust offline lint
swift Scripts/check-urls.swift --only-download                # online URL liveness (~3 min for 1155 entries)

# Catalog round-trip
swift run splynek-cli sovereignty-dump > Scripts/sovereignty-catalog.json   # Swift → JSON
swift Scripts/regenerate-sovereignty-catalog.swift                          # JSON → Swift
swift Scripts/regenerate-trust-catalog.swift

# Bump cask after a new release
git clone https://github.com/Splynek/homebrew-splynek /tmp/tap
cp Packaging/splynek.rb /tmp/tap/Casks/splynek.rb
cd /tmp/tap && git add . && git commit -m "splynek X.Y.Z" && git push

# Capture press screenshots
./Scripts/capture-screenshots.sh   # interactive — ~10 min for all 10
```

### When v1.0 clears Apple — the launch sequence

```bash
# 1. Update MAS version metadata → v1.5.3 (in App Store Connect, version page)

# 2. Upload v1.5.3 archive via Xcode Organizer → Distribute App → MAS

# 3. Deploy landing
cd "/Users/pcgm/Claude Code"
mv docs/index.html docs/index.v1.4.previous.html
mv docs/index.v1.6.2.html.draft docs/index.html
git add docs/ && git commit -m "landing: deploy v1.5.3" && git push

# 4. Capture screenshots (skipped this session — script ready)
./Scripts/capture-screenshots.sh

# 5. Wait for MAS Ready for Sale (~24h)

# 6. Show HN (Tuesday/Wednesday 14-16 UTC) — copy from SHOW_HN.md

# 7. Press emails in waves — templates in PRESS_KIT.md
#    Wave 1: EU sovereignty (Le Monde, Der Spiegel, El País, Repubblica, Politico EU, Heise)
#    Wave 2 (1h later): Privacy (Wired, FT, The Information, MIT TR, EFF, The Markup)
#    Wave 3 (1h later): Mac power-user (MacStories, 9to5Mac, Eclectic Light, MacRumors, Six Colors)

# 8. Directory submissions — pre-filled forms in DIRECTORIES.md (Tier 1 first)

# 9. Day 7: Product Hunt launch (Thursday)

# 10. After 75 stars on the upstream repo: resubmit homebrew/cask PR
```

### Next-bites queue (v1.7 has already shipped to `main`; this is what's NOT yet in)

After Apple v1.0 clears, the natural release cut for everything below is
`v1.7` or `v2.0` (maintainer's call).  Priority within the queue is up
for grabs:

**v1.8.1 — `.pkg` admin-domain installer.**  v1.8.0 ships user-domain
.pkg installs (most publisher app updates work).  Admin-domain (kexts,
LaunchDaemons, PrivilegedHelperTools) requires Apple's Authorization
framework + SMJobBless.  Multi-day work; its own MAS-review surface.
The v1.8.0 PkgInstaller cleanly surfaces `Failure.requiresAdmin` with
guidance for the v1.8.1 path.

**v1.9.x — engine-side warm-cache integration.**  The Fleet 2.0 swarm
serves bytes for arbitrary downloads, but doesn't yet pre-warm the
content cache for "predictable household" scenarios — Steam library
sync, Time Machine network targets, Photos library bootstrap.  Each
is a different integration: Steam needs to intercept its update URLs;
Time Machine needs an SMB-extension boundary; Photos needs iCloud
deep-link cooperation.  Pick the highest-value one first.

~~**Concierge Mac Assistant Pro polish.**~~ — **all three sub-items
shipped.** Inline typed-input through Mac-Assistant dispatcher landed
in v1.7.x (commit 3a97d2c on the Pro repo).  Card-history persistence
landed 2026-05-03 — `Sources/SplynekCore/ConciergeTranscriptStore.swift`
+ `ConciergeState` `didSet`-persists every chat mutation; load-on-init
restores the transcript text-only (cards intentionally dropped — see
the file header for why); 12 new tests covering round-trip + four
failure modes + retention cap + clear semantics.  PDF drag-to-summarize
landed 2026-05-04 — `.onDrop(of: [.pdf])` on `ConciergeView` with a
centered `.ultraThinMaterial` overlay banner ("Drop PDF to summarize");
free-tier returns false so `lockedUpsell` slot stays clean.  See
`a1fc19c` (public) + `c64deb1` (Pro).

~~**Localization cleanup — visual sweeps for de/es/fr/it.**~~ —
**done.** All 4 non-PT-PT locales walked end-to-end 2026-05-05;
DE+FR pass caught 6 InstallView strings flipped to `LocalizedStringKey`;
audit-script extension (commit `e40fe01`) surfaced 49 hidden strings
across 6 component-builder regex patterns; catalog 480 → 535 × 5 =
2,675 translations.  See the "Localization state machine" section
below for the now-canonical pipeline.

**MAS resubmit when v1.0 clears.**  Re-cut the MAS xcarchive against
the v1.7+ commits, upload via Xcode Organizer, attach the existing
review-notes block (which now includes the 2.5.2 disclosure
paragraph from `MAS_LISTING.md`).

**Marketing-on-clear:**

- **A.** Resubmit upstream homebrew/cask PR (after Show HN reaches 75 stars)
- **B.** Stripe + Postmark direct channel (see `MONETIZATION.md`) — alternative to MAS for users who can't pay via App Store
- **C.** Native-speaker review for FR + DE before the press wave (see `L10N-REVIEW.md`)
- **D.** v1.6 features deferred but still relevant: shareable Trust-scan report (PDF / shareable PNG), Sovereignty CSV export
- ~~**E.** S2 — Unbreakable Resume~~ — **shipped 2026-05-04.** All three components live: HTTP Range resume already in `DownloadEngine.swift`; `PathMonitorObserver` (`281c336`) auto-pauses on offline + auto-resumes on online via `DownloadJob.pause()`/`resume()` + sidecar preserve; `MirrorManifest` (`dd8cb1e` + `b46adb3`) injects curated Tier-1 mirrors as parallel lanes at engine creation time so primary + mirrors run simultaneously, with per-chunk SHA-256 (when supplied) gating correctness across every source.  Engine internals untouched throughout — the v1.x multi-URL surface (engine `urls: [URL]` + lane round-robin) was the existing seam.  Last-resort archive entries (web.archive.org) live in `lastResortAlternatives(for:)` for manual UI affordances; not yet wired.
- **F.** S5 — Splynek Accelerator (browser extension + HLS pre-buffer)
- ~~**G.** iOS Companion (Share Extension + Live Activity)~~ — **foundation + phase 2 + phase 3 + polish all shipped 2026-05-07.**  Three iOS targets in `project.yml` (SplynekCompanion app + SplynekShareExtension + SplynekCompanionWidgets); shared core under `iOS/Shared/` exposed as `SplynekCompanionCore` SwiftPM library, also depended on by `SplynekCore` so the Mac receiver shares the relay schema.  **Phase 1**: Bonjour discovery + token-paste pairing + Share Extension URL submission + `/api/jobs` polling.  **Phase 2**: **Live Activity** for in-progress downloads on lock screen + Dynamic Island, **mirrored into the Mac menu bar by macOS 26 Continuity passthrough** (no Mac widget code); **QR-code pairing** (`splynek://pair?...` from Mac Settings + iOS AVFoundation scanner).  **Phase 3 (CloudKit over-cellular relay)**: when LAN fails the iOS Share Extension transparently falls back to writing a SplynekRelayJob record to the user's *private* CloudKit database; the Mac's new `CloudKitRelayReceiver` polls every 60s, ingests pending records targeting its deviceUUID, marks consumed.  No APNs, no server we run.  iCloud entitlements added on Mac + iOS + Share Extension; container `iCloud.app.splynek.companion` is maintainer-provisioned in App Store Connect (runbook in `IOS-COMPANION.md`).  **Polish**: third tab `SettingsView` exposing the cloudKitRelayEnabled toggle + per-Mac health rows (online / recent ≤24h / stale >24h) + "Test pairing" probe button + About; pure `PairingHealthEvaluator` classifier for the status badges.  **642 tests passing (+90 over pre-S4 baseline).**  TestFlight rollout gated on Apple v1.0 macOS clearance.

### Pending tech debt (non-blocking)

All four debt items cleared 2026-04-26:

- ~~85 lint warnings in Sovereignty catalog~~ — **resolved.** Two passes via `Scripts/sovereignty-catalog.json` enriched 189 short-note alternatives across 27 alt-template suffixes (grafana, loop, audacity, inkscape, gimp, restic, bitwarden, obs, keepassxc, mistral, tesseract, clamav, f-secure, jitsi, element + 12 more). Validator now reports 0 errors / 0 warnings / 0 info on 1155 entries.
- ~~`Marketing/screenshots/` and `Scripts/make-mas-screenshots.sh` stale~~ — deleted (screenshots predated v1.5 redesign; capture fresh via `Scripts/capture-screenshots.sh` for MAS resubmission).
- `homebrew-cask` upstream PR (#261294) closed at notability; resubmit when stars cross 75. Thread is the timestamp record — leave it.
- ~~4 Trust catalog entries with >18-month-old sources~~ — **re-verified 2026-04-26.** BIS URL was actually dead (redirected to homepage); replaced with the canonical Federal Register Final Determination 2024-13869 URL. CISA URL blocks bots but works in browser. HIBP entries (Adobe 2013, Evernote 2013) are page-anchors that work in browser; substantively still correct (a 2013 breach is a 2013 breach). All 5 entries' `lastReviewed` bumped to 2026-04-26. Added `Federal Register` to validator's `knownSources` allowlist.

### Architecture inventory — next-release rollup (sub-version labels are historical only)

```
v1.7 — Concierge as Mac Assistant
  Sources/SplynekCore/ConciergeTools.swift                ← 8-tool registry (compile-time)
  Sources/SplynekCore/ConciergeBridge.swift               ← LiveConciergeBridge dispatcher
  Sources/SplynekCore/ConciergeTranscriptStore.swift      ← v1.7.x: chat persistence (load-on-init + didSet save)
  Sources/SplynekCore/HistorySearch.swift                 ← ranked history search
  Sources/SplynekCore/DiskUsageScanner.swift              ← top-N space-takers
  Sources/SplynekCore/PDFSummarizer.swift                 ← PDFKit text extraction
  Sources/SplynekCore/AppIntentsProvider.swift            ← +3 intents (Search/Disk/PDF)
  splynek-pro/Sources/SplynekPro/ConciergeMacAssistant.swift   ← LLM dispatcher (Pro)
  splynek-pro/Sources/SplynekPro/Views/ConciergeCardView.swift ← multi-card UI (Pro)
  splynek-pro/Sources/SplynekPro/Views/ConciergeView.swift     ← v1.7.x: PDF drag-to-summarize .onDrop wiring

S2 — Unbreakable Resume (active end-to-end)
  Sources/SplynekCore/PathMonitorObserver.swift           ← typed PathEvent stream over NWPathMonitor
  Sources/SplynekCore/MirrorManifest.swift                ← curated Tier-1 mirror sets (Ubuntu shipped; framework + comments for adding more)
  Sources/SplynekCore/ViewModel.swift                     ← startJob injects MirrorManifest.parallelAlternatives + path observer auto-pauses/resumes on online↔offline
  (HTTP Range resume + Merkle-verified segments already in DownloadEngine.swift)

v1.8 — Verified Installer
  Sources/SplynekCore/Installer/InstallSpec.swift                ← parsed spec types
  Sources/SplynekCore/Installer/InstalledAppRegistry.swift       ← persistence
  Sources/SplynekCore/Installer/InstallerEngine.swift            ← pipeline shell
  Sources/SplynekCore/Installer/InstallerEngine+Run.swift        ← 7-stage orchestrator
  Sources/SplynekCore/Installer/InstallVerification.swift        ← SHA-256 + Gatekeeper
  Sources/SplynekCore/Installer/AppMover.swift                   ← .app FileManager copy
  Sources/SplynekCore/Installer/DmgInstaller.swift               ← hdiutil mount/copy
  Sources/SplynekCore/Installer/ZipInstaller.swift               ← ditto-based extract
  Sources/SplynekCore/Installer/PkgInstaller.swift               ← user-domain installer(8)
  Sources/SplynekCore/Installer/AutoUpdateScheduler.swift        ← 6h periodic re-run
  Sources/SplynekCore/Views/InstallView.swift                    ← drop-target tab

v1.9 — Fleet 2.0 LAN peer cache
  Sources/SplynekCore/Fleet/FleetChunkSwarm.swift                ← protocol Codable types
  Sources/SplynekCore/Fleet/SwarmCoordinator.swift               ← seeder REST handler
  Sources/SplynekCore/Fleet/SwarmContentCache.swift              ← post-completion serve
  Sources/SplynekCore/Fleet/SwarmAnnouncementObserver.swift      ← peer-side poller
  Sources/SplynekCore/Fleet/SwarmParticipant.swift               ← peer fetch state machine

S3 — yt-dlp swallow (DMG-only dispatch)
  Sources/SplynekCore/YtDlpProbe.swift                           ← probe Homebrew/pip install paths + parse --version
  Sources/SplynekCore/YtDlpRunner.swift                          ← subprocess invocation + progress/bytes/title parsers
  Sources/SplynekCore/Views/DownloadView.swift                   ← ytDlpDispatchRow (purple card, host-aware, "Use yt-dlp" button)
  Sources/SplynekCore/ViewModel.swift                            ← dispatchYtDlp() wires into DownloadHistory record

S5 — Browser Accelerator (HLS+DASH bonded pre-buffer)
  Sources/SplynekCore/HLSManifest.swift                          ← HLS master/media parser, DRM detector, URL rewriter
  Sources/SplynekCore/DASHManifest.swift                         ← MPEG-DASH MPD parser + DRM (Widevine/PlayReady/FairPlay)
  Sources/SplynekCore/HLSRingBuffer.swift                        ← per-session 256 MB LRU segment cache
  Sources/SplynekCore/HLSProxyServer.swift                       ← /master + /v + /s routes; auto-detects HLS/DASH
  Sources/SplynekCore/BondedFetcher.swift                        ← multi-interface bonded Range fetch (LaneConnection-based)
  Sources/SplynekCore/FleetCoordinator.swift                     ← /hls/* dispatch + InterfaceDiscovery for BondedFetcher
  Extensions/Chrome/manifest.json + background.js + options.html ← declarativeNetRequest redirect, opt-in toggle
  Extensions/Safari-WebExtension/                                 ← .appex via xcodegen, JS ported with browser/chrome shim

S6 — File Witness (cryptographic download receipts)
  Sources/SplynekCore/DeviceKeyManager.swift                     ← per-device Ed25519 keypair in Keychain
  Sources/SplynekCore/DownloadReceipt.swift                      ← schema v1 + canonical-JSON sign/verify
  Sources/SplynekCore/ReceiptStore.swift                         ← ~/Library/Application Support/Splynek/receipts/
  Sources/SplynekCore/Views/HistoryDetailSheet.swift             ← "Export receipt" footer button (per-locale via directPlistLookup)
  Scripts/verify-splynek-receipt.swift                            ← standalone offline verifier CLI

Tests added across the v1.7 → S6 work
  Tests/SplynekTests/ConciergeBridgeTests.swift
  Tests/SplynekTests/HistorySearchTests.swift            (if present)
  Tests/SplynekTests/DiskUsageScannerTests.swift         (if present)
  Tests/SplynekTests/InstallVerificationTests.swift
  Tests/SplynekTests/AppMoverTests.swift
  Tests/SplynekTests/ZipInstallerTests.swift
  Tests/SplynekTests/InstalledAppRegistryTests.swift
  Tests/SplynekTests/AutoUpdateSchedulerTests.swift
  Tests/SplynekTests/SwarmCoordinatorTests.swift
  Tests/SplynekTests/SwarmContentCacheTests.swift
  Tests/SplynekTests/SwarmHooksTests.swift
  Tests/SplynekTests/SwarmAnnouncementObserverTests.swift
  Tests/SplynekTests/SwarmParticipantTests.swift
  Tests/SplynekTests/EngineExternalIngestTests.swift
  Tests/SplynekTests/FleetChunkSwarmTests.swift
  Tests/SplynekTests/LocalizableCatalogTests.swift       (catalog completeness invariant)
  Tests/SplynekTests/YtDlpProbeTests.swift               (S3 probe)
  Tests/SplynekTests/YtDlpRunnerTests.swift              (S3 parsers)
  Tests/SplynekTests/HLSManifestTests.swift              (S5 HLS parser + DRM + rewriter)
  Tests/SplynekTests/HLSRingBufferTests.swift            (S5 LRU eviction)
  Tests/SplynekTests/HLSProxyServerTests.swift           (S5 route parsing)
  Tests/SplynekTests/BondedFetcherTests.swift            (S5 splitRange)
  Tests/SplynekTests/DASHManifestTests.swift             (S5 DASH parser + DRM)
  Tests/SplynekTests/DownloadReceiptTests.swift          (S6 sign/verify roundtrip)
  Tests/SplynekTests/DownloadJobResumeTests.swift        (resume-button v0.31 fix)

Other v1.6.x → v1.9 docs the maintainer writes against
  MAS-2.5.2-COMPLIANCE.md     ← reviewer-facing brief on Apple's vibe-coding stance
  STRATEGY-v1.7-v1.9.md       ← the roadmap doc
  L10N-REVIEW.md              ← native-speaker contributor onramp
  RELEASE-NOTES-v1.6.2.draft.md ← release-notes template (still relevant for v1.7 cut)
```

### Things to NOT do without thinking

- **Don't push splynek.app changes** until v1.0 is `Ready for Sale` on App Store Connect.
- **Don't send press emails** until the landing matches what reviewers might see.
- **Don't merge cron-opened PRs blindly** — the agents draft, the maintainer approves.
- **Don't delete the upstream homebrew/cask PR** — closed is fine; the thread is the timestamp record.
- **Don't bump version in just one of the three plists** — InfoPlistSyncTests will fail.
- **Don't add `NetworkExtension` entitlement** — Apple already asked about VPN; we explicitly declared none.
- **Don't run cron triggers manually unless you understand they open PRs** — the dashboard has a "Run now" button; use it deliberately.

### How to ramp a fresh session in 5 minutes

```
1. Read HANDOFF.md (this file) top 300 lines
2. cd /Users/pcgm/Claude Code; git status (both repos must be clean)
3. swift run splynek-test (must show 552/552 — anything less is a regression)
4. python3 Scripts/find-missing-translations.py | head -5  → confirms catalog state
5. Open https://claude.ai/code/scheduled and check the four triggers fired clean
6. Open https://appstoreconnect.apple.com → Splynek → Distribuição → check v1.0 status
```

If everything green → ask the user what to work on. The "v1.6 candidates" list below is the queue.

### Localization state machine — closed at round 8

```
Catalog on `main`: 535 strings × 5 locales = 2,675 translations.
Audit (python3 Scripts/find-missing-translations.py): 0 missing.
The CI guardrail (.github/workflows/lint.yml) runs the audit on every
PR; any new Text("...") literal without a matching catalog entry
fails the workflow.

Pipeline (still relevant for adding strings as new features land):
  1. Edit Scripts/regenerate-localizations.py — add the new key with
     5 locale tuples (pt-PT/es/fr/de/it).
  2. python3 Scripts/regenerate-localizations.py
  3. swift build --target SplynekCore (must compile clean)
  4. python3 Scripts/find-missing-translations.py (must show 0 missing)
  5. swift run splynek-test --filter Localizable (catalog-completeness
     invariants — every key has all 5 locales, no empty values, ≥95%
     coverage per locale)
  6. Commit Scripts/regenerate-localizations.py + Localizable.xcstrings

Visual sweeps:
  - pt-PT was visually walked end-to-end through round 6.
  - de / es / fr / it are catalog-correct + machine-validated, but no
    human has eyeballed them in the running app.  ~30 minutes per
    locale to walk every tab.  See L10N-REVIEW.md for the contributor
    onramp (priority order: DE > FR > pt-PT > ES > IT).
```

---

## Shipped releases (in order)

All Developer-ID-signed, notarised, stapled, and published at
<https://github.com/Splynek/splynek/releases>. SHA-256 hashes match the
release-notes bodies.

### v1.5 — Trust tab (2026-04-25)
- New tab in the sidebar Ask section (next to Sovereignty). Free-tier; no PRO gate.
- **Source allowlist (legal/MAS guarantee):** every concern cites Apple App Store privacy labels, EU DPA / FTC / SEC rulings, NVD CVE, HIBP breaches, vendor security advisories, or vendor's own privacy policy. Editorial words (`spies`, `untrustworthy`, `you are the product`, etc.) are rejected by the regenerator. See `TRUST-CONTRIBUTING.md`.
- **30 deeply-cited initial entries** in `Scripts/trust-catalog.json` covering the most-installed apps (Chrome, Messenger, WhatsApp, Slack, Zoom, Teams, Dropbox, LastPass, TikTok, WeChat, Yandex Browser, Kaspersky, Adobe, ChatGPT, …).
- `TrustScorer` produces 0–100 score + categorical level (Low/Moderate/High/Severe). Pure + deterministic + weight-aware. UI always shows score + level + cited concern labels — never the score alone.
- **Alternatives lookup chain:** Sovereignty catalog (EU/OSS) first → Trust's own `fallbackAlternatives` → "no curated alt yet, contribute one".
- Pipeline mirrors Sovereignty: `Scripts/trust-catalog.json` → `regenerate-trust-catalog.swift` → `Sources/SplynekCore/TrustCatalog+Entries.swift`. Validator at `Scripts/validate-trust-catalog.swift --strict`.
- 18 new tests in `TrustCatalogTests` + `TrustScorerTests` — banned-phrase guard, HTTPS-only, ID uniqueness, scorer bounds, level thresholds.
- FR/DE/ES/IT localisation for all Trust strings.

### v1.4 — Catalog pipeline (90→1167) + discovery/quality engines + AI hardening + FR/DE/ES/IT (2026-04-24)
- **DMG**: not yet cut (waiting for this session's work to land). After commit + tag, run the Developer-ID build + notarise flow from the top of this file.
- **Catalog grew 13×** (90 → 1167 entries — a full order of magnitude). New authoring flow: edit `Scripts/sovereignty-catalog.json`, run `swift Scripts/regenerate-sovereignty-catalog.swift`, commit both the JSON and the regenerated `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`. See SOVEREIGNTY-CONTRIBUTING.md for the full pipeline. Compile-time type safety preserved; community can now PR via JSON diffs.
- **Discovery + quality engines** (v1.4 second pass — for indefinite catalog growth):
  - `Scripts/discover.swift` — finds new apps from external source files (`Scripts/sources/*.json`), local `/Applications/` (`--from-apps`), or display-name lists (`--from-file`); diffs against the catalog; emits `Scripts/candidates.json`.
  - `Scripts/ai-propose.swift` — drafts alt-sets for each candidate via local LLM (LM Studio, Ollama, OpenAI-compat). System prompt mirrors the FORBIDDEN PATTERNS block in `splynek-pro/AIAssistant.swift` to minimise US-leakage. Output: `Scripts/proposals.json`.
  - `Scripts/merge-proposals.swift` — reviewer-in-the-loop; interactive prompts (a/s/q) or `--auto-accept high` for trusted batches; validates against catalog invariants before merge.
  - `Scripts/validate-catalog.swift` — offline lint: bundle-ID format, dup IDs, short/long notes, non-https homepages, placeholder hosts. Errors are hard-fail; warnings flagged. `--strict` makes warnings fail too.
  - `Scripts/check-urls.swift` — concurrent online URL checker. Default 20 workers, 15s timeout per URL. `--json` for CI consumption, `--fail-on-rot` for non-zero exit. **Content-Type-aware (v1.5.7, 2026-05-07):** captures `Content-Type` per response; for `kind == "download"`, a 200 OK that returns text/html is flagged as `wrongContentType` rot — catches the GitHub `releases/latest/download/<file>.dmg` failure mode where artifact filenames embed versions and the redirect 404s into a friendly HTML page.  **Auto-prune:** `--prune-broken-downloads` rewrites the catalog in place, removing only the `downloadURL` field on broken alternatives (entry stays; falls back to homepage-only).  True rot only — transient failures are spared.  Idempotent: clean catalog runs as md5-unchanged no-op.
  - `.github/workflows/sovereignty-weekly.yml` — weekly cron: lint + regen-roundtrip + URL health.  Opens a labeled GitHub issue when URLs rotted, **and** runs `--prune-broken-downloads` in a third job that opens a PR via `peter-evans/create-pull-request@v6` for human review (never auto-merges, never runs on PRs).
- New `splynek-cli sovereignty-dump` subcommand: reverse-exports the catalog back to JSON (for verifying round-trip, or reseeding the JSON if Swift gets edited directly).
- The v1.4 bulk-seed itself is in `Scripts/seed-sovereignty-bulk.swift` — category templates × target tuples; idempotent, re-runnable. Useful for future bulk imports from curated external lists (european-alternatives.eu, switching.software, awesome-euro-tech).
- New `splynek-cli sovereignty-dump` subcommand: reverse-exports the catalog back to JSON (for verifying round-trip, or reseeding the JSON if Swift gets edited directly).
- **AI fallback hardening.** System prompt gains a FORBIDDEN PATTERNS block listing Netflix/YouTube/Discord/Slack/Dropbox/ChatGPT/etc. as things the model must NEVER propose. On top of that, a `sovereigntyDenyList` post-filter on `SovereigntySuggestion` strips any model-emitted name whose normalised form matches a known US/CN/RU product — belt + suspenders against the 3B model's hallucinations.
- **Localisation — FR / DE / ES / IT.** Sovereignty tab's ~30 UI strings now localised. New `Sources/SplynekCore/Localizable.xcstrings`. Package.swift gains `defaultLocalization: "en"` and declares the xcstrings as a processed resource. PageHeader widened to `LocalizedStringKey` (forward-compat; existing English-only callers unchanged).
- **Catalog invariant tests.** `Tests/SplynekTests/SovereigntyCatalogTests.swift` locks in contributor rules: every target is non-EU; every alt is .europe/.oss/.europeAndOSS/.other (never US/CN/RU); every entry has ≥1 recommendable alt; IDs unique; ≥100 entries. Test count: 117 → 124.
- Related commits: `/Users/pcgm/Claude Code` @ (pending) — `/Users/pcgm/splynek-pro` @ (pending)

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

v1.4 shipped the JSON-backed pipeline and took the catalog from 90 → 869 entries. Further growth is now mostly a data-curation exercise, not a code exercise.
- **Continue bulk imports** via `Scripts/seed-sovereignty-bulk.swift`. Easiest wins: mine [european-alternatives.eu](https://european-alternatives.eu/), [switching.software](https://switching.software/) (CC-BY), [awesome-euro-tech](https://github.com/) lists. Script is idempotent — re-running skips existing bundle IDs.
- **More `downloadURL`s** for popular alternatives that have stable canonical URLs. Firefox + Thunderbird currently work via Mozilla's redirect. Research: Signal, VLC, Bitwarden's desktop-download redirect, LibreOffice stable mirror. One afternoon of careful URL-verification per batch — prone to 404 rot if the author isn't careful.
- **Accuracy passes** — some v1.4 bulk entries have best-guess bundle IDs. High-value regression: an installed-apps scan on several real Macs, note which expected entries don't match, correct the bundle ID in JSON, regenerate. That's how the catalog goes from "comprehensive by count" to "comprehensive by hit-rate."
- **Invariants are test-enforced** (`SovereigntyCatalogTests`): every target is non-EU, every alternative is .europe/.oss/.europeAndOSS/.other (never US/CN/RU), every entry has ≥1 recommendable pick, IDs unique, catalog ≥ 500 entries (regression floor).

### C — Sovereignty AI-fallback prompt tuning (v1.4 pass shipped — future work optional)

v1.4 shipped a FORBIDDEN PATTERNS block in the system prompt + a `sovereigntyDenyList` post-filter (in `splynek-pro/AIAssistant.swift`) that strips known US/CN/RU products from model output. Future improvements if the 3B model still misbehaves:
- **A/B test**: adapt the `/tmp/concierge-ab/` harness for the sovereignty prompt and measure deny-list hit-rates across prompt variants.
- **Homepage TLD check**: reject suggestions whose homepage host resolves to a US-registered domain. Brittle (CloudFlare / CDN hosts confuse this); parking it.
- **Extend the deny-list** with new mis-suggestions as they surface in production. The deny-list is intentionally short and high-signal — false positives drop legit suggestions silently.

### D — Localisation (closed at round 8: 480 × 5 = 2,400 translations)

The catalog landed at **480 strings × 5 locales = 2,400 translations** at
v1.6.2 round 8 (2026-05-01).  Audit (`find-missing-translations.py`)
reports 0 missing.  Round 8 also upgraded the audit itself: balanced-paren
scanner replaces the regex (handles arbitrary nesting), type-blind
matching against `%@` ↔ `%lld` ambiguity, `\u{XXXX}` Swift-escape
decoder for false-positive elimination.  CI guardrail
(`.github/workflows/lint.yml`) blocks any PR that drops audit clean
state.

Pipeline (still relevant for adding strings as new features land):
- source-of-truth: `Scripts/regenerate-localizations.py`
- audit: `Scripts/find-missing-translations.py` (must report 0 missing)
- catalog completeness: `swift run splynek-test --filter Localizable`
- build pipeline auto-compiles xcstrings → .lproj

Remaining cosmetic work (none of it blocks shipping):
- **Visual sanity-sweep on de / es / fr / it.** pt-PT was walked end-
  to-end through round 6; the other 4 locales are catalog-correct +
  machine-validated, but no human has eyeballed them in the running
  app.  ~30 minutes per locale to walk every tab.
- **Native-speaker review** before the press wave — current translations
  are Claude-generated.  Flag FR + DE first (Sovereignty has the
  biggest credibility lift in those markets).  See `L10N-REVIEW.md`
  for the contributor onramp.
- **Arabic / ZH-HANS?** Only if Pro uptake in those markets warrants it.
  Not a priority.

### E — Monetization / marketing (unchanged from prior sessions)

- **Stripe + Postmark direct channel** — dual-channel revenue (see MONETIZATION.md). Not blocked; not started.
- **Show HN** — draft at `SHOW_HN.md`. Best done after MAS goes live. Rewrite around the Sovereignty angle: "Splynek — a Mac download manager that also helps you audit your software supply chain. All local, all private."
- **Product Hunt** — same timing.
- **Homebrew cask** — `Packaging/splynek.rb` is source-of-truth. v1.5.3 SHA: `4fe61bab5ee2eb847d789c7f8b2245bf6b180936ec231241284f20b968c0e6cb`. Two distribution paths:
  - **Splynek tap** ([github.com/Splynek/homebrew-splynek](https://github.com/Splynek/homebrew-splynek)) — live now. Install: `brew install --cask Splynek/splynek/splynek`. Bump for each release: clone the tap, copy the new `Packaging/splynek.rb` over `Casks/splynek.rb`, commit + push.
  - **Upstream homebrew/cask** — first submission (PR #261294, 2026-04-26) auto-rejected by `khipp` on notability heuristic (need ≥75 stars OR ≥30 forks OR ≥30 watchers; we had 0/0/0). Resubmit after MAS launch + Show HN coverage push the upstream repo across the bar. Reuse `Packaging/splynek.rb` placed at `Casks/s/splynek.rb` in a `homebrew-cask` fork.
- **EU press outreach** — Le Monde (FR), El País (ES), Der Spiegel (DE), Wired, FT. Hook: Sovereignty-tab scan video shot on a stock Mac. Co-ordinate with any MAS approval date to avoid review disruption.

### F — Future platform bets (scoped in STRATEGY-2026.md)

- **S2 — Unbreakable Resume** (HTTP Range + NWPathMonitor + curated mirror failover). Multi-week.
- **S5 — Splynek Accelerator** (browser extension + HLS pre-buffer). Multi-week.
- **S4 — iPhone Companion** — foundation shipped 2026-05-07 (iOS app + Share Extension + shared core, 579 tests passing).  Phase 2 (Live Activity with macOS-26 menu-bar mirror, QR pairing, CloudKit relay) is multi-day work each — see `IOS-COMPANION.md` punch list.

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
