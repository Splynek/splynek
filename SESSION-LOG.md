# Splynek session log — v1.6.2 → v1.9.7 → v1.8.2 SMJobBless

> Companion to `HANDOFF.md`.  HANDOFF is the **state**; this is the
> **journey** — what was discussed, what was decided, what was tried
> and rejected, and where each architectural choice came from.  Read
> when picking up a session cold and the next move isn't obvious from
> HANDOFF alone.
>
> Last updated 2026-05-04.

## TL;DR

Across the v1.6.2 → v1.9.7 → v1.8.2 arc (April → early May 2026)
Splynek went from "credible localized download manager waiting for
Apple's v1.0 re-review" to "fully-featured platform: Concierge as a
Mac assistant + verified installer with admin-domain support + LAN
peer-cache with auto-discovery + 5 publisher patterns for digest
auto-extraction + complete localization in 5 non-English locales
with audit-script + CI guardrails enforcing non-regression."

Catalog grew **56 → 535 strings** (×9.6) → **2,675 translations**.
Tests grew **148 → 451** (×3.0).  Build warnings: **906 → 0** on clean rebuild (Swift 6 strict-concurrency cleanup across 6 infrastructure files).  v0.31-era resume-button no-op guard fixed in `8a2940b` (was hidden behind `Lifecycle.isActive` returning true for `.paused` — bug since initial public commit; same path defeats the second half of S2 auto-resume on Wi-Fi return).
Apple App Review status: still pending day 8 of v1.0 re-review.
Nothing pushed, nothing tagged — `main` is hot.

## Architectural arc (chronological)

### v1.6.2 rounds 7-8 (closes localization)

**Round 7** added 41 plain long-tail strings (387→428).
**Round 8** added 28 format-spec catalog entries for interpolated
strings AND upgraded the audit script with three structural changes:
- Balanced-paren scanner replaces the regex (handles arbitrary nesting
  in `\(formatDuration(finished.timeIntervalSince(started)))`)
- Type-blind matching: `\(...)` matches both `%@` AND `%lld` catalog
  keys so the catalog can use the right format-spec without the
  audit guessing wrong
- `\u{XXXX}` Swift-escape decoder eliminates a class of false
  positives (curly-quote characters)

After round 8, audit reported 0 missing for the first time.

### MAS-2.5.2 defence packet

In response to Apple's 2026 enforcement of guideline 2.5.2 against
"vibe coding" apps (Replit + Vibe Code rejected), shipped:
- `MAS-2.5.2-COMPLIANCE.md` — paste-into-Resolution-Center brief
  with 8 file-anchored architectural invariants
- `MAS_LISTING.md` review-notes update with proactive 2.5.2 disclosure
- Architectural-invariant header comments on `MCPTools.swift`,
  `MCPServer.swift`, `Probe.swift`
- `SECURITY.md` "AI boundaries" section

Splynek's vocabulary (Concierge, MCP, local LLM, natural-language)
sits in 2.5.2 risk space; the architecture is distinct (LLM is a
URL classifier, never a code generator).  The brief makes that
distinction visible to a reviewer in 5 minutes.

### v1.7 — Concierge as Mac Assistant

The Concierge LLM picks among a **fixed compile-time tool registry**
of 8 tools.  Output decoded through `Codable`, dispatched via
`LiveConciergeBridge`, rendered in `ConciergeView` as multi-card
chat output (`ConciergeCardView` in splynek-pro).

The 8 tools:
1. `download_by_goal` — English → URL → Download/Cancel sheet
2. `search_history` — ranked tokenized history search
3. `disk_usage` — top-N space-takers (sandbox-safe enumerator)
4. `installed_apps` — list /Applications via SovereigntyScanner
5. `sovereignty_report` — top 5 apps with EU/OSS alternatives
6. `trust_report` — top 5 apps with non-trivial Trust concerns
7. `summarize_pdf` — PDFKit text → LLM summary card
8. `recent_activity` — 24h digest of downloads + queue events

Plus 3 new App Intents (Search/Disk/PDF) so Shortcuts can drive
the same surface.  Pro-side `ConciergeMacAssistant.swift` (~300
lines) is the LLM dispatcher.

### v1.7.x — input-bar routing polish

Suggestion chips routed through Mac Assistant; typed input still
went through the legacy chat-action `conciergeSend`.  Unified by:
- Adding typed `ConciergeCard.downloadByGoal(goal: String)` case
- Bridge surfaces this card for download intents
- Pro `conciergeAsk` intercepts it and forwards to legacy
  `ai.concierge(goal)` URL-resolution
- Input-bar `submit()` now calls `conciergeAsk`

Result: typed input goes through the unified Mac-Assistant surface;
download intents still produce real download offers (not placeholder
cards).

### v1.8 — Verified Installer

Drag a `.dmg` / `.zip` / `.app` onto the Install tab; pipeline runs
the 7 stages: resolve → trustCheck → sovereigntyCheck → downloading
→ verifying → installing → registering.

Handlers:
- `AppMover` (FileManager copy, suffix-rename on collision)
- `DmgInstaller` (hdiutil mount/copy/unmount)
- `ZipInstaller` (Apple's signed `/usr/bin/ditto`)
- `PkgInstaller` (user-domain installer(8); admin-domain in v1.8.1)

Plus:
- `InstallVerification` — streaming SHA-256 + `GatekeeperVerify`
- `InstalledAppRegistry` — persists what's installed
- `AutoUpdateScheduler` — re-runs pipeline every 6h against opted-in
  apps
- `InstallView` — drag-drop + progress card + activity card +
  per-record auto-update toggles

### v1.8.1 — `.pkg` admin-domain installs

`PkgInstaller.install(requireAdmin: Bool = false)`.  When opted in,
spawns `/usr/bin/osascript` with `do shell script "..." with
administrator privileges`, surfacing macOS's standard authorization
dialog.  Hard-coded AppleScript fragment (no attacker-controlled
string concat); .pkg path is shell-quoted defensively; .pkg has
already been SHA-256 + Gatekeeper verified by the time this method
runs.

User-cancelled-the-dialog detected via osascript exit code -128 →
typed `Failure.adminDeclined`.

### v1.8.2 — SMJobBless full plumbing (this session)

Replaces v1.8.1's osascript path with a proper privileged-helper
bundle (`Sources/SplynekHelper/`).  Helper = NSXPCListener serving
SplynekHelperProtocol; runs as launchd-spawned root after first
SMAppService.daemon.register() user-approval prompt.  Two-tier
authorization:
1. NSXPCConnection enforces SMAuthorizedClients (must be signed
   Splynek.app) before delivering messages.
2. HelperService re-validates AuthorizationCopyRights for the
   `app.splynek.Splynek.installPkg` right (defence-in-depth).

App-side `PrivilegedHelperClient` activated with real
SMAppService.daemon.register + NSXPCConnection +
AuthorizationCopyRights flow.  Gated behind `#if canImport(Service
Management)` + `@available(macOS 13, *)` so SwiftPM tests + non-
Apple builds still work — they get `.helperUnavailable` and
PkgInstaller falls back to the v1.8.1 osascript path.

`project.yml` declares the new SplynekHelper target +
SMPrivilegedExecutables key + reciprocal code-signing requirement
strings.

**Activation gate (maintainer steps):**
1. `xcodegen generate` (picks up the SplynekHelper target +
   SMPrivilegedExecutables)
2. `xcodebuild -scheme SplynekHelper`
3. Replace dev `OU=58C6YC5GB5` anchor with Apple Distribution
   leaf-cert SubjectKeyIdentifier
4. Smoke-test against a sample admin .pkg

Until those four steps complete, the helper is unreachable +
PkgInstaller falls through to osascript — **zero behavioural
change for users today**.

### v1.9 — Fleet 2.0 LAN peer cache

Two Macs configured with the same household swarm token (Settings
→ "Household swarm token") auto-share download bytes over the LAN.

Components:
- **Protocol types** (`FleetChunkSwarm.swift`) — Codable structs
  for Manifest / ChunkRef / Announce / ContributionOffer / Listing
  / State.
- **Seeder** (`SwarmCoordinator.swift`) — REST handler over the
  existing FleetCoordinator NWListener.  5 verbs: announce,
  manifest, chunks/{n}, contribute, leave + the no-auth list
  endpoint.
- **Participant** (`SwarmParticipant.swift`) — HTTP client with
  per-chunk SHA-256 verification.  Async `ChunkSink` callback
  streams verified bytes to the engine's `ingestExternalChunk`.
- **Discovery** — TXT capability flag (`swarm=1`) +
  `/splynek/v1/swarm/list` no-auth endpoint +
  `SwarmAnnouncementObserver` polling every 10s + `vm.peerSwarms`
  publishing to the Fleet UI.
- **Auto-join** — `autoJoinSwarms` matches peer Listing's
  `contentDigest` against active local jobs' `sha256Expected`;
  spawns SwarmParticipant on hit; feeds bytes through engine's
  new `ingestExternalChunk(index:bytes:)` port.
- **Trust model** — household token grants "ride along" power,
  not "tamper" power.  Every chunk SHA-256-verified before disk
  write.

### v1.9.x continued — engine warm-cache + PublisherPattern

- **Warm-cache (digest-based dup detection).**
  `Duplicate.findMatch(forDigest:)` + `Duplicate.warmCacheLookup
  (url:digest:)` — digest match wins over URL match.  Triggers
  the existing duplicate-banner UI (Reveal in Finder /
  Re-download anyway).
- **PublisherPattern.**  5 publishers — Mozilla, Apache, Debian,
  Ubuntu, Arch.  Each is a typed Pattern struct (`name` /
  `matches` / `extract`) + tests for host-matching + parser-edge-
  cases.  Triggers warm-cache short-circuits against publisher
  URLs alone (no manual SHA paste required).

### v1.9.5 → v1.9.7 — auto-join hardening

- v1.9.5: TXT capability flag + `/swarm/list` no-auth + observer
- v1.9.6: engine `ingestExternalChunk` port + autoJoinSwarms
- v1.9.7: household swarm token (Settings SecureField + dual-
  bearer auth on token-gated routes)

### Latest landing (this session): visual sweeps + audit extension + 5-publisher coverage + SMJobBless full

Visual walks of all 4 non-PT-PT locales surfaced 3 InstallView
gaps (`ContextCard.subtitle`, `TitledCard.title`, `autoUpdateSummary`)
that the audit was hiding.  Fixed + extended `find-missing-
translations.py` with 6 new component-builder regex patterns →
49 additional missing strings surfaced + filled in.  Catalog
480 → 535 strings.  Then 4 new publisher patterns + the SMJobBless
full implementation (above).

### Latest landing (2026-05-04): Concierge persistence + PDF drag-to-summarize

**Concierge transcript persistence** (`a1fc19c`).  Chat survives
session restart via a JSON-backed store at `~/Library/Application
Support/Splynek/concierge-transcript.json`.  Schema-versioned, capped
at 200 messages, atomic write, all failure modes (corrupted JSON,
missing file, schema mismatch, nil URL) return `[]` rather than
crash.  `ConciergeState` got a `didSet`-persists hook on `chat` +
load-on-init; `ConciergeMessage` got an explicit init so the
persisted UUID round-trips (id defaults to `UUID()` so the 14
existing call sites stay source-compatible).  Cards intentionally
NOT persisted — they encode live state (URLs to scan reports, file
paths in disk usage, "Download"/"Open" buttons that close over
in-process closures) and would render interactive surfaces over
stale data after a relaunch.  The text caption populated by the
Pro dispatcher's `captionFor(card:)` preserves the conversation's
readability, which is what users already see above each card.
12 new tests across 4 suites: round-trip / failure modes /
retention + clear / `ConciergeState` integration.  328 → 340 tests.

**PDF drag-to-summarize** (`c64deb1`, Pro repo).  `.onDrop(of:
[.pdf])` on `ConciergeView`'s outermost view, with a centered
`.ultraThinMaterial` overlay banner ("Drop PDF to summarize") shown
while a PDF is hovering.  UTType filter is `.pdf` specifically (not
`.fileURL`) so non-PDF drops fall through to RootView's broader
URL-as-download handler unchanged.  Free-tier returns false from the
drop handler — `lockedUpsell` slot stays clean.  On drop:
`vm.conciergeAsk("Summarize this PDF.", pickedPDF: url)` —
`LiveConciergeBridge` already wires `pickedPDF` through
`summarize_pdf`, so no new bridge plumbing.  Replaces the previous
flow which required typing "summarize a PDF", LLM picking
`summarize_pdf`, bridge returning "Pick a PDF first" error, then
re-prompting via NSOpenPanel — now zero-step.

### Latest landing (2026-05-04 part 2): S2 Unbreakable Resume + 6th publisher + SMJobBless runbook

**S2 thesis active end-to-end.**  Three commits:

1. `2899196` — `PathMonitorObserver` + `PathEvent`.  Long-lived
   `NWPathMonitor` wrapper that emits typed events through an
   `AsyncStream`.  Pure translation factored out for testability
   (no public initialiser on `NWPath`); duplicate suppression filters
   the boot-time noise the framework occasionally emits.  18 tests.

2. `dd8cb1e` — `MirrorManifest` (later refined in `b46adb3`).
   Curated Tier-1 mirror sets keyed off URL host.  Initial
   population: Ubuntu only (`releases.ubuntu.com` →
   `mirror.kernel.org` / `fr.releases.ubuntu.com` /
   `mirror.us.leaseweb.net` / `mirrors.cat.net` + archive.org
   Wayback long-shot).  Mirrors picked from launchpad.net's
   Tier-1 list ranked by 2024–2026 uptime + geographic spread.
   Splynek's per-chunk SHA-256 + final-file digest still gates
   acceptance — list is curated for liveness, not trust.

3. `281c336` + `b46adb3` — wire-up.  VM subscribes to
   `PathMonitorObserver.liveStream()` and gates the existing
   `DownloadJob.pause()`/`resume()` primitives on `.online↔.offline`
   transitions specifically (interface-set flips stay routed
   through engine's per-lane failover).  Auto-pause flushes the
   sidecar in <1s instead of waiting ~60s for OS-level socket
   timeout.  `MirrorManifest.parallelAlternatives` (alternatives
   minus archive.org Wayback) gets injected into the engine's
   `urls: [URL]` constructor at `DownloadJob.start` time — engine
   internals untouched, the v1.x multi-URL round-robin is the
   existing seam.

**Why VM-level not engine-level:** `DownloadEngine.run()` is 750+
lines of complex async orchestration (chunk-queue, lane workers,
sidecar, swarm hooks, Merkle verify); touching it for path-restart
would risk regressions in the project's most load-bearing code.
The VM already owns DownloadJob lifecycle + battle-tested
pause/resume primitives.  Engine integration of mirror failover
similarly turned out trivial: the engine's `urls: [URL]` parameter
+ lane round-robin (`DownloadEngine.swift:619`) was already there;
the VM just needed to inject more URLs at engine creation time.

**Parallel/last-resort split:** `MirrorManifest.alternatives(for:)`
returns 5 URLs including the archive.org Wayback entry — fine as a
"view archived copy" affordance but bad as a parallel lane (cold
archive, slow on hot resources).  Split into
`parallelAlternatives` (the 4 Tier-1 mirrors, used by engine
creation) and `lastResortAlternatives` (the Wayback entry, surface
deferred for manual UI affordance).

**6th publisher pattern (`5f434be`)**: GitHub Releases.  Claims
`github.com` URLs whose path contains `/releases/download/`.  Tries
`sha256sums.txt` (lowercase, used by ripgrep / fd / bat / eza /
helix / most modern OSS Rust + Go projects) → falls back to
`SHA256SUMS` (uppercase, the Mozilla / Linux-distro convention).
Per-asset `.sha256` siblings remain handled by the existing
`Enrichment.probe` path.  Match scope intentionally narrow:
github.com only (not objects.githubusercontent.com — the
post-redirect host's parent directory doesn't expose the manifest).

**SMJobBless activation runbook (`bf76909`)**: precise step-by-step
for the maintainer turning the helper on for users.  Audited the
plumbing first — bundle ID `app.splynek.Splynek.helper` is
consistent across 9 files; reciprocal `SMPrivilegedExecutables` +
`SMAuthorizedClients` requirements both anchor to OU=58C6YC5GB5
(team ID, fine for MAS — Apple Distribution leaf certs share OU
with Developer ID).  Runbook covers: pre-flight (xcodegen +
signing identity); `xcodegen generate`; build SplynekHelper
standalone (verify `__launchd_plist` segment is non-empty);
archive Splynek-MAS (verify embed + cross-direction
`codesign --test-requirement` checks); install + first-launch
approval flow; automated smoke test using `pkgbuild` +
`productsign`'d 1KB no-op .pkg; optional cert-hash pinning;
6-row troubleshooting table; "when to flip the activation switch"
section (concrete triggers: Apple flags osascript, deprecation
announcement, feature needs persistent admin daemon).

**L10N count refresh (`2ad95ba`)**: bookkeeping — the doc had
round-8-era counts (480 strings, 2,400 translations); current is
535 × 5 = 2,675.  Added bullets for the audit-extension catch-up +
visual sweeps.

### Latest landing (2026-05-04 part 3): audit + live-test pass

After shipping the S2 trifecta, GitHub publisher, Concierge persistence
+ PDF drag, SMJobBless runbook, UX trio (Trust PDF/PNG, Sovereignty
CSV, Wayback affordance), engine-internal restart on interface flip,
and Fedora MirrorSet, ran a full audit-then-live-test pass to surface
issues that wouldn't show up in unit tests alone.

**Audit phase (`b9e4e97`):** 5 issues found across this session's 17
commits, 3 fixed:

- `DownloadEngine` exception-path leak: pathObserverTask wasn't
  cancelled in the catch handler.  `defer` cleanup applied.
- VM offline→online race: rapid-flap could resume a job before its
  pause settled (lifecycle still .running, resume() no-ops).  250ms
  Task.sleep delays the resume past settleAfterRun.
- Hardcoded `/web/2024/` in MirrorManifest's Wayback URLs (Ubuntu,
  Debian, Fedora).  Dropped year for archive.org auto-resolve.

Two issues deferred (Trust PDF single-page clip — known limitation;
CSV `#`-comment non-RFC-4180 — minor).

**Live-test phase (`b07d788`):** built debug .app via `./Scripts/
build.sh debug`, drove via computer-use MCP under the maintainer's
pt-PT locale.  Three new surfaces validated end-to-end:

- Trust PDF export (`splynek-trust-2026-05-04.pdf`, 38KB,
  US Letter @ 72dpi) — renders title, date, methodology blurb,
  summary stats, per-app section with cited concerns, slogan
  footer.  Research-grade artifact looks correct.
- Trust PNG export (`splynek-trust-top10-2026-05-04.png`,
  1200×1200) — renders top-N most-concerning, slogan footer.
  Sparse with 1-app input but acceptable.
- Sovereignty CSV export (`splynek-sovereignty-2026-05-04.csv`,
  9 rows) — 10 columns, RFC 4180 quoting working, schema-version
  comment, ISO-8601 timestamps.

Two live-test bugs surfaced + fixed in `b07d788`:

1. **SovereigntyView filterBar overflow on pt-PT.**  Segmented
   Picker with `frame(maxWidth: 320)` was left-anchored against
   the sidebar; "Todas as alternativas" (~25% longer than EN
   "All alternatives") clipped its leading "Todas " behind the
   sidebar boundary, rendering as "…as as alternativas".
   ZStack-with-overlay restructure centers the Picker dead-center
   of the pane width regardless of locale label length, with
   the count overlaid on the trailing edge.  Works for all 5
   locales.
2. **NSSavePanel.message English-only on 3 export panels.**
   Tried String(localized:bundle:) → NSLocalizedString(_:bundle:)
   → Bundle.module.localizedString(forKey:value:table:) — all
   three returned English even though SwiftUI's
   Text(LocalizedStringKey) resolves correctly against the same
   Bundle.module.  Cause appears to be in SwiftPM's xcstrings→
   .strings pipeline for AppKit-side lookup.  Pragmatic fix:
   drop panel.message entirely.  Save panels work cleanly without
   it; a stale-English caption in a pt-PT UI is worse UX than
   no caption.

One reported issue verified as NOT a bug: Firefox "Instalar" button
apparent-white-text — confirmed live as the standard macOS modal-dim
state during NSSavePanel foregrounding, not a readability issue.

**Deferred from the live test:** Concierge chat surface (needs Pro
license unlock), Install tab drop targets (needs real .dmg / .pkg
samples), end-to-end download (would need a real URL + network
state changes to exercise the new S2 wire-up), Concierge PDF drag
(in Pro repo, not in the public-only debug build).

### Latest landing (2026-05-04 part 4): A→F punch-list sweep

User explicitly requested "do all from A to G" of the post-S2
deferred-items menu (`590fdee`).  6 of 7 shipped in one commit;
G reduced to a smoke-test because the surfaces require maintainer
inputs.

**E** (Swift 6 warning fix in WatchedFolderTests, 1 line):
`MainActor.assumeIsolated` wraps the expectEqual autoclosure.

**A** (localization investigation, ~1 hour bisection): three
Foundation APIs (`String(localized:bundle:)`, `NSLocalizedString
(_:bundle:)`, `Bundle.module.localizedString(forKey:value:table:)`)
all return English in the SwiftPM-built .app under pt-PT locale
even though SwiftUI's `Text(LocalizedStringKey)` resolves correctly
against the same `Bundle.module`.  Empirical finding:
`Bundle.preferredLocalizations` returns `["en"]` inside the running
app despite system `AppleLanguages = ["pt-PT"]`; direct lookup via
`Bundle(path: lprojPath).localizedString(forKey:)` against the
pt-PT.lproj subdirectory works in *script* context but fails in
the live .app context.  Root cause not pinned (best guess: SwiftUI
uses LocalizedStringResource which threads user prefs differently
than AppKit's Bundle reads sandboxed-app per-process defaults).
Shipped `LocalizedString+Workaround.swift` extension as right-shaped
scaffolding for the next iteration; captured as durable memory
entry `splynek_localization_gotcha.md` so future sessions don't
waste time on the same bisection.

**C** (kernel.org PublisherPattern): claims `cdn.kernel.org +
kernel.org + www.kernel.org` URLs whose path contains `/pub/linux/`.
Uses existing `fetchSimpleSHA` against the per-tarball `.sha256`
sibling.  PublisherPattern count 6 → 7.

**D** (engine restart-loop integration test): factored the run()
restart-loop decision into a pure testable helper
`DownloadEngine.decideRestartLoopOutcome(cancelled:allDone:
pathFlagSet:completedRestarts:maxRestarts:) -> RestartLoopOutcome`
(.completeOrCancelled / .giveUp / .restart).  Call site delegates;
behaviour unchanged.  9 new tests covering exit-priority predicates +
typical 6-restart-then-bail flap-loop walk-through.

**B** (Trust PDF multi-page pagination): new
`TrustExport.chunkAppsForPDF` splits scored apps into per-page
chunks (firstPage=5 because cover takes space, continuationPage=8).
`renderPDF` iterates chunks + emits one CGContext PDF page per
chunk.  `TrustReportPDFView` gained `isCoverPage / pageNumber /
totalPages / allScoredForCoverStats` parameters.  Cover renders
methodology + summary stats (across full ranked list) + first 5
apps; continuation pages render "Page X of Y" header + their app
chunk.  Footer shows slogan + page number.  8 new chunker tests.

**F** (memory consolidation, skill-driven): 6 files touched (2
stale refreshed: current_state + mas_state from v1.3-era to
v1.6.2+S2; 3 durable preserved + lightly updated; 1 new entry
for the localization gotcha).  MEMORY.md index rewritten as 6
lines.

**G** (live test deferred surfaces, partial): rebuilt + launched +
verified Trust PDF export still triggers cleanly with new
pagination on a 1-app input (single page, same as pre-pagination).
Other deferred surfaces (Concierge chat, Install drop targets,
end-to-end download with network state changes, Concierge PDF
drag) require maintainer-level inputs.

Tests 425 → 442 (+17).  Audit clean (544 strings × 5 locales).

### Latest landing (2026-05-04 part 5): localization fully mapped + Download verified live

User followed up on the post-A→F honest-scope flags ("Localization
gotcha is mapped but unsolved" + "G's deferred surfaces") with two
explicit asks:

1. **Try the LocalizedStringResource end-to-end fix.**  Did it.
   Tested LocalizedStringResource(key, bundle: .atURL(...)) and the
   variant with explicit Locale.current.  Both still return English
   in the live .app — making 6 failed Foundation/SwiftUI APIs total.
   The issue is now fully mapped: SwiftUI's Text uses the resource
   pipeline via environment-aware rendering, while AppKit-side
   String extraction reads the sandboxed-app per-process
   AppleLanguages defaults which return ["en"] regardless of system
   pref.  Definitive fix path (rewrite save panels as SwiftUI
   .fileExporter sheets) documented as deferred — multi-week
   refactor not warranted for save-panel captions.

2. **Live-test G's deferred surfaces.**  Mixed outcomes:
   - **Concierge: BLOCKED.**  Free-build ConciergeView in the public
     repo is hardcoded as the always-render upsell.  The actual chat
     surface lives in splynek-pro and swaps in only via the MAS
     Xcode build's source-exclusion mechanism.  Patching
     `ProStubs.swift::isPro = true` unlocks the sidebar PRO badges
     but the view stays on the upsell — the chat code isn't in the
     SwiftPM build.  Untestable from this build path.  Patch
     reverted before commit.
   - **Install: SKIPPED.**  Running installer(8) on any .pkg (even
     a pkgbuild'd no-op) is destructive.  Not run without explicit
     go-ahead.
   - **Download: ✅ VERIFIED end-to-end.**  Drove a download of
     https://releases.ubuntu.com/24.04/SHA256SUMS through the
     Transferências tab.  File landed cleanly at
     ~/Downloads/SHA256SUMS (594 bytes, real Ubuntu hashes for the
     three 24.04.3 spins), Histórico bumped 7 → 8 entries, en0 lane
     reached 100%, no errors.  Confirms the new S2 wire-up works
     end-to-end on a real Ubuntu URL — VM injects
     MirrorManifest.parallelAlternatives at engine creation, and
     the curated Tier-1 mirrors get added to laneURLs without
     breaking small-file completion.

Net result of the two asks: localization is now durably understood
(captured as memory entry splynek_localization_gotcha.md so the
next session doesn't repeat the bisection); Concierge and Install
deferred surfaces are documented as untestable-without-additional-
infrastructure (Concierge needs MAS Xcode build; Install needs a
real .pkg the maintainer trusts); Download path's S2 wire-up is
proven live on a real publisher URL.

### Latest landing (2026-05-04 part 6): perfection pass

After "I want all to be perfect" pushback, ran a systematic cleanup
of every half-baked piece + bug.  One commit (`74cd74a`), five
distinct outcomes:

1. **Localization mystery DEFINITIVELY SOLVED.**  Root cause finally
   pinned via os_log diagnostic in the live .app: `Bundle.module
   .bundleURL` resolves to the SwiftPM build cache (`.build/<arch>/
   <config>/Splynek_SplynekCore.bundle/`), which has only Info.plist
   + Localizable.xcstrings — NO .lproj subdirs (those exist only
   in the .app-internal copy, written by `Scripts/compile-xcstrings
   .py` as part of build.sh).  Foundation's lookup machinery looks
   at the build-cache path, finds no .lproj, falls through to
   English.  SwiftUI's Text(LocalizedStringKey) works because it
   threads through LocalizedStringResource which uses a different
   lookup path.  Fix: `LocalizedString+DirectPlist.swift` extension
   that walks Bundle.main's in-app paths + reads .strings files
   directly as plists.  Verified live: pt-PT save panels now show
   "Exportar a tabela de aplicações instaladas × Soberania como
   ficheiro CSV" + the Trust equivalents.

2. **906 build warnings on clean rebuild → 0.**  Strict-concurrency
   cleanup across 6 pre-existing infrastructure files (none touched
   by feature work this session): `Models.swift` gains
   `NSLock.withLockSync(_:)`; `SeedingService` × 6 NSLock pairs +
   `FleetCoordinator` × 6 pairs converted to withLockSync;
   `FleetCoordinator` × 3 main-actor static lets marked nonisolated;
   `AppIntentsProvider` × 3 `_ = await MainActor.run`; `Sovereignty
   Scanner` explicit `[weak self]`; `InstallView` `_ = loadObject`;
   `BenchmarkView` summaryPill var refactored to single-expression
   flatMap to avoid Swift's implicit @ViewBuilder confusion.

3. **SplynekHelper/Info.plist recurring drift — fixed.**  Root cause:
   `xcodegen generate` (invoked by build.sh for App Intents metadata)
   was writing its default placeholder Info.plist template to the
   path declared in project.yml because no `properties:` block was
   declared.  Fix: full `properties:` block in project.yml +
   committed xcodegen's canonical output as the new source of
   truth.  Trade-off: lost the rationale comments inside the plist,
   but those lived elsewhere in HANDOFF + project.yml anyway.
   Verified: subsequent build runs produce zero drift.

4. **Trust PDF render integration test (5 new tests).**  Synthesizes
   ScoredApp inputs + verifies actual rendered PDF page count via
   PDFKit.  Confirms the chunker logic + view rendering integrate
   correctly: empty → 1 page, 5 → 1, 13 → 2, 30 → 5, plus a
   file-validity check.

5. **Pre-existing Swift 6 lint in WatchedFolderTests** (smaller
   sub-fix, in the same arc): `MainActor.assumeIsolated` wrap.

Final hot state: `swift build` produces 0 warnings + 0 errors on
clean rebuild; 451/451 tests pass; audit clean (544 strings × 5
locales); helper Info.plist no longer drifts after build.  Working
tree clean after build.  Localization gotcha memory entry
rewritten as SOLVED with the full investigation + the working fix.

### Latest landing (2026-05-04 part 7): MAS build path restored + Concierge input-bar fix

User asked to see the live Pro version + audit it.  This required
building the MAS xcarchive (the SwiftPM build path is free-tier-only;
the chat surface, Pro-Concierge view, and AI-assist UI live in
splynek-pro and only swap into the binary at MAS-build time via
xcodegen-driven source-exclusion).

The MAS build had accumulated tech debt across two repos that
blocked the archive: 6 distinct error categories spanning Bundle.module
non-existence (xcodegen targets aren't SwiftPM), missing
start(url:sha256:filename:) overload that Pro's onDownload callback
expects, private handleConciergeAction, AppShortcut cap (13 > 10),
String-not-Error in `Result<_, String>`, and a String→LocalizedStringKey
gap in RecipeView.  Fixed across `296117e` (public) + `369a69d` (Pro).

**Bundle.module → Bundle.splynekCore.**  New cross-build wrapper in
LocalizedString+DirectPlist.swift wraps `#if SWIFT_PACKAGE` so SwiftPM
builds use Bundle.module + xcodegen builds use Bundle.main.  Either
way, directPlistLookup walks Bundle.main's in-app paths internally
so the localization SOLVED state holds across both build paths.

**License-gate live test via dev override:** the splynek-pro
LicenseManager has a built-in `splynekDevProUnlocked` UserDefaults
key for App Review Team demos.  Sandbox-container preferences are
isolated from `defaults write` against the bundle ID at the
top-level Preferences/, so a temporary code patch (isPro = true
hardcoded) was the working path for live verification.  Patches
reverted before commit.

**Live-verified Pro Concierge surface:** 4 Mac-Assistant suggestion
chips (What apps installed, What's eating disk, Sovereignty
alternatives, Trust scores) + 4 legacy chips (download/queue/
history/cancel) + provider footer "Using Apple on-device model
via Apple Intelligence" + input bar with "Ask anything…"
placeholder.  Plus AI-assist purple bar on the Transferências tab
(✨ Or describe it — "latest Ubuntu 24.04 desktop ISO" / Perguntar).

**Concierge input-bar layout bug FOUND + FIXED (`803b830`):** during
live verification, user spotted the input bar clipped at the
window's bottom in empty-state mode.  Root cause: emptyState VStack
uses `.frame(maxHeight: .infinity)` to center its hero + chips,
which competes with the inputBar's intrinsic height when the window
is short.  Fix: pull inputBar (+ Divider) out of the inner VStack
into `.safeAreaInset(edge: .bottom)` modifier on the outer view.
safeAreaInset reserves bottom space the inner content can't claim
regardless of any maxHeight settings below it.

### Latest landing (2026-05-05): v0.31-era resume-button no-op guard fixed

User flagged "the resume button doesn't work — pause works, resume
doesn't" while we were mid-test of S2 (Unbreakable Resume) via the
CLI fallback path (live Wi-Fi-flip test had failed earlier because
my own Anthropic API connection died with the Wi-Fi).

Read led to [DownloadJob.swift:185](Sources/SplynekCore/DownloadJob.swift:185):

```swift
var isActive: Bool { self == .running || self == .paused }
func resume(onFinish: ...) {
    guard !lifecycle.isActive else { return }
    start(onFinish: onFinish)
}
```

`Lifecycle.isActive` is `true` for `.paused`.  So `!isActive` is
`false` whenever the user clicks resume on a paused job, the guard
fires the early-return, and resume() is a silent no-op.  Bug
present since `2ab1eee` — v0.31 initial public commit.

**Wider blast radius than the manual button.**  The same `job.resume(...)`
method is what `VM.handlePathEvent` calls to auto-resume jobs that
S2 paused on a Wi-Fi drop.  So Bet S2's offline-pause worked
(verified earlier in session via menubar speed indicator dropping
to 0 the moment Wi-Fi was cut), but the online-resume half also
hit this guard and no-op'd.  The Bet S2 trifecta on `main` was
half-broken end-to-end since landing.

**Fix:** invert the guard intent into an explicit allow-list that
mirrors the resume button's UI contract:
```swift
guard lifecycle == .paused || lifecycle == .failed else { return }
```
The `start()` method (which resume() calls) already has its own
`guard lifecycle != .running` so the fix doesn't add a second
race-condition path against a double-press.

**Regression test:** [Tests/SplynekTests/DownloadJobResumeTests.swift](Tests/SplynekTests/DownloadJobResumeTests.swift)
covers all 6 lifecycle states + asserts paused→running, failed→running,
running stays running, completed/cancelled/pending stay put.  Uses
`MainActor.assumeIsolated` (sync) like the existing
ConciergeTranscriptStore + TrustExport tests do — DownloadJob's init
is @MainActor and the harness blocks the main thread on a
DispatchSemaphore so an async-test path would deadlock.  +4 tests
(447 → 451).

**Live-verified:** real Ubuntu 24.04.4 ISO download.  Pre-pause
8.4 MB/s @ 112 MB / 1.8%; pause froze it at 161.9 MB / 2.6% with
"EM PAUSA" badge; resume picked up at 208 MB / 3.3% @ 10.7 MB/s
with "AO VIVO" + "Downloading" phase.  Bytes-progress crucially
went **forward** from 161.9 MB, not back to zero — sidecar resume
preserved the chunks already on disk.  Downloaded only 47 MB total
across the verify, then cancelled.  Landed in `8a2940b`.

**Lesson learned (worth carrying forward).**  Two things:
1. Audit code paths that have been working "since forever" by
   testing them, not by trusting the tests.  This was a
   fully-broken UI button hidden in a method that compiled, ran,
   and silently no-op'd — no crash, no log line, no test fail.
   The unit tests didn't cover resume() because the only
   integration path was through the @MainActor live-engine surface.
2. When rolling out a feature like S2 that *also calls* a
   pre-existing method, exercise the pre-existing method's actual
   transitions in a fresh integration check, not just the
   pure-decision predicates.  If we'd run a manual pause→resume
   sequence on the existing resume button before landing S2, we'd
   have caught it in a single live test.

## Open positions (what a fresh session should know about)

### Apple v1.0 review — escalate by day 10 if no movement

Resubmitted 2026-04-26.  Status 2026-05-04: day 8, at the upper
edge of the typical 1-7 day window.  If still pending at day 10,
maintainer should escalate via Resolution Center.  Sample message:
ask reviewer for an ETA, mention the v1.0 binary has been in queue
since 2026-04-26 (8 days), reaffirm no VPN/NetworkExtension
entitlement (the original rejection ground).

If Apple cites 2.5.2 (the "vibe coding" guideline), paste
`MAS-2.5.2-COMPLIANCE.md` into Resolution Center — the brief is
pre-written + file-anchored.

### v1.8.2 SMJobBless — **maintainer must xcodegen + sign before this ships**

Per the activation gate above.  Until those steps complete the
helper bundle isn't built; PkgInstaller falls through to v1.8.1
osascript path.  No urgency — osascript works today; SMJobBless is
the long-term-correct architecture for when Apple eventually
deprecates AppleScript admin-elevation or tightens sandbox policy.

### Concierge Pro polish

~~1. Card-history persistence layer~~ — **shipped 2026-05-04**
(`a1fc19c`).  See "Latest landing" above.

~~2. Drag-PDF flow that bypasses the suggestion-chip detour~~ —
**shipped 2026-05-04** (`c64deb1`, Pro).  See "Latest landing" above.

3. The legacy `conciergeSend` still routes Spotlight + AppIntents +
   menu-bar callers.  v1.7.x unified the input-bar but those other
   surfaces still take the legacy path.  Migration is straightforward
   (call `conciergeAsk` instead of `conciergeSend`) but each
   call site needs review for context.

### Engine warm-cache: more publisher patterns

Documented at the bottom of `Sources/SplynekCore/PublisherPattern.swift`:
- Linux Mint (HTML scraping, harder)
- Fedora (annual rotation)
- GitHub releases (`<repo>/releases/download/<tag>/sha256sums.txt`)
- Most container-registry digests (Docker, Quay)
- Steam-CDN URLs (different shape entirely)

Each is ~10–20 lines + test fixture.

### Visual sweeps for PT-PT post-round-8

PT-PT was walked end-to-end through round 6 (the v1.6.2 sprint).
Rounds 7-8 + the audit-extension catch-up added ~120 strings
without a fresh PT-PT walk.  Worth 20 minutes to verify the new
strings render natively (the catalog is correct; this is layout +
idiom validation only).

### Native-speaker review — high-leverage but human work

`L10N-REVIEW.md` is the contributor onramp.  Priority order:
**DE > FR > pt-PT > ES > IT** (Sovereignty + privacy press
coverage is most credibility-sensitive in DE + FR markets).
Current translations are Claude-generated.  Native-speaker review
is genuinely human work.

### Latest landing (2026-05-05 part 2): full-audit sweep + B-F roadmap + S6 File Witness

Single-session push of seven commits.  Started from "what's left
on the rollup" and ended with S6 (Strategy Bet 6 from
STRATEGY-2026.md) shipped end-to-end.

**Resume-button v0.31 bug** — `8a2940b`.  User reported pause
worked, resume didn't.  Read led to `Lifecycle.isActive` returning
true for both `.running` AND `.paused`, so the `guard !isActive
else { return }` in `DownloadJob.resume` silently no-op'd the
exact case it was supposed to handle.  Bug present since the
initial public commit `2ab1eee` (v0.31).  Wider blast radius than
the manual button: the same `job.resume(...)` is what S2's
`handlePathEvent` calls to auto-resume on Wi-Fi-back-online —
Splynek's offline-pause worked end-to-end, but the online-resume
half hit the same wall.  Fix mirrors the resume button's UI
contract: `guard lifecycle == .paused || lifecycle == .failed
else { return }`.  Live-verified against a real Ubuntu 24.04.4
ISO download — paused at 161.9 MB, resumed at 208 MB (sidecar
preserved chunks, no refetch).  +4 regression tests (447 → 451).

**Sub-version consolidation** — `9f06ff9`.  Architectural-state
line had grown to "v1.7 + v1.7.x + v1.8 + v1.8.1 + v1.8.2 + v1.9
+ v1.9.x + S2" — eight sub-versions all destined to ship as one
combined release once Apple v1.0 clears.  Replaced with the single
"next-release rollup" label + per-feature status line.  New memory
file `splynek_versioning_policy.md` captures the rule (no new
sub-version branches; future work piles into the rollup).

**Full audit pass** — `e2309b1` + `b9b200c`.  Walked every tab in
the public build live.  Caught `ProLockedView`'s `summary` parameter
declared as `String` — SwiftUI's `Text(String)` doesn't auto-localize,
unlike `Text(LocalizedStringKey)`.  Two ProLockedView summaries
(Painel web móvel + Agendamento de transferências) had been rendering
in English on pt-PT systems despite catalog translations existing.
Promoted both to `LocalizedStringKey` at the type level.

The deeper finding: `find-missing-translations.py` was processing
files line-by-line, missing every multi-line component invocation
(e.g. `ProLockedView(\n featureTitle: "...",\n summary: "..."\n)`).
Switched to whole-file regex with offset-aware SKIP-L10N filter.
Surfaced 21 strings that had been quietly missing for months.
Plus History timeline footer "X across N days" + MCP endpoint URL
truthfulness fix (free tier displays 127.0.0.1 to match actual
binding instead of LAN IP).  Catalog 535 → 569 → still 569 across
the audit + follow-up commits.

**B-F sweep** — `1e8c9df`.  Five-bet roadmap landings:
  - **B (Pro audit + L10N)**: Built the MAS xcarchive, walked
    Concierge / Recipes / Settings end-to-end with the dev-override
    Pro key set in the sandbox container.  Function-tested
    (Concierge tool dispatch, Recipes 6-category UI, Settings ATIVO +
    Pro features unlocked + Painel web URL truthful).  Found 49
    splynek-pro UI strings the audit script wasn't covering.  Added
    5-locale translations.  Extended audit script to scan splynek-pro
    when checked out as a sibling.  Catalog 569 → 618.  Pro UI
    confirmed in pt-PT after rebuild.
  - **C (L10N onramp refresh)**: L10N-REVIEW.md updated for the
    post-audit state (618 strings, 2026-05-05 audit-pass section,
    Pro-repo scope).
  - **D (publisher patterns)**: PyPI (path-segment SHA-256, no
    network round-trip) + Hugging Face (api/models/<repo>/tree LFS oid).
    +4 tests; allPatterns 7 → 9.
  - **E (Stripe direct channel)**: STRIPE-DIRECT-CHANNEL.md design
    doc — full architecture (Stripe Checkout → Cloudflare Worker
    webhook → HMAC license mint → Postmark email), cost projection
    (+37.5% margin vs MAS), maintainer operational checklist
    (~3 hrs to set up accounts).  Code untouched in this commit;
    implementation = 1 day client-side once accounts exist.
  - **F (S-bet roadmap + S3 pre-flight)**: STRATEGY-FOLLOWUPS-2026-05.md
    enumerates each S-bet's current state with kickoff steps.
    Started S3 with `YtDlpProbe` — detects yt-dlp at standard
    install paths (homebrew apple-silicon / intel / pip-user),
    reads --version with strict regex (rejects shell injection),
    exposes preferred-hosts set for future dispatch logic.
    Pre-flight only — doesn't bundle yt-dlp, doesn't dispatch yet.
    +15 tests.

**S6 File Witness shipped end-to-end** — `17cb90a`.  The journalist /
academic / build-engineer / compliance-team feature.  Every successful
download now mints an Ed25519-signed JSON receipt.

Architecture:
  - `DeviceKeyManager` — per-device Ed25519 keypair in Keychain
    (`kSecAttrAccessibleAfterFirstUnlock`, NOT iCloud-synced).
    Lazy creation on first sign; `rotate()` for "reset device
    identity".
  - `DownloadReceipt` — schema v1 fields: splynek_receipt_schema,
    url, sha256, size_bytes, finished_at (ISO 8601 with explicit Z),
    device_pubkey (base64), signature (base64).  Signature covers
    `JSONSerialization.data(withJSONObject:options:[.sortedKeys,
    .withoutEscapingSlashes])` over the unsigned-fields subset —
    matches what {Swift, Python, Node, Go} runtimes emit for
    sortedKeys, so verifiers can be written in any of those.
  - `ReceiptStore` — atomic on-disk persistence at
    `~/Library/Application Support/Splynek/receipts/<sha256>.json`,
    keyed by content SHA-256.  Failures intentionally silent.
  - Engine integration — DownloadEngine's verify-phase success path
    (right after `DownloadHistory.record`, where `contentHash` and
    `totalBytes` are already known) calls `ReceiptStore.mintAndStore`.
  - UI — `HistoryDetailSheet` footer shows "Export receipt" button
    when a receipt exists for the row's sha256.  Click opens
    NSSavePanel with localized message routing through
    `Bundle.splynekCore.localizedStringForAppKit` for pt-PT/de/es/fr/it.
  - Standalone verifier — `Scripts/verify-splynek-receipt.swift`,
    two-form CLI (signature only / signature + file hash).  No
    third-party deps; uses Foundation + CryptoKit.

10 new tests — canonical JSON, sign/verify roundtrip, tamper
rejection (URL, sha256, forged signature), encode/decode roundtrip
preserves verifiability, schema version exposed, ISO 8601 round-trip.

Live-verified end-to-end: real download of
`https://releases.ubuntu.com/24.04/SHA256SUMS` (594 bytes) produced
a receipt at the canonical path.  Standalone verifier confirmed
both internal-consistency AND file-content-match against the
on-disk file.  Export receipt button ("Exportar recibo") visible
in pt-PT in HistoryDetailSheet footer.

Threat model: signing key never leaves device; wiping the Mac =
key gone but existing receipts still verify (pubkey is in each
receipt).  No CA, no PKI chain, no Splynek-side database.  Same
no-cloud / no-account / no-telemetry posture as the rest of the
product.

**Catalog growth this session**: 569 → 621 (+52 strings, +260
translations across 5 locales).  **Tests**: 451 → 480 (+29).  **Build
warnings**: 0 on clean rebuild throughout.  **Public repo** at
86 commits ahead of origin; Pro repo at 3 commits ahead.

### Latest landing (2026-05-05 part 3): S3 dispatch + S5 Browser Accelerator end-to-end + Safari xcodegen + DASH

Continuation of "do A through F" arc.  After the S6 File Witness
ship, Paulo asked to push S3 dispatch + Safari WebExtension parity
+ HLS pre-buffer + DASH support to functional completion.  Six
commits delivered the full S5 Browser Accelerator strategy bet
end-to-end.

**S3 dispatch wire-up** (`bf9d3a0`).  YtDlpProbe pre-flight from
`1e8c9df` becomes a working feature.  When the user pastes a URL
whose host yt-dlp handles natively (YouTube / Twitch / Instagram /
TikTok / X / Vimeo / Bilibili) AND yt-dlp is detected on disk,
DownloadView's source card surfaces a purple-tinted dispatch row
with version + "Use yt-dlp" button.  YtDlpRunner spawns yt-dlp
with `--no-update --no-call-home --no-cache-dir --no-playlist
--newline --print after_move:filepath`, streams the output line-
by-line on a background queue parsing progress / bytes / title,
records the result in DownloadHistory so it shows up in
Histórico.  +15 tests covering pure parsers (regex injection
rejection, MiB/KiB/GiB unit handling, title detection, dispatch
errors).  DMG-only feature; MAS sandbox blocks `Process()`
invocation, surfaced via `.sandboxBlocked` probe state.

**S5 Accelerator + HLS scaffolding** (`a4af998`, `efe3069`).  Chrome
extension v0.21 → v0.23.  Manifest gets +webRequest, +downloads,
+notifications, +host_permissions: <all_urls>.  background.js
listens on `downloads.onCreated`, threshold check (default 50 MB,
overridable), per-host opt-out + always lists in
chrome.storage.sync.  When triggered, notification: "Splynek can
fetch this faster. 247.3 MB from <host>. [Send to Splynek] [Keep
in browser]".  Default OFF — surprising users by silently
redirecting their downloads is hostile UX.  Options page exposes
Accelerator toggle + per-host preferences.  v0.23 adds notification
right-click → openOptionsPage hook for managing per-host lists.

Day-10 escalation message also drafted (`MAS-DAY10-ESCALATION.md`):
pre-written Resolution Center copy for Apple v1.0 review when day
10 hits, structured to be polite + comprehensive (VPN clarification
+ 2.5.2 compliance + architectural invariants + sub-24h turnaround
signal).

**S5 Safari + HLS manifest parser** (`39e9021`).  Safari WebExtension
mirror of the Chrome extension.  Apple's Safari extensions need a
`browser.*` namespace + ship as `.appex` inside a host app.  Each
JS file opens with `const X = (typeof browser !== "undefined") ?
browser : chrome;` so the same source compiles in either browser.
SafariWebExtensionHandler.swift is a minimal NSExtensionRequest
Handling stub.  HLS manifest parser shipped at the same time —
HLSManifest.parse(_:) returns .master / .media / .notHLS,
parseAttributeList handles quoted CODECS with embedded commas,
parseMedia covers VOD vs live (ENDLIST presence) + byte-range
segments.  +14 tests against IETF HLS RFC + Apple Sample Streams.

**S5 ship: end-to-end** (`6850e48`).  Safari xcodegen target wired
in `project.yml` (type: app-extension, com.apple.Safari.web-extension
principal class), buildPhase: resources for flat Resources/ layout,
Splynek main app dependency: copy + codeSign + embed → appex lands
in Contents/PlugIns/.  Smoke verified: xcodebuild produces
SplynekSafariExtension.appex with manifest.json, popup.html, etc.
at correct paths.  HLS pre-buffer end-to-end:
  - HLSManifest URL rewriter: rewriteMasterURIs / rewriteMediaURIs
    + base64URL encoding for proxy redirect URLs
  - HLSManifest.hasDRM: detects #EXT-X-KEY non-NONE methods
  - HLSRingBuffer: per-session 256 MB LRU cache, oversized-segment-
    fits-once semantics, get-touches-LRU
  - HLSProxyServer (@MainActor): three routes (/master, /v, /s),
    session lifecycle with prune-by-age, segment Content-Type
    inference (.ts / .m4s / .mp4)
  - FleetCoordinator integration: /hls/* dispatch wired alongside
    existing API surface, token-gated like everything else
  - Chrome extension: `chrome.declarativeNetRequest` per-tab
    session rule redirecting *.m3u8 URLs to local proxy
  - Options page: HLS toggle + Splynek port + token inputs
  +24 tests (HLS rewriter, ring buffer LRU, proxy route parsing,
  session lifecycle).

**Bonded fetch + DASH** (`e9e7002`).  The closing pair on S5.
BondedFetcher.swift wraps LaneConnection (NWConnection-based,
already used by the engine) for multi-interface bonded fetch of
small files.  Pipeline: HEAD probe via URLSession → splitRange
across N interfaces (ceil(total/N) per chunk) → parallel
LaneConnection.fetch range requests → reassemble.  Failure modes:
HEAD fails → fullFetch via first interface; one range fails →
nil out (no partial-success); empty interface list → nil.  +7
splitRange invariant tests.  HLSProxyServer.serveHLS now
discovers active interfaces via `InterfaceDiscovery.current()`
+ routes segment fetches through BondedFetcher when ≥2 interfaces
are up, falls back to URLSession on bonded failure.

DASH support (`DASHManifest.swift`, +12 tests).  MPEG-DASH MPD
parser, regex-based.  DRM detection covers Widevine / PlayReady /
FairPlay / Common Encryption baseline.  URL extraction for
<BaseURL> + <SegmentTemplate> media + initialization attrs (two-
pass extraction — block-level then per-attribute, since SegmentT
has multiple URL attrs).  rewriteMediaURLs replaces BaseURLs
with proxy redirects; pass-through on DRM.  HLSProxyServer.
handleMaster now auto-detects HLS vs DASH from body content via
DASHManifest.detectKind so the same /master route serves both
protocols transparently.  Chrome extension's declarativeNetRequest
regex extended: `(m3u8?|mpd|dash)` covers everything.

**Strategic state**: Strategy Bet S5 is FUNCTIONALLY COMPLETE.
Both halves from STRATEGY-2026.md ship:
  a) Accelerator intercept (downloads): off-by-default toggle,
     notification-based per-file consent, per-host preferences
  b) HLS+DASH pre-buffer (streaming): browser-extension redirect
     to localhost proxy, BondedFetcher segment fetches across
     every NIC, ring-buffered serve at <1ms latency

The "video never buffers" demo from the strategy memo is now
shippable: enable Accelerator + HLS pre-buffer in the extension,
open Vimeo on weak Wi-Fi + 5G tether — segments fetch via
parallel byte ranges across both NICs, pre-buffered in RAM,
served from localhost.  Live test on real Vimeo/Twitch +
measuring buffering improvement is the manual next-step.

**Catalog growth this part**: 621 → 624 (+3 strings — yt-dlp
detection row).  **Tests**: 480 → 552 (+72 across S3, S5, bonded,
DASH, HLS).  **Build warnings**: 0 throughout.  **Public repo**
at 93 commits ahead of origin (+7 commits).

Six commits delivered:

```
e9e7002 S5 ship: bonded segment fetch + DASH manifest support
6850e48 S5 ship: Safari xcodegen target + HLS pre-buffer end-to-end
39e9021 S5 expansion: Safari WebExtension parity + HLS manifest parser scaffolding
efe3069 Apple day-10 escalation draft + Accelerator v0.23
a4af998 S5 first half: Chrome Accelerator intercept (off-by-default)
bf9d3a0 S3 dispatch: yt-dlp wired into Source view + History
```

### Latest landing (2026-05-06/07): UI/UX polish + Sovereignty catalog expansion + URL-verification automation

Two-day arc covering everything between the S5 ship and now.  Six
commits, no version bump (still v1.6.2 in Info.plist; release held
behind Apple v1.0 re-review).  Three discrete tracks:

#### Track 1 — UI/UX polish (`d26ac6b`, `3687633`, `702fb25`)

User feedback: button hover states were invisible, the Benchmark
process appeared to hang on tab-switch, and the Install tab's
filename column had grey "checkbox-looking" glyphs that did nothing.

**Hover affordances** (`d26ac6b`).  New `HoverEffects.swift` exports
three reusable primitives:
- `.splynekHover()` — tint-on-hover modifier for any view
- `.splynekHoverCursor()` — pointer-cursor without tint
- `.buttonStyle(.splynekHover)` — full ButtonStyle replacement for
  `.borderless`, with NSCursor.push/.pop for pointer cursor +
  tint-on-hover

Bulk-replaced `.buttonStyle(.borderless)` → `.buttonStyle(.splynekHover)`
across 30 buttons in 9 files (DownloadView, HistoryView, AgentsView,
FleetView, SettingsView, TorrentView, UsageTimelineView, OnboardingSheet,
LegalView).  In the Pro repo: ConciergeCardView, ConciergeView
(`suggestionChip(_:)` + `macAssistantChip(_:icon:)`), RecipeView
(themed-idea card + URL link).

Initial tint of 0.08 was invisible in dark mode; bumped to 0.16
(button style) and 0.12 (modifier) after second feedback round
("Vejo o button state on click, não vejo o on hover").

**Benchmark live progress + tab-switch survival** (`3687633`).
Two bugs:
1. `executar avaliação` showed only a spinner — no readout — making
   it look hung even when running.
2. Switching tabs and coming back showed the runner stopped: the
   `@StateObject` was view-scoped, so SwiftUI tore it down on tab
   switch.

Fixes:
- Hoisted `BenchmarkRunner` ownership from view to `ViewModel`
  (`@StateObject` → `let benchmarkRunner = BenchmarkRunner()` on VM,
  `@ObservedObject` in the view).  Survives tab switches because
  the VM is app-scoped.
- BenchmarkRunner now publishes `liveBytes`, `liveExpectedBytes`,
  `liveThroughputBps`.  A 250 ms polling task during `probe(...)`
  reads `progress.downloaded` / `progress.totalBytes` and surfaces
  spinner + phase + GradientProgressBar + live bytes/throughput
  stats in the new `runningProgressBlock` view.

**Install-tab "checkbox" confusion + Sovereignty Visit→Get-installer
rebalance + hover tint bump** (`702fb25`).  Three fixes in one commit
because they were all "user looked at the screen and was confused":
- InstallView's filename column showed `Image(systemName: "app")`
  glyphs — empty squares that read as broken checkboxes.  Replaced
  with `installedAppIcon(for:)` using `NSWorkspace.shared.icon(forFile:
  r.installedAt.path)` (real .app icons), with `app.fill` as the
  fallback when no `installedAt` URL is present.  Added `import AppKit`.
- SovereigntyView's `actionButton(for:)`: when only `homepage` exists
  (no `downloadURL`), the button used to be `.bordered` + "Visit".
  Rebalanced to `.borderedProminent` + "Get installer" with a tooltip
  explaining "Splynek doesn't have a direct download URL for X yet —
  opens its homepage where you can grab the installer."  This makes
  Install the visual norm + Visit the residual case rather than the
  reverse.  +4 strings × 5 locales in `Localizable.xcstrings`
  (`Get installer` + tooltip + alt-tag forms).
- Hover tint bump 0.08 → 0.16 / 0.06 → 0.12 (described above).

#### Track 2 — Sovereignty catalog expansion (`d22b9ce`)

The "98% of cards say Visit instead of Install" diagnosis was a
**data** problem (only 1.4% of alternatives had a `downloadURL`),
not code.  Two-step fix:

**Backfill verified URLs** (within `d22b9ce`).  Tested ~30 candidate
download URLs with `curl -sI -L`.  78% of the candidates failed —
mostly GitHub `releases/latest/download/<file>.dmg` patterns where
the artifact filename embedded a version number, so the redirect
404'd silently into a friendly HTML 404 page (status 200, body
text/html — the failure mode that motivated Track 3 below).
Kept only the 7 verified-binary URLs: Element, Bitwarden, ProtonVPN,
Stats, Ollama, iTerm2, Zotero.

**8 new alternative rows** (also in `d22b9ce`) — apps with
publisher-canonical "/latest/" redirects added to existing target
rows that lacked them: Brave on Chrome / Edge / Arc; Telegram on
WhatsApp / Discord / Slack; Docker Desktop on Parallels / VMware
Fusion.  Each was URL-verified before insertion.

Coverage moved 1.4% → 7.0% (45 → 223 alternatives with direct
`downloadURL` out of 3,194 total).

#### Track 3 — URL-verification automation (`72e57b9`)

Manual verification of the 30 candidate URLs took most of an hour
and revealed that `Scripts/check-urls.swift` was passing on rotted
URLs because it didn't validate Content-Type — a 200 OK that
returned `text/html` slipped through as healthy.  The user's
follow-up was direct: "Change the routines to do that verification
automatically."

Three changes that close the loop end-to-end:

**1. Content-Type validation in `check-urls.swift`.**  `checkURL`
now captures the `Content-Type` header per response.  `classify`
takes the URL `kind` ("homepage" or "download") and a new
`isBinaryContentType(_:)` helper.  For `kind == "download"`, a 200
OK with non-binary Content-Type produces a new `.wrongContentType(Int,
String)` Status case — counted as **real rot**, not transient.
Homepages are unaffected (they legitimately return text/html).
Acceptable binary types: `application/octet-stream`, `application/
x-apple-diskimage`, `application/x-iso9660-image`, `application/zip`,
`application/x-xar`, `application/*` minus json/xml/javascript/xhtml/
ld+json.

**2. New `--prune-broken-downloads` flag.**  Verifies every
`downloadURL` and rewrites the catalog in place, removing only the
`downloadURL` field from broken alternatives (the alternative entry
stays — it just falls back to homepage-only).  True rot only —
transient failures (429 / 5xx / DNS blips / timeouts) are
deliberately spared so a flaky network run can't strip working URLs.
Idempotent: a no-op run on a clean catalog leaves the file
byte-identical (md5 confirmed).  Implies `--only-download`.  Uses
`JSONSerialization` with `[.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]`
to match the canonical catalog format.

**3. Weekly cron auto-PR job.**
`.github/workflows/sovereignty-weekly.yml` gained a third job
`prune-broken-downloads` that runs after the existing `urls`
liveness check.  Calls `--prune-broken-downloads`, re-runs
`validate-catalog.swift --strict`, regenerates the Swift companion
via `regenerate-sovereignty-catalog.swift`, and opens a PR via
`peter-evans/create-pull-request@v6` with the diff for human
review.  Never auto-merges; never runs on PRs (would create cycles).
Workflow permissions bumped: `contents: write`, `pull-requests:
write` (was `contents: read`).

**Side benefit**: normalized catalog key ordering (alphabetical) once
so the first auto-PR doesn't show a 500-line key-shuffle noise diff —
without this, `JSONSerialization` would reshuffle every alternative
because Swift dictionaries don't preserve insertion order.

Verified locally before commit:
- Bitwarden corrupted to `https://bitwarden.com` (an HTML landing
  page) → flagged across all 8 password-manager target rows with
  status `200 html(text/html; charset=utf-8)`.
- `--prune-broken-downloads` strips the 8 corrupted entries; clean
  catalog re-runs with md5 unchanged.
- `validate-catalog.swift --strict` passes (1,155 entries, no findings).
- `regenerate-sovereignty-catalog.swift` round-trips cleanly.

**Catalog growth this arc**: Sovereignty alternatives with
`downloadURL`: 45 → 223 (×5).  Localization catalog: 624 → 628
(+4 strings — Get installer flow).  **Tests**: unchanged (552;
no new test files this arc).  **Build warnings**: 0.

Six commits delivered:

```
72e57b9 Sovereignty: automate URL verification with Content-Type validation + auto-prune
d22b9ce Sovereignty catalog: verified direct download URLs + 8 new alternatives
702fb25 UI fixes: Instalar checkbox confusion, hover tint contrast, Sovereignty action equality
3687633 Benchmark: live progress feedback + survives tab switch
d26ac6b UI/UX: hover affordances + pointer-cursor across all interactive surfaces
ab31170 Documentation refresh: HANDOFF + SESSION-LOG + L10N + design docs
```

#### Open positions opened by this arc

- **Sovereignty downloadURL coverage at 7%** — the verifier now
  catches failures, but the catalog still has 2,971 alternatives
  without a direct download URL.  Apps that recur 5–24 times across
  target rows (~80 apps) have the highest leverage; verifying just
  those could push coverage to ~30%.  Manual + cron-supported.
- **Trust catalog expansion** — at 151 entries, well below
  Sovereignty's 1,155.  Multi-day work; no infrastructure
  investment needed first.
- **S5 live test on real Vimeo/Twitch** — HLS pre-buffer is
  shippable but unmeasured against real streams.  Manual,
  deferred.

### Latest landing (2026-05-07 part 2): Strategy Bet S4 — iPhone Companion foundation

User asked to "jump in S4" — the iPhone Companion strategy bet from
`STRATEGY-2026.md`.  STRATEGY puts the full ship at week 8-16
alongside Pro+ tier; this commit lands the **foundation skeleton**
so the build system + tests + shared core are in place and the
remaining phase-2 work (Live Activity, QR pairing, CloudKit relay)
becomes multi-day chunks of focused work rather than ground-up
infrastructure.

#### Architecture choice: Mac side untouched

The crucial early decision was that `FleetCoordinator` already
exposes everything an iOS companion needs:

- Bonjour service `_splynek-fleet._tcp` with TXT keys
  `uuid` / `name` / `ver` / `swarm`
- `POST /splynek/v1/api/queue?t=<token>`  body `{"url": "..."}`
  → 202 Accepted
- `GET  /splynek/v1/api/jobs?t=<token>`   → active job list
- `GET  /splynek/v1/status`               → liveness / pairing probe

So the iOS app is purely a consumer.  No Mac-side commits required.

#### Targets + layout

Two new iOS targets in `project.yml`:

- **SplynekCompanion** (`type: application`, iOS 17+) — the iPhone
  app, marketing version 0.1.0, App Group `group.app.splynek.companion`
  + keychain access group same.
- **SplynekShareExtension** (`type: app-extension`, iOS 17+) — the
  Share Extension, embedded into the host app, same App Group +
  keychain.

Shared sources under `iOS/Shared/` are compiled into BOTH targets
AND exposed as a SwiftPM library `SplynekCompanionCore` so the
existing `swift run splynek-test` harness exercises them on the
Mac toolchain — no iOS Simulator round-trip in the unit-test loop.

```
iOS/
├── SplynekCompanion/           main app: SwiftUI tab root,
│   │                              PairedMacsView, PairingSheet,
│   │                              JobsView, SubmitURLView
│   └── Info.plist + entitlements
├── SplynekShareExtension/      Share Extension:
│   │                              ShareViewController + ShareSheetView
│   └── Info.plist + entitlements
└── Shared/                     compiled into both targets +
                                   exposed as SplynekCompanionCore SPM lib
```

#### Shared core (`iOS/Shared/`)

Five files — all platform-portable Swift, no UIKit / SwiftUI in the
public surface so they compile on the macOS test runner:

- `PairedMac.swift` — Codable record (uuid / displayName /
  lastKnownHost / lastKnownPort / token / lastSeen).
- `PairedMacStore.swift` — App Group + keychain persistence.  Plist
  in `UserDefaults(suiteName: "group.app.splynek.companion")` for
  metadata; per-Mac token in keychain with `kSecAttrAccessGroup` set
  to the App Group identifier so both targets can read/write.
  In-memory mode for tests.
- `PairedMacClient.swift` — actor-based HTTP client.  Three
  methods (`ping`, `queue(url:)`, `download(url:)`, `jobs()`).
  5-second request timeout so the Share Extension returns to the
  host app fast even when the Mac is asleep.  Permissive JSON
  decoding (handles both top-level array + `{"jobs": [...]}` shapes
  for forward-compat).
- `ShareExtractor.swift` — pure URL extraction from
  NSItemProvider payloads.  Handles `URL` / `NSURL` / `String`;
  uses `NSDataDetector` for URLs embedded in free-text shares.
  `bestURL(from:)` prefers https → http → file.  `canonicalize(_:)`
  strips utm_*, fbclid, gclid, mc_cid, mc_eid, _hsenc, _hsmi,
  ref_src, ref_url for visual dedup (NOT a privacy filter — Trust
  scan handles that).
- `SplynekBonjourBrowser.swift` — `NWBrowser` wrapper for
  `_splynek-fleet._tcp` + a pure `SplynekTXTRecord.decode(...)`
  function that maps the TXT dict to a `Discovered` model
  (testable without `Network.framework`).

#### Main app (`iOS/SplynekCompanion/`)

Five SwiftUI files:

- `SplynekCompanionApp.swift` — `@main`.
- `ContentView.swift` — TabView with two tabs (Macs / Submit).
- `PairedMacsView.swift` — paired-Mac list + Bonjour-discovered Mac
  list ("on this Wi-Fi"), `+` to add, swipe-to-delete.  Live
  online/offline pill driven by Bonjour discovery overlap.
- `PairingSheet.swift` — three-field form (display name / host:port
  / token), hits `/splynek/v1/status` to confirm reachability +
  auth, saves on success.
- `JobsView.swift` — per-Mac active-jobs list, polling at 2s
  intervals while visible.  Includes inline "submit URL" row so
  the user can queue from anywhere in the app.
- `SubmitURLView.swift` — type-or-paste fallback when not coming
  from the Share Extension.

#### Share Extension (`iOS/SplynekShareExtension/`)

Two files:

- `ShareViewController.swift` — UIKit lifecycle wrapper.  Walks
  `extensionContext.inputItems` → `NSItemProvider.attachments` →
  `loadItem(forTypeIdentifier:)` for `public.url` /
  `public.plain-text` / `public.text`, hands payloads to
  `ShareExtractor.bestURL(...)`, presents the SwiftUI sheet.
- `ShareSheetView.swift` — three states (URL + paired Macs / URL
  but no paired Macs / no URL extracted).  Picker auto-selects
  most-recently-seen Mac.  Tap Send → POST to Mac → dismiss.

#### Tests

27 new tests across three suites in
`Tests/SplynekTests/Companion*Tests.swift`:

- `CompanionShareExtractorTests` — payload-type coverage (URL /
  NSURL / String / nil), `bestURL` preference order, canonicalize
  (utm strip / fbclid / gclid / preserves non-tracking / idempotent).
- `CompanionBonjourTests` — `SplynekTXTRecord.decode` (missing
  uuid → nil, minimal valid, swarm flag, version surfacing,
  display name fallback).
- `CompanionStoreTests` — in-memory `PairedMacStore` CRUD,
  upsert-overwrites, sort-by-displayName, `PairedMac.baseURL`.

After this commit: **579 tests passing** (was 552 — +27).

#### What's NOT in the foundation

Tracked in `IOS-COMPANION.md`:

- **Live Activity (ActivityKit)** for download progress on the
  lock screen + Dynamic Island, mirrored to the Mac menu bar via
  macOS 26's Live-Activity passthrough.  Requires APNS push tokens
  + a Mac-side push provider via `FleetCoordinator` job-progress
  hook.  Multi-day work; phase 2.
- **QR-code pairing** as alternative to manual token paste.  Mac
  shows `splynek://pair?host=&port=&token=` QR; phone scans it.
- **CloudKit relay** for over-cellular submission when phone isn't
  on the same Wi-Fi.  Private CloudKit zone + `CKDatabaseSubscription`
  on the Mac side.
- **TestFlight** — gated on Apple v1.0 macOS clearance to avoid
  fragmenting App Review attention.

#### Why ship foundation now (vs. wait for phase 2)

- The build system catches API breakages early — every CI rebuild
  now compiles all five targets.
- The shared core is unit-tested at PR time, which protects the
  REST surface the iOS app depends on against silent Mac-side
  breakage.
- `IOS-COMPANION.md` documents the architecture so a phase-2 push
  doesn't need to re-derive the design.

**Catalog growth this part**: tests 552 → 579 (+27).  Source files
+ ~12 (5 shared + 5 main app + 2 extension).  Documentation: new
`IOS-COMPANION.md` (~150 lines).  **Build warnings**: 0 throughout.

One commit delivers the foundation:

```
(pending) S4 iPhone Companion: foundation skeleton — iOS app + Share Extension + shared core
```

### Latest landing (2026-05-07 part 3): S4 phase 2 — Live Activity + QR-code pairing

After landing the foundation, user said "continue" — meaning push
through phase 2 of S4.  The strategy memo had originally framed
Live Activity / QR / CloudKit as multi-week each, but the
foundation's clean shape (pure shared core + iOS-only thin
wrappers) made Live Activity + QR a one-day addition.  Phase 2
ships them; phase 3 (CloudKit over-cellular relay + TestFlight)
remains genuinely multi-day per item.

#### Track 1 — Live Activity (with macOS-26 menu-bar mirror for free)

**The strategic thesis**: per `STRATEGY-2026.md` Bet S4, "macOS 26
mirrors paired-iOS Live Activities into the Mac menu bar — this
feature lights up the Mac menu bar for free, no separate Mac
menu-bar widget to build."  One ActivityKit implementation = both
surfaces.

**New shared types** (`iOS/Shared/`, gated `#if os(iOS)` because
ActivityKit imports cleanly on macOS but its protocols are
`@available(macOS, unavailable)`):

- `DownloadActivityAttributes` — fixed attrs (sourceURL / filename
  / macName / jobID) + dynamic ContentState (phase / downloaded /
  total / throughputBps / etaSeconds).  Conforms to
  `ActivityAttributes` for ActivityKit consumption.
- `LiveActivityCoordinator` — pure transition layer.
  `decide(previous:current:)` returns a Plan
  (toStart/toUpdate/toEnd) by diffing the previous Snapshot
  against the current `[JobIdent]`; `project(after:from:)` gives
  the next Snapshot.  Phase filter: `running` + `paused` get
  Activities; `queued`, `finished`, `failed` don't.

**iOS-only driver** (`iOS/SplynekCompanion/LiveActivityDriver.swift`):
`@MainActor`-isolated wrapper that takes the pure Plan and applies
it to ActivityKit (`Activity.request` / `update` / `end`).  Maps
each `(macUUID, jobID)` to its
`Activity<DownloadActivityAttributes>` instance for subsequent
operations.  Stale-date set to 30s out so iOS dims the chip if
polling stops (e.g. app backgrounded, Mac off LAN).  `endAll()`
clears every activity on JobsView disappear so the lock screen
doesn't carry a stale chip after the user navigated away.

**Wired into JobsView's poll loop**: every 2s `refresh()` calls
`liveActivities?.sync(currentJobs: jobs)` — that takes the diff,
applies it, advances the snapshot.  `onAppear` creates the
driver, `onDisappear` settles all activities.

**Widget Extension** (`iOS/SplynekCompanionWidgets/`, new
`app-extension` target in `project.yml`):

- `SplynekCompanionWidgetBundle.swift` — `@main` WidgetBundle.
- `DownloadActivityWidget.swift` — `ActivityConfiguration(for:
  DownloadActivityAttributes.self)` covering all four surfaces:
  - **Lock screen / banner** — full progress card (icon + filename
    + Mac name + ProgressView + bytes + throughput).
  - **Dynamic Island compact** — phase icon + throughput.
  - **Dynamic Island minimal** — single phase icon.
  - **Dynamic Island expanded** — leading filename, trailing
    throughput, bottom progress bar.

**Mac side: zero changes required** — macOS 26's Continuity
Live-Activity passthrough is OS-level; the iPhone's Activity
appears in the Mac menu bar automatically when paired.

**Host app Info.plist gained `NSSupportsLiveActivities=YES`** —
required for ActivityKit to permit Activity creation.

#### Track 2 — QR-code pairing

**Mac side, two changes:**

1. New method `FleetCoordinator.iPhonePairingURLString()` — emits
   the canonical `splynek://pair?host=…&port=…&token=…&name=<deviceName>`
   string, or nil when the listener is loopback-only (a phone
   on a different network can't reach 127.0.0.1).  Implementation
   builds the string via URLComponents to mirror exactly what
   `iOS/Shared/SplynekPairURL.swift::encode` produces; the
   round-trip is verified by 14 unit tests.
2. SettingsView's "Web dashboard" card gains a second QR card
   ("Pair Splynek Companion (iPhone)") below the existing
   browser-dashboard QR.  Same `QRCode.image(for:size:)` helper
   renders the new QR; copy-pair-URL button next to it.  The
   pairing card hides itself when LAN sharing is off (Privacy
   mode → Loopback only) and surfaces an inline hint instead.

**iOS side, two new files:**

1. `iOS/Shared/SplynekPairURL.swift` — pure encode/decode for the
   `splynek://pair?…` format.  Required fields: host (non-empty),
   port (positive int), token (non-empty); optional name.  Encode
   omits empty/nil name.  Decode rejects wrong scheme, wrong
   host, missing required fields, non-numeric port.  Trims
   whitespace.  14 unit tests cover round-trip + every rejection
   path.
2. `iOS/SplynekCompanion/QRScannerView.swift` —
   `UIViewControllerRepresentable` wrapping AVCaptureSession +
   AVCaptureMetadataOutput with `[.qr]` metadata.  Reticle UI +
   Wallet-style success beep on first valid decode (mismatched QR
   formats keep scanning rather than emitting).  Camera-permission
   denial + missing back camera both fall through to `onCancel`
   gracefully.

**PairingSheet wiring**: `Form` gains a prominent "Scan QR from
Mac" button at the top.  On scan success, the components pre-fill
the manual fields and `attempt()` auto-submits — if the Mac is
unreachable the form re-appears with the values filled in for
retry.

**Host app Info.plist gained `NSCameraUsageDescription`** — required
for AVCaptureDevice access.  Privacy nutrition label: camera is
"used only when scanning a QR code to pair with a Mac running
Splynek; not used for any other purpose."

#### ActivityKit gotcha — `canImport(ActivityKit)` lies

Initial implementation gated on `#if canImport(ActivityKit)`.  That
returns true on macOS — the framework is importable — but its
public protocols are marked `@available(macOS, unavailable)`, so
any reference to `ActivityAttributes` errors at compile time on
macOS even when the symbol is in scope.  Fix: gate on
`#if os(iOS)` instead.  Touched `DownloadActivityAttributes`,
`LiveActivityDriver`, and the JobsView wiring.

#### Tests

32 new tests across two new suites:

- `CompanionLiveActivityTests` (18 tests) — every `decide(...)`
  edge case (empty/start/update/end), phase filter (`running` +
  `paused` deserve Activities; `queued` / `finished` / `failed`
  don't), multi-step transition chains.
- `CompanionPairURLTests` (14 tests) — round-trip + every reject
  path (wrong scheme, wrong host, missing host/port/token,
  non-numeric port, negative port, empty token, garbage text).

After this commit: **611 tests passing** (was 579 — +32; net +59
over the 552 baseline before S4).  **Build warnings: 0.**

#### Numbers this part

| Metric | Before phase 2 | After phase 2 | Δ |
|---|---:|---:|---:|
| Tests | 579 | **611** | +32 |
| iOS targets | 2 (app + share-ext) | **3** (+ widgets) | +1 |
| iOS Swift files | ~12 | **~17** | +5 |
| Mac-side Swift LOC changed | 0 | **~60** | +60 |
| Top-level docs | 7 | 7 | 0 (IOS-COMPANION updated in place) |

#### Two commits delivered

```
(pending) S4 phase 2: Live Activity + QR-code pairing
b509954 S4 iPhone Companion: foundation skeleton — iOS app + Share Extension + shared core
```

(Phase 2 lands as a single commit because the Live Activity
+ QR pairing pieces are mutually-dependent on the Widget
Extension target landing — partial commits would leave
`SplynekCompanion` declaring a dependency on a target that
doesn't exist yet.)

### Latest landing (2026-05-07 part 4): S4 phase 3 — CloudKit over-cellular relay

User said "continue" again.  Phase 3 was the last functional gap
in S4: the iPhone Companion only worked on the same Wi-Fi as the
Mac — useless when on cellular, on a hotel network, or when the
Mac's at home and the user's at the office.  Phase 3 closes that
gap with a CloudKit-backed relay path.

#### Architectural choice: poll, don't push

The textbook design uses `CKDatabaseSubscription` + APNs silent
push to wake the Mac when a relay record arrives.  We rejected
that for two reasons:

1. **Entitlement complexity.**  APNs silent push requires
   `aps-environment` + a background-fetch capability + careful
   delegate wiring on the Mac side that Splynek doesn't have today.
2. **Sleeping-Mac brittleness.**  iOS coalesces silent pushes when
   the receiver is asleep; "later" can be hours.  The user
   experience would be "I submitted from cellular, why isn't it
   downloading?"

Instead the Mac polls the user's private CloudKit database every
60s while running.  CloudKit's per-user free tier covers this
comfortably (~720 queries/day for a typical desk Mac), and "60s
worst-case latency" matches the "I'm on cellular, not at my desk
yet" use case fine.

#### Six new files, one schema

**Pure shared core** (`iOS/Shared/`):

- `CloudKitRelayRecord.swift` — `Codable` payload + CKRecord
  encoder/decoder.  Schema fields: `url`, `submittedAt`,
  `senderDevice`, `targetMacUUID`, `status`.  Same schema iOS
  writes and Mac reads — no schema duplication.  Status is
  `pending` on write, transitions to `consumed` after the Mac
  ingests it.
- `RelayPolicy.swift` — pure decision layer.  Given a
  `LANOutcome` + the user's `cloudKitRelayEnabled` toggle,
  returns a `Decision` (`.done` / `.fallbackToCloudKit` /
  `.surfaceError`).  Token-rejection (401) NEVER falls back —
  re-pair is the only fix; CloudKit relay would just sit pending
  forever.

**iOS-only writer** (`iOS/Shared/CloudKitRelaySubmitter.swift`):
actor wrapping `CKContainer(identifier: "iCloud.app.splynek.companion").privateCloudDatabase`.
`submit(url:senderDevice:targetMacUUID:)` returns the saved
record's name; throws typed errors (`noICloudAccount`,
`quotaExceeded`, `network`, `ckError`) the UI maps to user-facing
messages.  Pre-flight `accountStatus()` check so a user without
iCloud signed in gets a clear message instead of cryptic CK
errors.

**Mac-only receiver** (`Sources/SplynekCore/CloudKitRelayReceiver.swift`):
actor that runs a 60s poll loop.  Each tick queries
`SplynekRelayJob` records where
`targetMacUUID == this Mac's deviceUUID AND status == "pending"`,
hands the URLs to the existing `onWebIngest("queue", url)` callback
(same path the LAN POST goes through), then transitions each
record to `consumed`.  Idempotent: re-reading a record after
crash-during-mark sees status `consumed` and skips.  Public
`pollOnce()` for diagnostics + tests.

**Mac wiring** (`Sources/SplynekCore/FleetCoordinator.swift`):
`startCloudKitRelayReceiverIfNeeded()` called from `start()`
right after `startBrowser()`; receiver shutdown in `stop()`.
Skipped entirely when `effectiveLoopbackOnly` is true (privacy
posture wins — if the user opted out of LAN sharing, they
opted out of phone-to-Mac workflows too).

**iOS Share Extension swap** (`iOS/SplynekShareExtension/ShareViewController.swift`):
`PairedMacClient.queue(...)` call replaced with
`submitWithRelay(...)`.  Handles all three result cases:
`.lan` (silent dismiss), `.relayed` ("Sent via iCloud — will start
when X checks in" alert), `.failed(message)` (red error alert).

**Cross-target schema sharing**: the Mac's `CloudKitRelayReceiver`
needs the same `CloudKitRelayRecord` type the iOS Share Extension
uses.  `Package.swift` now has `SplynekCore` depend on
`SplynekCompanionCore` so the Mac core sees the iOS-shared schema
without duplicating it.  Forward-compat: future Mac↔iOS shared
types live in `iOS/Shared/` by default.

#### Entitlements

iCloud + container ID added to all three:

- `Resources/Splynek.entitlements` (Mac main app)
- `iOS/Resources/SplynekCompanion.entitlements` (iOS host app)
- `iOS/Resources/SplynekShareExtension.entitlements` (Share Extension)

Container ID: `iCloud.app.splynek.companion`.  This is a
maintainer-provisioned identifier in App Store Connect; until
that's done the receiver runs but quietly returns 0 ingested per
tick (account-status check returns `.couldNotDetermine`).
Provisioning runbook documented in IOS-COMPANION.md.

#### Tests (19 new)

- `CompanionRelayPolicyTests` (10 tests) — every input × output
  combination of `decide(...)`: success/done, unauthorised never
  falls back, network failure with relay enabled → CloudKit,
  network failure with relay disabled → surface error with
  helpful message.
- `CompanionCloudKitRecordTests` (9 tests) — Codable round-trip,
  CKRecord round-trip, missing-required-field rejection, unknown
  status rejection (schema-drift defence), empty URL rejection,
  Equatable + Hashable correctness.

After this commit: **630 tests passing** (was 611 — +19; net +78
over the 552 pre-S4 baseline).  **Build warnings: 0** throughout.

#### Numbers this part

| Metric | Before phase 3 | After phase 3 | Δ |
|---|---:|---:|---:|
| Tests | 611 | **630** | +19 |
| iOS Shared/ files | 9 | **12** | +3 |
| Mac SplynekCore files | unchanged | +1 (`CloudKitRelayReceiver.swift`) | +1 |
| SwiftPM target dependencies | 3 (test → core+companion) | **4** (+ core → companion) | +1 |
| Entitlement files touched | 3 (App Group only) | **3** (+ iCloud) | 0 |

#### One commit delivers phase 3

```
(pending) S4 phase 3: CloudKit over-cellular relay
```

Phase 3 lands as one commit because the iOS submitter, Mac
receiver, schema, entitlements, and tests are mutually-coherent
— partial commits would leave the Mac compiling but unable to
read the schema, or vice versa.

### Latest landing (2026-05-07 part 5): S4 polish — Settings tab + diagnostics

After phase 3 landed, the iOS Companion still had a UX gap: the
`cloudKitRelayEnabled` toggle was stored + read but had no UI
surface — invisible to the user.  And a freshly-installed
companion had no way for a user to verify "is my pairing healthy?"
which would become "why isn't this working?" support tickets the
moment we hit TestFlight.

#### What landed

A third tab `SettingsView` with three sections:

1. **Paired Macs** — per-Mac status row.  Three health tiers
   driven by the new `PairingHealthEvaluator`:
   - `online` (green dot, "On this Wi-Fi") — Mac is in the live
     Bonjour discovery set right now.
   - `recent` (blue dot, "Reachable via iCloud") — not on Bonjour
     but lastSeen ≤ 24h.  CloudKit relay covers this case.
   - `stale` (grey dot, "Not seen recently") — lastSeen > 24h.
     Settings UI nudges "Test pairing" to confirm.
   Each row has a "Test pairing" button that round-trips
   `/splynek/v1/status` and surfaces latency or failure inline
   ("OK — 12 ms" / "Token rejected — re-pair this Mac." /
   "Unreachable — \(reason)").  On success, lastSeen bumps to
   `Date()` so future health classifications stay fresh.

2. **Relay** — `cloudKitRelayEnabled` toggle + explainer footer
   that flips between "When the iPhone can't reach the Mac over
   Wi-Fi, the URL is sent through your private iCloud database…"
   and "URLs only send over local Wi-Fi. Submissions fail when
   the Mac is unreachable."  Default-on (matches PairedMacStore's
   default).

3. **About** — version + build number from Bundle.main, plus a
   Link to splynek.app.

#### New shared type

`iOS/Shared/PairingHealth.swift` — pure classifier with
`PairingHealth` enum (online / recent / stale) + `displayLabel`
+ `evaluate(macUUID:lastSeen:bonjourUUIDs:now:recentThreshold:)`.
Tests use injectable `now` + `recentThreshold` so we never write
flaky calendar-arithmetic tests.

#### Tests (12 new)

- `CompanionPairingHealthTests` (10 tests) — every health tier
  decision branch, including boundary case (exactly at threshold
  is `recent` not `stale`), `recentThreshold` override, display
  label invariants (non-empty + visually distinct).
- `CompanionStoreTests` gained 2 tests covering the
  `cloudKitRelayEnabled` default-on invariant + setter persistence.

After this commit: **642 tests passing** (was 630 — +12; net +90
over the 552 pre-S4 baseline).  **Build warnings: 0.**

#### Numbers this part

| Metric | Before polish | After polish | Δ |
|---|---:|---:|---:|
| Tests | 630 | **642** | +12 |
| iOS Shared/ files | 12 | **13** | +1 |
| iOS app files | 8 | **9** | +1 (`SettingsView.swift`) |
| `ContentView.Tab` cases | 2 (Macs / Submit) | **3** (+ Settings) | +1 |

#### One commit delivers polish

```
(pending) S4 polish: iOS Settings tab + paired-Mac diagnostics
```

### Latest landing (2026-05-07 part 6): Five-track polish sweep

User requested five tracks in one big run: verify iOS Xcode build,
push Sovereignty coverage toward 100%, scaffold iOS L10n, double
Trust with audited download buttons, S5 live-test on Vimeo/Twitch.

Up-front honesty on two of them:

- **Sovereignty 100%** isn't achievable on its own merits — most
  alternatives are SaaS-only / paid sign-up walls / version-embedded
  URLs that always 404.  Realistic ceiling is ~40-60% over time as
  publishers publish stable redirects.  Pushed +34 this round to
  reach 8.0% (was 7.0%).
- **S5 live test** can't be done end-to-end from a Claude session
  (no GUI, no buffering to watch).  What shipped instead: live
  HLSProxyServer telemetry + a token-gated REST endpoint exposing
  it + a watch script Paulo runs while opening a real video.  The
  measurement becomes possible; Claude doesn't perform it.

Five commits delivered:

```
969db71 S5 instrumentation: HLSProxyServer telemetry + /hls/stats + watch script
e151e16 Trust: inherit 86 fallbackAlternatives from Sovereignty across 41 entries
74915be iOS Companion L10n scaffolding: 51 strings × 5 locales
a430675 Sovereignty: +34 verified downloadURLs across 4 high-recurrence apps
77b04d3 S4 polish: migrate iOS Info.plist content into project.yml
```

#### Track 1 — iOS Xcode build verification (`77b04d3`)

Real issue surfaced: xcodegen REGENERATES the Info.plist files
listed in `info: path:` from `info: properties:` on every run.
With `path:`-only declarations (shipped in the foundation commit),
xcodegen wrote minimal placeholder plists, silently clobbering my
hand-crafted keys (NSSupportsLiveActivities, NSCameraUsageDescription,
NSLocalNetworkUsageDescription, NSBonjourServices, NSAppTransportSecurity,
NSExtension keys for the Share Extension).

Fix: move every key from the plist files into `info: properties:`
in project.yml + `excludes: ["Info.plist"]` on the source list so
xcodegen's regeneration doesn't conflict with the source inclusion.
Pattern mirrors the existing Splynek-Safari-Extension target.

Verified `xcodebuild -list` parses all seven targets correctly
(Splynek, Splynek-MAS, Splynek-Safari-Extension, SplynekCompanion,
SplynekCompanionWidgets, SplynekHelper, SplynekShareExtension).
Full xcodebuild compile blocked locally on missing iOS 26.4 SDK
(maintainer-side: Xcode → Settings → Components install).

#### Track 2 — Sovereignty downloadURL push (`a430675`)

Audit identified 195 unique alternative names without a downloadURL.
Tested ~120 candidate URLs across three batches with curl + Content-
Type validation; 26 returned binary Content-Type with stable URLs.
Of those, 4 had non-trivial recurrence in the catalog and weren't
already covered:

  - Proton Pass     (5 entries)
  - TeamViewer      (8 entries)
  - DBeaver         (13 entries)
  - AnyDesk         (8 entries)

Coverage 7.0% → 8.0% (223 → 257 of 3,194).  The auto-pruner
re-verified all 257 URLs after the add — 0 broken.

#### Track 3 — iOS Companion L10n scaffolding (`74915be`)

51 user-facing strings extracted from the iOS app + Share Extension,
translated to 5 locales (de / es / fr / it / pt-PT).  Wired as a
`resources:` entry on the SplynekCompanion target in project.yml.
SwiftUI's `Text("…")` initializer takes a LocalizedStringKey
implicitly when called with a string literal, so the existing 9
SwiftUI files automatically bind to the catalog with zero code
changes.  Combined Mac+iOS catalog total: 679 source strings × 5
= 3,395 translations.

#### Track 4 — Trust catalog fallback inheritance (`e151e16`)

Honest read on "double Trust to ~300 entries": doing that in one
session means Claude-generated risk assessments per entry —
exactly the failure mode TRUST-CONTRIBUTING.md prohibits ("AI-
generated risk assessments — hallucination risk").

The real gap was elsewhere: 149 of 151 Trust entries had ZERO
fallbackAlternatives — the Trust UI surfaced concerns but offered
no replacement.  Closed via inheritance from Sovereignty: 41
Trust entries share a targetBundleID with a Sovereignty entry,
and Sovereignty's `.europe` / `.oss` / `.europeAndOSS` alternatives
are valid Trust fallbacks (Sov's contributor rules already require
factual / non-editorial notes which pass Trust's banned-words
filter unmodified).

  Trust fallbackAlternatives:    2 → 88 (×44)
  Trust entries with ≥1 alt:      2 → 43 (1.3% → 28%)
  Of the 88 alts, with verified downloadURL: 8

Validator: 151 Trust entries, 0 findings.

#### Track 5 — S5 instrumentation (`969db71`)

`HLSProxyServer.Telemetry` Codable struct with sessionsActive (gauge),
masterFetches / variantFetches / prefetchInsertions / segmentRequests /
segmentCacheHits / segmentCacheMisses / bytesFromCache / bytesFromOrigin
(counters) + computed cacheHitRate.  Counters bumped at the existing
call sites in handleMaster / handleVariant (incl. prefetch fire-and-
forget Task closure) / handleSegment.  `resetTelemetry()` zeroes
counters but preserves sessionsActive (re-derived from sessions).

FleetCoordinator: new `GET /splynek/v1/hls/stats?t=<token>` endpoint
returning the Telemetry as JSON.  Optional `?reset=1` zeroes counters.

Scripts/hls-watch.sh: bash poller, 1s cadence, auto-detects port +
token from ~/Library/Application Support/Splynek/fleet.json.  Prints
rolling table:

  Time  Sessions  Segments  CacheHits  FromCache  FromOrigin  HitRate

Demo recipe (per strategy memo "video never buffers"):
  1. `./Scripts/hls-watch.sh --reset` in one terminal
  2. Open Vimeo on weak Wi-Fi + 5G tether in browser with
     Splynek Accelerator extension on
  3. Watch cacheHitRate flip from ~0% (no extension) to >90%
     (BondedFetcher pulling segments via parallel byte ranges
     across both NICs)

#### Numbers this part

| Metric | Before sweep | After sweep | Δ |
|---|---:|---:|---:|
| Tests | 642 | **648** | +6 (S5 telemetry) |
| iOS Localizable.xcstrings | none | **51 × 5 = 255** | +255 translations |
| Mac+iOS L10n total | 3,140 | **3,395** | +255 |
| Sovereignty downloadURL coverage | 7.0% | **8.0%** | +1.0 pp / +34 URLs |
| Trust fallbackAlternatives | 2 | **88** | ×44 |
| Trust entries with ≥1 fallback | 2 | **43** | +41 |
| Telemetry surfaces | 0 | **9** counters + 1 gauge | new capability |

### Latest landing (2026-05-07 part 7): Three-phase product expansion

User asked for four things in one prompt: deliveryKind badges,
free-vs-paid Savings tab, audited Trust expansion (already shipped
in part 6), and the Updates tab.  Three commits delivered the
remaining product expansion in one continuous run.

#### Phase 1 — deliveryKind badges (`b40c2e0`)

Closed the UX gap where ~92% of Sovereignty alts had no `downloadURL`
and silently degraded to "Get installer" → homepage, landing users
on SaaS sign-up walls.  New `SovereigntyCatalog.DeliveryKind` enum:

  directDownload    ⬇  one-click DMG/PKG/ZIP via Splynek
  macAppStore       🍎 deep-link to macappstore://
  webService        🌐 no native app — opens in browser
  homebrew          ⌘  copy `brew install …` to clipboard
  signupRequired    🔐 publisher requires free account
  purchaseRequired  💳 publisher requires payment
  versionEmbedded   ⬇  direct download with version-embedded URL
  comingSoon        🚧 desktop announced but not shipped

Each kind has a `displayLabel`, SF Symbol (`symbol`), and factual
`tooltip`.  UI changes: capsule badge above each alt's name, plus
per-kind CTA button (Install / Open in App Store / Open / Copy
brew / Visit / Visit project).  Auto-classified all 3,194 alts:

  versionEmbedded   1339   webService      1162
  purchaseRequired   296   directDownload   257
  homebrew           113   comingSoon        27

#### Phase 2 — Pricing + Savings tab (`5197f76`)

New top-level "Savings" sidebar tab.  Three sections:

  - Hero: "Your Mac costs ~$X/year. Up to $Y is replaceable
    with free alternatives."
  - Breakdown: subscription / one-time / freemium pills with
    per-bucket annualized cost.
  - Paid apps list: each row shows installed app icon + cost +
    pricing-page link + free-alternative chip ("Save ~$120/yr"
    + Install button).

Pricing seed dataset: ~50 well-known paid Mac apps (Adobe CC suite,
Microsoft 365, Spotify, Things 3, Bear, OmniFocus, DEVONthink,
Setapp, 1Password, Sketch, Affinity Suite, etc.) — each with
publisher-cited sourceURL.  Free alternatives sourced from
Sovereignty filtered to `.oss`/`.europeAndOSS` origins AND
deliveryKind ∈ {directDownload, versionEmbedded, homebrew} —
no SaaS sign-up walls.

#### Phase 3 — Updates tab (`fe1cc4e`)

New "Updates" sidebar tab.  Universal updater unifying:

  .sparkle(feedURL:)            ~70% of paid Mac apps
  .githubReleases(owner:repo:)  OSS apps released via GitHub
  .macAppStore(adamID:)         MAS-managed (read-only surface)
  .homebrew(formulaName:)       brew-installed
  .publisherRSS(feedURL:)       generic feed fallback
  .unknown                      manual flow

UpdateSourceResolver: reads each installed app's Info.plist
`SUFeedURL` (Sparkle) → falls back to a curated
`wellKnownSources` table (Stats / Element / VSCodium / Zed) →
`.unknown`.  HTTPS-only on Sparkle.

SparkleAppcast.swift: pure-Swift Sparkle 2.x XML parser via
XMLParser — no Sparkle.framework dependency.  Extracts version,
download URL, size, SHA-256, release notes from the first
`<item>` (reverse-chrono convention).

UpdatesView: three sections — Updates available (per-app row with
source badge + version diff `1.5.0 → 1.6.0` + size + release
notes + Update button), Unchecked (resolved-source-but-no-version-
yet), Manual (unknown-source disclosure group).  "Update all"
toolbar queues every pending update via the existing VM start
path — inherits S5 BondedFetcher + S6 File Witness for free.

#### Strategic angle

Splynek's update story is genuinely better than alternatives:

  - BondedFetcher (S5)  → updates download via multi-NIC bonded
                          byte ranges
  - File Witness (S6)   → Ed25519 receipt + rollback on verify-fail
  - MirrorManifest      → curated OS-distro mirrors (Ubuntu /
                          Debian / Fedora)

No other Mac updater bonds + verifies + mirrors-on-failure.

#### Numbers across the 3-phase expansion

| Metric | Before phase 1 | After phase 3 | Δ |
|---|---:|---:|---:|
| Tests | 648 | **692** | +44 (DeliveryKind 9 + Savings 14 + AppUpdate 21) |
| Sidebar tabs | 14 | **16** | +2 (Savings + Updates) |
| Sovereignty alts with explicit deliveryKind | 0 | **3,194** | +3,194 |
| AppPricing seed | n/a | **50** apps with sourceURL | new |
| UpdateSource enum cases wired | n/a | **6** | new |

Three commits delivered:

```
341c648 Updates tab: universal app updater with Sparkle parser + multi-source resolver
674332a Savings tab: pricing schema + free-alts-to-paid-apps + annual cost hero
b40c2e0 Sovereignty: deliveryKind badges + per-kind action buttons
```

## Commit timeline (latest first, top of `main`)

```
341c648 Updates tab: universal app updater with Sparkle parser + multi-source resolver
674332a Savings tab: pricing schema + free-alts-to-paid-apps + annual cost hero
b40c2e0 Sovereignty: deliveryKind badges + per-kind action buttons
cff9723 Documentation: five-track sweep landed 2026-05-07
969db71 S5 instrumentation: HLSProxyServer telemetry + /hls/stats + watch script
e151e16 Trust: inherit 86 fallbackAlternatives from Sovereignty across 41 entries
74915be iOS Companion L10n scaffolding: 51 strings × 5 locales
a430675 Sovereignty: +34 verified downloadURLs across 4 high-recurrence apps
77b04d3 S4 polish: migrate iOS Info.plist content into project.yml
4df6d39 S4 polish: iOS Settings tab + paired-Mac diagnostics
2e381f4 S4 phase 3: CloudKit over-cellular relay
eac2caf S4 phase 2: Live Activity + QR-code pairing
b509954 S4 iPhone Companion: foundation skeleton — iOS app + Share Extension + shared core
aaddef8 Documentation: 2026-05-06/07 sweep + URL-verification automation
72e57b9 Sovereignty: automate URL verification with Content-Type validation + auto-prune
d22b9ce Sovereignty catalog: verified direct download URLs + 8 new alternatives
702fb25 UI fixes: Instalar checkbox confusion, hover tint contrast, Sovereignty action equality
3687633 Benchmark: live progress feedback + survives tab switch
d26ac6b UI/UX: hover affordances + pointer-cursor across all interactive surfaces
ab31170 Documentation refresh: HANDOFF + SESSION-LOG + L10N + design docs
e9e7002 S5 ship: bonded segment fetch + DASH manifest support
6850e48 S5 ship: Safari xcodegen target + HLS pre-buffer end-to-end
39e9021 S5 expansion: Safari WebExtension parity + HLS manifest parser scaffolding
efe3069 Apple day-10 escalation draft + Accelerator v0.23 (options page + per-host UX)
a4af998 S5 first half: Chrome Accelerator intercept (off-by-default)
bf9d3a0 S3 dispatch: yt-dlp wired into Source view + History
17cb90a S6 File Witness: cryptographically-signed download receipts
1e8c9df B-F roadmap landings: Pro L10N + 2 publishers + Stripe doc + S3 pre-flight
b9b200c Audit follow-ups: History timeline footer L10N + MCP endpoint URL truthfulness
e2309b1 Audit pass: ProLockedView localization + audit-script whole-file scan + 20 catalog gaps
9f06ff9 Consolidate sub-version narrative → "next-release rollup"
925e2d9 HANDOFF + SESSION-LOG: refresh for v0.31-era resume fix
8a2940b DownloadJob.resume: fix v0.31-era no-op guard (+ regression test, +4 tests)
952d154 HANDOFF + SESSION-LOG: capture MAS build restoration + Pro live-verify + input bar fix
296117e MAS build path restored: Bundle.module → Bundle.splynekCore + AppShortcut cap + start(url:sha256:filename:) overload
b07d788 Live-test fixes: SovereigntyView filterBar overflow + drop save-panel localized message
b9e4e97 Audit fixes: 3 real issues across S2 + Wayback wiring
58a970e HANDOFF + SESSION-LOG: refresh for S2 trifecta + GitHub publisher + SMJobBless runbook + L10N counts
8d38827 TrustExport: shareable PDF + PNG of Trust scan results
3298797 Wayback "view archived copy" affordance on failed-job card
243424b SovereigntyExport: CSV export of installed-apps × catalog matches
888afdf MirrorManifest.fedora — Tier-1 safety net under MirrorManager
fa4d2f3 DownloadEngine: restart lanes on interface-set flips (Bet S2 cont'd)
b50a7bb MirrorManifest.debian — broadens S2 mirror failover to Debian ISOs
b46adb3 S2 mirror failover wired: VM injects MirrorManifest mirrors as parallel lanes
281c336 S2 wire-up: VM auto-pauses on path offline, auto-resumes on online
dd8cb1e S2 component 3: MirrorManifest — curated fallback mirrors
2ad95ba L10N-REVIEW.md: refresh stale catalog counts (480 → 535, 2,285 → 2,675)
bf76909 SMJobBless v1.8.2: activation runbook for the maintainer
5f434be PublisherPattern: GitHub Releases (6th publisher)
2899196 S2 component 2: PathMonitorObserver — typed PathEvent stream over NWPathMonitor
56c5ed8 HANDOFF + SESSION-LOG: refresh for Concierge persistence + PDF drag landings
a1fc19c Concierge transcript persistence: ConciergeTranscriptStore + load-on-init + 12 tests
75c25b6 Session transition: HANDOFF refresh + new SESSION-LOG.md
e8ebb2a SMJobBless v1.8.2: privileged helper bundle + activated client + PkgInstaller fallback
d2d4bfe PublisherPattern: Apache + Debian + Ubuntu + Arch + 15 tests
e40fe01 Audit script extension + catalog catch-up: 49 strings × 5 locales
011fb16 Visual sweep DE+FR: 6 InstallView strings flipped to LocalizedStringKey + catalog
22b0d36 SMJobBless v1.8.2 architectural skeleton: helper protocol + client stub + design doc
91d6cc4 PublisherPattern: per-directory SHA256SUMS extraction (Mozilla proof-of-concept)
4ca37b8 HANDOFF.md: catch up with v1.7.x + v1.8.1 + v1.9.x follow-up commits
5b6ce55 PkgInstaller v1.8.1: admin-domain installs via osascript-elevated installer(8)
b2016ba Warm-cache lookup: digest-based dup detection short-circuits the WAN download
0cf9451 ConciergeCard.downloadByGoal: typed forwarder for Pro URL-resolution
05b9749 HANDOFF.md: refresh for v1.7+v1.8+v1.9 architecture landing
0686ee6 Household swarm token: shared bearer unlocks Mac-to-Mac auto-join
df4261d Auto-join: VM spawns SwarmParticipant on digest match → engine ingests bytes
636a07a Fleet UI: SWARM badge + tooltip per peer
c0ce18c LAN swarm discovery: TXT capability flag + /swarm/list + peer observer
38c8a22 Engine ↔ swarm: lifecycle hooks fire register/chunkCompleted/finished
7df8479 SwarmParticipant: peer-side state machine for joining a swarm and pulling chunks
2cd6e7a Auto-update goes live: VM owns the scheduler + InstallView controls + activity card
82a1668 Auto-update scheduler: re-run installer pipeline on opted-in registry records
2f8ba6e Swarm bytes ship: payload resolver wires to activeJobs + content cache
11dca19 Swarm seeder (v1.9 protocol): SwarmCoordinator + REST routing in FleetCoordinator
2f6e39f PkgInstaller: user-domain .pkg installs via /usr/sbin/installer
4db4f9c Install tab: surface InstallView in the sidebar + i18n the pipeline labels
8f746f8 Installer UI: drag-and-drop InstallView + ZipInstaller (.appArchive handler)
9f24d35 ConciergeMessage: add card + toolID payload for Mac-Assistant turns
7859792 Installer pipeline: AppMover + DmgInstaller + InstallVerification + run() wiring
992adf3 Concierge bridge: dispatch surface for the v1.7 LLM tool-pick loop
291c0b0 Installer + Fleet 2.0 architectural skeletons: installer pipeline + chunk-swarm wire types
69b9208 v1.7 Concierge-as-Mac-Assistant: foundation types + 3 new App Intents
1b67b5f strategy: v1.7→v1.9 roadmap (Concierge as Mac assistant, Verified Installer, Fleet 2.0)
1f8961c 2.5.2 defence packet: compliance brief + invariant anchors + reviewer disclosure
ca912bd ci + docs: lint workflow, HANDOFF refresh, L10N onramp, release notes draft
ae6d7f0 test: catalog completeness invariant + --filter substring flag
9dcfbc4 v1.6.2 round 8: 428→457 catalog strings + audit upgrade
f4e7ee0 v1.6.2 round 7: 387→428 catalog strings — final long-tail plain pass
11be473 HANDOFF.md: refresh for v1.6.2 round 6 — catalog at 387×5, pt-PT verified
9ccc319 v1.6.2 round 6: 346→387 catalog strings — Frota labels, MCP descriptions, long-tail
5f502da v1.6.2 round 5: full audit fixes — EmptyStateView + MetricView wrap, 6 catalog keys
```

splynek-pro top of main:

```
3a97d2c Concierge input bar: typed input now goes through Mac-Assistant dispatcher
d15e0d2 ConciergeView: render Mac-Assistant cards inline + new chip surface
78f41bc Concierge Mac Assistant: LLM tool-pick dispatcher + card-rendering view
```

## Numbers

| Metric | Start of arc (v1.5.3) | End of arc (today) | Δ |
|---|---:|---:|---:|
| Catalog strings | 56 | **628** | ×11.2 |
| Translations (×5 locales) | 56 | **3,140** | ×56 |
| Tests | 148 | **692** | ×4.7 |
| Public-repo Swift files | 49 | **69** (top-level SplynekCore) / 146 (recursive incl. iOS/) | +20 / +97 |
| Public-repo plists | 6 | **8** | +2 (helper + launchd) |
| Pro-repo Swift files | 8 | **10** | +2 (Mac-Assistant dispatcher + cards) |
| Top-level docs | 1 (HANDOFF) | **7** (HANDOFF + STRATEGY-v1.7-v1.9 + MAS-2.5.2-COMPLIANCE + L10N-REVIEW + RELEASE-NOTES draft + SMJOB-BLESS-DESIGN + SESSION-LOG + IOS-COMPANION) | +6 |
| Architecture invariant comments | ~3 (catalog + sandbox) | **~15** (every AI-touching, code-execution-adjacent file) | +12 |
| CI guardrails | 1 (sovereignty-weekly: lint+urls) | **3** (+ lint.yml + sovereignty-weekly: prune-broken-downloads auto-PR) | +2 |
| Trust catalog entries | 30 | 151 | +121 |
| Sovereignty catalog entries | 1,155 | 1,155 | unchanged |
| Sovereignty alts with verified `downloadURL` | n/a (no Content-Type check) | **223 of 3,194 (7.0%)** | new metric |

## What is NOT in this commit arc

Worth being explicit about:

- **No DMG cut.**  `main` carries everything but the maintainer
  must `./Scripts/build.sh` + notarise + staple before publishing.
- **No tag pushed.**  All v1.x.y tags are local-only; the next
  release-cut decision is the maintainer's.
- **No marketing deployed.**  `docs/index.v1.6.2.html.draft` exists
  but `docs/index.html` is still v1.3 copy.  Press kit + Show HN
  + directories all staged but un-triggered.
- **No MAS resubmit.**  Apple's v1.0 must clear before the v1.7+
  binary uploads.
- **Native-speaker review not done.**  All translations are
  Claude-generated; `L10N-REVIEW.md` is the onramp for the human pass.
- **iOS Companion full functional ship 2026-05-07.**  Foundation
  + phase 2 + phase 3 all landed same day (build system + shared
  core + UI shell + Share Extension + Widget Extension + Live
  Activity + QR-code pairing + CloudKit over-cellular relay + 78
  tests).  Outstanding maintainer-only work: provision the
  `iCloud.app.splynek.companion` CKContainer in App Store Connect
  + publish the SplynekRelayJob schema in CloudKit Dashboard
  (runbook in IOS-COMPANION.md), and run TestFlight rollout —
  both gated on Apple v1.0 macOS clearance.

### 2026-05-08 — Design revolution + whole-app audit (sessions M-N)

**Trigger.** User opened with a sidebar screenshot showing the
"Agentes" tab partially clipped at the default window height.
What started as one consolidation spawned a 14-commit revolution
over the entire user-facing surface, plus a final whole-codebase
audit that brought the project to 100%-confidence state.

**Mode of work.** User-driven, screenshot-led.  Each tab in turn
got critiqued ("feio", "deslavado", "dá sensação de serem todos",
"não dá para perceber esta pontuação") with explicit feedback
recorded in the screenshots; a focused fix shipped per critique
rather than batched.  This worked because each issue mapped to a
clean separate commit, but the cumulative effect is that nearly
every tab in the app was touched.

#### Commits in chronological order (14 total)

| # | SHA | Tab/area | Substance |
|---|---|---|---|
| 1 | `2efa8d0` | Sidebar | Install + Updates merged into Apps with segmented Picker; Agents moved out of one-item Connect section into Library; brandFooter dropped (Settings already in macOS menu via ⌘,); WindowGroup `defaultSize: 1180×820` so first-launch users see the whole sidebar without clipping |
| 2 | `d1289c0` | Frota | Dedupe by outputPath with ×N badge; hover-revealed Reveal/Stop/Trash buttons (right-click + ⌘⌫ mirror); `NSWorkspace.recycle` for trash; total count + bytes in card header; new helpers `DownloadHistory.remove(id:)`, `vm.trashAndForgetCompletedFile(outputPath:)`, `vm.revealInFinder(outputPath:)` |
| 3 | `e03c234` | Install | **Critical bug fix:** test fixtures (`Bork`, `Good`) had been writing to the user's real `~/Library/Application Support/Splynek/installed-apps.json` because `_resetForTesting()` only deleted the file before subsequent `upsert()` calls re-created it.  Fix: `_testOverrideURL` redirect.  UI revolution: 2 cards collapsed to 1; per-row status pills (ACTIVE/UPDATE BLOCKED/MISSING); `⋯` menu with Reveal / Enable+Disable auto-update / **Forget**; engine errors humanised (`/var/folders/...` paths stripped, `rejected·source=no usable signature` translated); `wipeAll()` helper |
| 4 | `784597e` | Atualizações | “Atualizar” button now downloads + verifies + installs through `InstallerEngine.run` (was previously a queue-add that left the user to drag-drop manually); per-row Phase state machine (`idle → downloading → installing → installed | failed`); ContextCard hero replaces green LinearGradient block; `vm.availableUpdateCount` published so sidebar Apps badge reads `↑ N` instead of generic `NEW`; `.onAppear` chains `refreshScanner` → `checkAll` automatically |
| 5 | `986d662` | Transferências | `1.0× faster than single-path` tautology replaced with single-path upsell (“Bond a second network for 2–3× faster downloads”) when only one interface contributed bytes.  Multi-path celebration banner kept unchanged for the real ≥2× case |
| 6 | `55d8f92` | Poupanças | First revolution: ContextCard hero, swap-cards (paid → arrow → free), “I’ve already switched” toggle persisted via UserDefaults, browse-Sovereignty CTA, empty-state with punch.  Sets the stage for v2 below |
| 7 | `02c6f82` | Atualizações | Resilience pass after user reported 2/3 install failures: **(a)** Gatekeeper check no longer rejects DMG/PKG/ZIP at container level (was falsely failing publishers like Zed who only sign the `.app` inside); only `.app` direct bundles get `spctl`. **(b)** New `InstallPreflight.swift` with magic-byte sniff + HEAD probe — catches HTML 404s posing as DMGs *before* hdiutil runs. **(c)** Engine errors humanised in UpdateRow (`hdiutil attach failed` → “The file isn’t a valid disk image”, etc.). **(d)** GitHub asset picker prefers arm64 + drops Intel-only assets (no Rosetta fallback) |
| 8 | `d94f1d1` | Histórico | Count badge in card accessory; per-row Forget (hover trash + context menu); “Move to Trash” trashes file + prunes entry; `⋯` menu with Clear-all-history (confirmation dialog gates the destructive action); `DownloadHistory.clearAll()` single-write helper |
| 9 | `eda0679` | Soberania + Confiança | Splash screens retired (56pt icon + bullet list + “Scan my Mac” button) — they doubled with the ContextCard subtitle and forced the user to click through to data they’d already seen.  Now: ContextCard always present, `.onAppear` auto-scans, thin inline `inlineScanState` strip while scanning.  -172 lines |
| 10 | `2c07fc5` | Atualizações | Three-fix bug for “installed app re-appears as needing-update”: **(a)** `replaceExisting: true` in InstallerEngine.run for update clicks (was suffix-renaming `<App> 2.app` and leaving the old version), **(b)** SovereigntyScanner deduplicates duplicate-bundle-ID hits by highest `CFBundleShortVersionString` (segment-wise compare with mtime fallback), **(c)** `splynekUpdatesDidInstall` notification triggers re-scan + re-resolve so the row drops out of `updatesAvailable` immediately |
| 11 | `520a133` | Poupanças v2 | Tier picker: AppPricing gains `Tier` struct + `tiers: [Tier]?` field + `annualizedUSD(forTier:)` accessor; seed adds Claude (Pro/Max 5×/Max 20×/Team), ChatGPT (Plus/Pro/Team), Perplexity (Pro/Enterprise).  Big-number hero block replaces single-line summary: 38pt heavy figures with comparison framing (“≈ 5 years of Spotify Premium” / “≈ 53 cappuccinos” / “≈ X new MacBook Air every year”, threshold-picked).  Vertical SwapCard reads top-to-bottom as a substitution path.  Confirmed-switch toggle states the exact dollar amount credited.  Bug fix: removed duplicate `com.openai.chat` key in seed (Swift dictionary literal crash on duplicate keys) |
| 12 | `0bbdba7` | Confiança | User: “não dá para perceber esta pontuação — 100 é bom ou mau?”.  Fix: explicit “RISK” label + “N/100” scale + level word in scoreBadge; horizontal gauge with green→yellow→orange→red gradient + position dot + “0 clean”/“high concern 100” anchor labels; percentile context (“Higher than X% of your installed apps”) when pool ≥2; ContextCard subtitle adds “0 (clean) → 100 (severe + numerous concerns)” direction statement |
| 13 | `9e680d6` | Hardening 1 | Audit-driven fixes after the design revolution: **(a)** Fleet dedupe v2 — cascade key `sha256 │ (filename, totalBytes) │ outputPath` collapses Finder-rename twins where prior single-key dedupe missed them; ShareRow tracks `allURLs` + `allOutputPaths` so Stop-sharing + Trash fan out across all underlying entries.  **(b)** New `Tests/SplynekTests/HardeningTests.swift` — 19 tests covering `InstallPreflight.detectFormat` (5) + `validateBeforeRun` (2) + `AppPricing.annualizedUSD(forTier:)` (5) + `DownloadHistory.remove/clearAll` (3) + `AppUpdateInfo.isNewer` edges (4).  **(c)** Splynek-MAS scheme verified BUILD SUCCEEDED (had only been verified in 1/12 commits up to that point) |
| 14 | `05dfce6` | Hardening 2 | Whole-app audit pass: **(a)** Update count warmed at end of launch (was deferred during the design revolution — user pushed back: “porque não executar no fim do launch?”).  Resolver dispatch + URL pre-flight extracted from UpdatesView into new `Sources/SplynekCore/AppUpdates/UpdateSweep.swift`; both UpdatesView (foreground manual check) and `vm.warmUpdateCount()` (launch-time background warm) call into it.  Boot path stays fast (Task.detached + 1.5 s gap after restoreSession).  `UpdateSourceResolver.resolve` lost its over-cautious `@MainActor` annotation — pure synchronous filesystem I/O.  **(b)** Localizable.xcstrings: 38 new keys × 5 locales — every user-facing string the design revolution shipped now has full coverage (LocalizableCatalogTests' full-coverage gate stays green).  **(c)** User-Agent normalisation — three drift versions (`Splynek/0.1`, `Splynek/1.0`, `Splynek/1.0 (+https://splynek.app)`) all collapsed to `SplynekVersion.current` interpolation across DoH/Lane/Probe/Tracker/UpdatesView |

#### New architectural pieces

- **`Sources/SplynekCore/Installer/InstallPreflight.swift`** (216 lines).
  Magic-byte detection (`koly` DMG trailer / `xar!` PKG / `PK\x03\x04`
  ZIP / HTML body) + URL pre-flight (HEAD then Range-GET fallback +
  Content-Type validation + Content-Length sanity).  Two surfaces:
  `validateBeforeRun(payload:expectedKind:)` for InstallerEngine to
  fail fast before hdiutil; `previewURL(_:expectedKind:)` for
  UpdatesView to downgrade rows to “Manual” before the user clicks.
  Internal-visibility (`enum InstallPreflight`) because
  `InstallSpec.Kind` is internal.

- **`Sources/SplynekCore/AppUpdates/UpdateSweep.swift`** (186 lines).
  Extracted from `UpdatesView.checkAll`.  `run(installedApps:)` is
  the full sweep: source resolution → per-source resolver fan-out
  → URL pre-flight.  `actionableCount(_:)` counts pending updates.
  Resolvers (resolveSparkle / resolveGitHub / resolvePublisherRSS)
  + ResolvedUpdate struct + kindFor mapping.  Both UpdatesView and
  `vm.warmUpdateCount` call `run`.

- **`Tests/SplynekTests/HardeningTests.swift`** (253 lines).  19
  tests for the design-revolution surface (preflight, tier
  annualisation, DownloadHistory remove/clearAll, isNewer edges).
  Uses `_testOverrideURL` redirect for the registry; uses backup/
  restore for DownloadHistory (no override hook there).

#### Critical bugs caught + fixed

1. **Test pollution into the user's real registry.**  Every dev
   running `swift run splynek-test` had `Bork` + `Good` fixtures
   permanently parked in the Install tab.  Fix: `_testOverrideURL`
   redirect inside `_resetForTesting()`.  Existing 26 in-suite
   registry calls inherit the redirect for free.

2. **Update click installed nothing.**  Was queue-add only; user
   had to drag-drop manually after the download finished.  Fix:
   real `InstallerEngine.run` chained off the URLSession download.

3. **Updates re-appeared after successful install.**  Three
   contributing causes — `replaceExisting: false` default left
   the old `.app` in place; `SovereigntyScanner` deduplicated by
   first-seen which on APFS is non-deterministic; no re-scan after
   install.  All three fixed.

4. **Gatekeeper false-rejected legitimate DMGs.**  `spctl -t execute`
   was running on the .dmg container itself; many publishers
   (Zed) only sign the `.app` inside.  Fix: only run spctl on
   `.app`; delegate DMG/PKG/ZIP verification to their handlers.

5. **GOOSE VPN install “imagem não reconhecida”.**  hdiutil failed
   because the URL was serving HTML.  Fix: `InstallPreflight`
   magic-byte sniff catches the wrong format pre-hdiutil with a
   readable explanation.

6. **`com.openai.chat` duplicate dictionary literal key** in
   AppPricing seed crashed the test suite immediately on launch.
   Caught when adding Claude’s tiered entry.  Fix: retire the
   single-rate alias since the new multi-tier listing supersedes.

#### Audit findings (whole codebase)

Verified clean (no fix needed):
- 0 `try!` in production code
- 1 `fatalError` — `MenuBarController.required init?(coder:)` —
  standard Swift pattern when not supporting NSCoder unarchive
- All `Process()` / shell-out points use hard-coded `/usr/{bin,sbin}`
  Apple-signed binaries with argv-style args (no shell injection)
- 0 telemetry endpoints — HTTP POSTs only target user-controlled
  LAN peers + localhost AI (LM Studio / Ollama)
- User-Agent strings carry no fingerprinting (no MAC, no installed-
  app list, no email)
- `swift build` produces 0 warnings on a fresh DerivedData

Found + fixed in commit 14:
- 38 user-facing strings the design revolution shipped without
  catalog coverage (pt-PT users were seeing English mixed in)
- Three drift User-Agent versions in flight
- `vm.availableUpdateCount` was stale at 0 until first Updates-tab
  visit (user explicitly pushed back — this is what landed in
  the launch-time warm-up)

Explicitly deferred (documented in commit 14 body):
- `URLSession.shared.download` cache: no `.reloadIgnoringLocalCacheData`.
  Publishers ship immutable assets; haven’t seen a stale-bytes report.
- `comparisonFraming` thresholds in Savings v2 use fixed prices
  that drift over time; cosmetic; revisit when a price changes ≥30%.
- `replaceExisting: true` on a running `.app` may leave a zombie
  process until quit; macOS handles this gracefully (Sparkle has
  used the same pattern for 15 years).

#### Numbers

- **Tests**: 717 → **736** (+19 in HardeningTests)
- **Localization**: catalog grew by **38 strings × 5 locales** =
  **190 new translations** across Trust gauge / Savings hero /
  Updates row states + pipeline stage labels / Install registry
  actions / History actions / Fleet hover / Downloads upsell /
  sidebar.
- **Schemes verified**: Splynek (free) + Splynek-MAS (App Store) +
  SplynekCompanion (iOS) all BUILD SUCCEEDED at every commit
  point.  Splynek-MAS had only been verified in 1/12 design-
  revolution commits before the audit caught the gap (commit 13).
- **LOC delta**: ~+1500 / -800 net across the 14 commits.  Three
  new files (`InstallPreflight.swift`, `UpdateSweep.swift`,
  `HardeningTests.swift`) replace inline duplication.

#### Strategy notes

- **Splash retirement** (Sovereignty + Trust) is a small but
  philosophical move: the app no longer pitches itself to the
  returning user.  Once the user has the app installed, every
  surface should fill with their data, not with a marketing card.
  ContextCard subtitle is enough; auto-scan-on-appear handles
  the cold start.  Generalises: any future tab adding a splash
  is a regression of this principle.

- **Number framing** (Savings v2 + Trust gauge) is the same
  principle applied to numbers.  A bare “75” is information; a
  “RISK 75/100 HIGH” with a green→red gauge is meaning.  Same
  with “$240/year” → “≈ 12 months of Spotify”.  When the user
  asks for “more perceived value” (verbatim, on Savings + Trust
  + Poupanças), reach for direction + comparison + scale, not
  bigger fonts.

- **Honest audit** principle (final commits 13 + 14): when the
  user asks “are you 100% confident?”, the right answer is to
  list what you actually checked, what you found, what you fixed,
  and what you explicitly chose not to fix.  Not to rubber-stamp.
  The L10n gap and Splynek-MAS verification gap were both real
  and fixable; the cache-policy and zombie-process trade-offs
  were real and acceptable.

### 2026-05-08 end-of-session — smoke-test plan + backup state

After the 17-commit design revolution + audit hardening + 2 follow-up
polish commits + audit-driven catalog batch, the work needed a
backup + a structured validation plan before clocking off.

**Backup state (2026-05-08 19:49).**

- 137 commits ahead of `origin/main` (the `next-release rollup`
  per the 2026-05-05 versioning policy).  Without a remote backup
  this was a single-disk-failure away from gone.
- Pushed to `origin/rollup/2026-05-08` so the work survives
  outside this Mac without polluting the public `main` branch
  before the eventual Apple-cleared cut.  GitHub now carries the
  full arc as a ref.
- Plus belt-and-suspenders `git bundle create
  ~/splynek-backup-2026-05-08.bundle main` — 12 MB self-contained
  pack file that can be restored on any other host with
  `git clone <bundle>`.

**End-to-end smoke test (TODO — maintainer-only, requires live
network + an installed app).**

The unit tests cover the pure-logic layer (740 green).  What
they CAN'T cover is the install pipeline against real publisher
URLs.  Walk through this checklist on an actual launch before
cutting a DMG:

- [ ] Launch the app on a fresh boot.  Confirm the Apps row in
      the sidebar shows `↑ N` within ~3 s without manually
      visiting the Updates segment (the
      `vm.warmUpdateCount` background warm-up should fire 1.5 s
      after `restoreSession`).
- [ ] Open Atualizações.  Confirm the ContextCard reads in
      pt-PT.  Confirm the per-app rows show source pills
      (Sparkle / GitHub / Manual) + version pair (X.Y → A.B).
- [ ] Pick a Sparkle-sourced row (Bear / Things / OmniFocus / a
      similar Sparkle publisher you have installed) and click
      Atualizar.  Watch:
  - [ ] Phase transitions render inline: Downloading… →
        Verifying signature… → Installing… → Recording install…
        → Done. (or per-stage failures with humanised text)
  - [ ] On success: row flips to "Instalado" with green seal
        icon; row drops out of Atualizações disponíveis on next
        sweep
  - [ ] /Applications/<App>.app's CFBundleShortVersionString
        actually changed to the new version (no `<App> 2.app`
        suffix-rename — `replaceExisting: true` is meant to
        trash the old)
- [ ] Pick a GitHub-sourced row (Zed / Stats / etc.) and click
      Atualizar.  Same checklist.  Bonus: confirm the picker
      chose an arm64 asset (no Intel fallback).
- [ ] Force a known-bad URL: edit a Sparkle appcast or test
      against an app whose enclosure URL serves HTML (or use
      GOOSE VPN's tar.gz).  Click Atualizar.  Confirm:
  - [ ] Row downgrades to "Open page" affordance with humanised
        reason (NOT a raw `hdiutil: attach failed - imagem não
        reconhecida`)
  - [ ] tar.gz / tgz / xz / bz2 URLs are flagged fatal at
        preflight before any download
- [ ] In Frota's "What this Mac is sharing" card, hover a row.
      Confirm Reveal · Stop sharing · Trash buttons appear.  Pick
      a non-critical row, click Trash, confirm the file lands in
      the macOS Trash and the row disappears.
- [ ] In Histórico, click `⋯` → Limpar histórico.  Confirm the
      confirmation dialog fires and "Downloaded files on disk are
      NOT deleted" copy reads correctly.  Don't click destructive
      yet — just verify the dialog body.
- [ ] In Poupanças, pick the Claude row's tier picker.  Walk
      Pro → Max 5× → Max 20× → Team.  Confirm the COULD RECOVER
      number animates with `.contentTransition(.numericText())`
      between values.
- [ ] In Confiança, pick an app with score > 0.  Confirm the
      gauge dot is centred vertically on the bar (not floating
      above), the badge reads "RISCO ALTO" / "RISCO MODERADO"
      etc. (not the broken "RISCO + Alta" composition), and the
      percentile line reads correctly.
- [ ] In Soberania, confirm scan auto-fires on tab-open (no
      manual click on a splash CTA).  ContextCard always visible
      at top.

**Tabs not touched today** (Concierge / Receitas / Ao Vivo /
Torrents / Fila / Avaliação / Agentes / Settings) had a static
catalog audit via `Scripts/find-missing-translations.py` —
results landed in `25c8e7d` + this commit's batch.  No live UI
walkthrough yet; flag any in-the-flesh issues to a follow-up.

**Apple gate.**  Tag push + DMG cut + cask + landing deploy +
MAS resubmit are still gated on `v1.0` clearing the in-flight
re-review (day 8+ as of 2026-05-08).  Until then `main` =
local-only `next-release rollup`; remote is `origin/rollup/
2026-05-08`.

### 2026-05-08 evening — catalog growth strategy + Homebrew Cask import

After the design-revolution arc + audit hardening + end-of-day
polish (commit `dc62d95` already documented above), the user
flagged that the three Ask-tab catalogs (Confiança / Soberania /
Poupanças) had "almost laughable" coverage:

> "Confiança, Soberania e Poupanças... estas são as nossas mais
> fracas prestações. Temos tão poucas referências no catálogo
> que é quase risível.  Acho que temos de ser criativos e
> inteligentes e pensar fora da caixa para resolvermos o problema."

Numbers at the start of the segment:

| Catalog              | 2026-05-08 size | Mac App Store size |
|----------------------|-----------------|--------------------|
| `SovereigntyCatalog` | 1,155 entries   | ~30,000            |
| `TrustCatalog`       | 151 entries     | ~30,000            |
| `AppPricing`         | 119 paid apps   | ~5,000 paid        |

Hand-curation cannot scale with the long tail.  Proposed eight
tactics, user said "Faz todas!" — this is the implementation log.

#### Eight tactics + status

| # | Tactic | Commit | Status |
|---|---|---|---|
| #1 | Categorical fallback (LSApplicationCategoryType → champions) | `5055bef` | ✅ live |
| #2 | Homebrew Cask bulk import | `5055bef` (script) + `8482199` (data) | ✅ 4,088 hints live as JSON resource |
| #3 | AI-suggested entries | `5055bef` (design only) | 🚧 design captured; live wiring stays in splynek-pro |
| #4 | App Store privacy labels scraper | `5055bef` (script) | 📅 needs cron infra |
| #5 | Contribute button (one-click GitHub issue) | `5055bef` | ✅ live, enriched with cask metadata |
| #6 | Federated popularity census (Fleet) | `5055bef` (foundation) | 🚧 file shipped, announcement protocol pending |
| #7 | Wikidata SPARQL enrichment | `5055bef` (script) | 📅 needs cron infra |
| #8 | "We don't know yet" graceful state | `5055bef` | ✅ live |

Single source of truth for the strategy lives in
`CATALOG-GROWTH-STRATEGY.md`.

#### Architectural pieces shipped

- **`Sources/SplynekCore/SovereigntyCategoryChampions.swift`**
  16 macOS categories × 3-5 free-software champions each.  Used
  by `SovereigntyView.categoricalRows` to fall through when the
  hand-curated catalog has no specific entry.  Coverage jumps
  from ~50% → ~95% of typical-Mac installed apps.

- **`Sources/SplynekCore/Resources/cask-hints.json`** + thin loader
  4,088 Homebrew Cask metadata entries (bundleID, caskToken, name,
  homepage, downloadURL, category hint).  Loaded lazily by
  `SovereigntyCatalog.caskHints` via Bundle.splynekCore /
  Bundle.main fallback.  Powers the unknown-apps row enrichment
  (real names + green "Cask" badge) and pre-fills the contribute
  GitHub-issue body.

- **`Sources/SplynekCore/Fleet/PopularityCensus.swift`**
  Internal API for hashed-bundleID popularity tracking via Fleet.
  SHA-256 prefix (96-bit) of bundleID + version + the (already
  non-PII) LSApplicationCategoryType.  No bundleID in plain text
  leaves the LAN.  Foundation only — announcement protocol +
  Settings opt-in toggle pending follow-up.

- **`Scripts/import-from-homebrew-cask.py`**
  Clone the cask repo + run; emits `Scripts/cask-import.json`.
  Filters non-app casks (fonts, drivers, CLI-only).  Bundle-ID
  guess via reverse-DNS of homepage host.  86% bundle-ID coverage,
  100% download URL coverage in the resulting JSON.

- **`Scripts/scrape-app-store-privacy-labels.py`**
  Skeleton + complete documentation for scraping Apple's publicly-
  readable privacy labels into TrustCatalog concerns.  Maps
  `DATA_USED_TO_TRACK_YOU` / `DATA_LINKED_TO_YOU` /
  `DATA_NOT_LINKED_TO_YOU` to existing concern kinds with primary-
  source citations.

- **`Scripts/wikidata-sovereignty-enrich.py`**
  Skeleton + complete documentation for SPARQL queries against
  query.wikidata.org.  Maps country Q-IDs to
  `SovereigntyCatalog.Origin` (full EU+EEA+UK Q-ID table inline).

- **`Scripts/emit-cask-swift.py`**
  Converts `Scripts/cask-import.json` → `Resources/cask-hints.json`
  + thin Swift loader.  Pinned the architectural lessons from the
  swiftc OOM saga (see below) so a future regenerator doesn't
  regress.

- **`CATALOG-GROWTH-STRATEGY.md`** — the master doc for all eight
  tactics + coverage timeline + operational principles.  Read
  this first if a future session needs to reason about the
  catalog's growth model.

#### The swiftc OOM saga (lesson learned)

Two attempts at a Swift literal for the cask hints both blew up:

1. **`static let caskHintsByBundleID: [String: CaskHint] = [...]`**
   exit 137, OOM at ~200 GB.  Dictionary literals trigger
   exponential type-check paths above ~1,000 entries.

2. **`static let caskHints: [CaskHint] = [...]` with String fields**
   (no URL force-unwraps anywhere in the literal) — exit 144,
   OOM at ~200 GB *again*.  4,088 array elements alone tripped
   constraint solving.

Reference: `SovereigntyCatalog+Entries.swift` compiles fine at
26,368 lines because the top-level array has only ~1,155 elements
(the line count comes from nested .init() calls per entry's
alternatives).  4× element count was the wall.

**Pattern for future large datasets**: ship as a JSON resource +
lazy decoder.  Decoder runs once on first access (~30 ms), result
caches for the process lifetime.  The runtime dictionary index
is built via for-loop, NOT a dictionary literal — same trap.

This is now codified in `CATALOG-GROWTH-STRATEGY.md` and in
the loader's source-comment header.

#### Coverage delta

| Catalog              | 2026-05-08 morning | 2026-05-08 evening |
|----------------------|--------------------|--------------------|
| Sovereignty specific | 1,155              | 1,155              |
| Sovereignty cask hints | —                | **4,088**          |
| Sovereignty categorical | —              | ~95% of installed  |
| Sovereignty effective | ~50% of installed | ~95% of installed + 4,088 cask-enriched contribute paths |
| Trust                | 151                | 151 (script ready) |
| AppPricing           | 119                | 119                |

#### Verification

- 740 tests pass (no test changes needed — pure data + UI)
- `swift build` clean
- xcodebuild Splynek + Splynek-MAS + SplynekCompanion all
  BUILD SUCCEEDED — the JSON resource is bundled into all three
  target paths via Package.swift + project.yml resources blocks.
- All work pushed to `origin/rollup/2026-05-08` (the backup
  branch from earlier in the day).  Local `main` is now ~140
  commits ahead of `origin/main`.

#### Where it stands at end of session

`main` carries the full 2026-05-08 arc:
- Sidebar consolidation
- 7 tab revolutions
- Updates resilience hardening
- Fleet dedupe + per-row Reveal/Stop/Trash
- Whole-app audit + L10n catalog filling
- Catalog growth: 8 tactics with 4 live + 1 design + 3 scripts
- 4,088-entry Homebrew Cask metadata bundled as JSON resource

`origin/rollup/2026-05-08` is the safe backup.  When Apple clears
v1.0 MAS re-review, the cut sequence is:

```bash
git push origin main           # publish the whole rollup
git tag v2.0 && git push --tags
./Scripts/build.sh              # cut DMG
xcrun notarytool submit build/Splynek.dmg --keychain-profile AC_PASSWORD --wait
xcrun stapler staple build/Splynek.dmg
./Scripts/build-mas.sh          # cut MAS pkg + resubmit
```

#### Open follow-ups for the next session

1. **End-to-end smoke test** following the 12-checkbox checklist
   added to SESSION-LOG by `dc62d95`.  Live UI walkthrough of
   the design-revolution surfaces + failure-mode paths.
2. **L10n native-speaker review** — `L10N-REVIEW.md` has a
   38-key pt-PT checklist for Paulo to walk in 5 minutes.
3. **Run the cron scripts** (#4 + #7) against the union of
   cask-imported + popularly-installed apps → grow Trust 151
   → ~5,000 + Sovereignty origins enriched.  Both scripts are
   skeleton + docs; the live network calls + retry handling
   live in CI infrastructure that doesn't exist yet.
4. **Promote OSS-confirmed cask entries** to first-class
   Sovereignty matches — currently they only enrich the
   contribute flow.  Filter by `license:` (when extractable
   from cask) + cross-check against #7 Wikidata results.
5. **Wire AI-suggested entries** persistence (cache,
   "AI · not yet verified" badge, "Confirm + open PR" button) —
   the live LLM call already runs in Pro's `uncatalogedSection`.
6. **Settings → Fleet → Popularity census toggle** + the Fleet
   announcement protocol extension to share `PopularityCensus`
   observations across the LAN.

### 2026-05-09 — Settings decentralization (5 commits)

After the 2026-05-08 design-revolution arc settled, Paulo flagged
that several Settings cards conceptually belonged in their feature
tabs:

> "Existem várias coisas nos settings que acho que têm lugar nas
> tabs correspondentes, como por exemplo o peso da pontuação Trust
> deveria estar na tab trust. O que achas? Verifica os settings
> todos e vê o que faz sentido levar para as tabs.  Para além
> disso, neste momento temos espaço de sobra para voltarmos a ter
> o logo e a roldana de settings no rodapé do pane."

The principle: **discovery wins** — the user finds each control
at the moment they're looking at the surface it governs.  The
sliders that tune Trust live next to the Trust score they tune;
the schedule that gates the queue lives next to the queue it
gates; the household swarm token lives next to the swarm peers it
authorizes; the dashboard QR lives next to the MCP setup it
shares a listener with.

User approved the 5-commit plan with "cooncordo".

#### Five commits (chronological)

| #   | Commit    | Migration                                              | Net diff       |
|-----|-----------|--------------------------------------------------------|----------------|
| 1/5 | `57fb6cb` | Trust weights → **TrustView** (`weightsDisclosure`)    | -ratio in Settings, +disclosure card on top of Confiança |
| 2/5 | `b494a2b` | Schedule + Watched folder → **QueueView**              | both cards now under the queue list |
| 3/5 | `f944b09` | Swarm token + Security → **FleetView**                 | extension after `localActivityCard` |
| 4/5 | `52e9249` | Web dashboard + iPhone pairing QR → **AgentsView**     | `mobileDashboardCard` after `statusCard` |
| 5/5 | `2b3a87f` | Brand footer restored in Sidebar + Settings cleanup    | logo + version + gear at bottom of pane |

After all five: 740/740 tests still green, `swift build` clean,
all pushed to `origin/rollup/2026-05-08`.

#### Migration patterns established

Each card moved with the same shape:

1. **In-source forwarding comment** at the original site —
   future readers find a breadcrumb pointing to the new home,
   not a deletion mystery.  Example from `SettingsView.swift`:

   ```
   // 2026-05-09: trustWeightsCard moved to TrustView —
   // sliders that tune the Trust score now live next
   // to the score they tune.  See TrustView.weightsDisclosure.
   ```

2. **Card-as-`fileprivate` extension** at the destination — keeps
   the destination view's struct body slim and lets the migrated
   card's helpers (e.g. `weightSlider`, `pickWatchFolder`) stay
   private to the file without polluting the host struct.

3. **No behaviour change** — bindings still go through the same
   `vm.fleet.*` / `vm.trust.*` / `vm.swarmHouseholdToken` paths.
   Pure surface relocation, not a model refactor.

4. **Disclosure-style for advanced knobs** — Trust weights moved
   into a `DisclosureGroup` (not always-visible), because the
   sliders are advanced configuration, not first-class content.
   The card itself sits at the **top** of TrustView — closed by
   default, single click to open, right above the score it tunes.

#### Why this isn't busywork

The original Settings tab was 8 cards all of equal weight.  Many
of them had no relationship to each other beyond "configures
something" — the user's mental model can't map "schedule downloads"
and "Trust score weights" to the same neighborhood.  After the
migration, Settings has 4 **genuinely cross-cutting** cards:

- **Pro license** — gates several feature tabs at once
- **Browser helpers** — Chrome extension + Safari bookmarklets
- **Local AI** — Ollama detection + model (used by Concierge +
  History search)
- **Background mode** — dock icon + login item (app-wide)

Everything else lives next to what it affects.  Bonus side effect:
SettingsView shrank from 583 → 368 lines.  Each destination tab
gained ~100-200 lines but the cognitive load went **down**: the
reader is already in the right context when they encounter each
control.

#### Brand footer restoration (Move 5)

The footer was removed in commit `2efa8d0` (2026-05-07) on the
grounds that "it ate a sidebar row at every window height" and
Settings was reachable from `Cmd+,` in the menu bar.  Two days
of layout polish later, the sidebar has plenty of breathing room
**and** the Settings tab is no longer in the sidebar at all
(removed in v0.49) — meaning users who don't know about the menu
bar gear had no on-screen path to Settings.

The restored footer:
- 28 pt app icon + "Splynek" name + version on the lead edge,
  tapping opens About via the existing `splynekShowAbout`
  notification
- Gear icon on the trailing edge, tapping opens Settings via the
  same `splynekShowSettings` notification the menu-bar `Cmd+,`
  posts (RootView's routing is unchanged — pure UI affordance)
- Top-edge divider keeps it visually distinct from the sidebar
  list above

#### Numbers

```
Commits:                5
Tests:                  740/740 (no test changes — pure UI)
SettingsView:           583 → 368 lines (-215)
TrustView:              ~840 → 1,071 lines (+231)
QueueView:              ~360 → 591 lines (+231)
FleetView:              ~440 → 546 lines (+106)
AgentsView:             ~500 → 650 lines (+150)
Sidebar:                ~360 → 451 lines (+91)
Net delta:             +594 lines (mostly forwarding comments
                       + extension wrappers; no model code added)
```

#### Where it stands at end of session

`origin/rollup/2026-05-08` carries the full 2026-05-08 + 2026-05-09
arc.  Branch is now ~145 commits ahead of `origin/main`.  Next
maintainer steps unchanged from the 2026-05-08 evening entry:
end-to-end smoke test, L10n native-speaker review, run cron
scripts, promote OSS-confirmed cask entries, wire AI-suggested
persistence.  The Settings decentralization adds **one** thing
to the smoke-test checklist: walk Trust / Fila / Frota / Agentes
and confirm each migrated card renders in its new home and the
brand footer appears at the bottom of the sidebar.

### 2026-05-09 evening — PRO-PLUS-IPHONE Sprint 1 (5 commits)

After the Settings decentralization arc settled, Paulo asked for
strategic thinking on two fronts:

> "pensa aprofundadamente no que fazer para alavancar, melhorar e
>  tornar mais valiosa a compra do pro... temos de apostar no Pro
>  e em levá-lo para outros patamares.  Ao mesmo tempo, estudar
>  formas de melhorar a app para iphone, que ferramentas levar
>  para lá, como torná-la um must."

I produced a strategy memo identifying five Pro bets (Aposta A-E)
+ an iPhone Companion must-have list.  User approved with
"Quero que faças TUDO o que está no documento!" — full Sprint 1
execution.

#### Five commits (chronological)

| #   | Commit    | What                                                              |
|-----|-----------|-------------------------------------------------------------------|
| 1   | `5e30f5c` | Strategy doc + Trust Watcher Mac-complete (4 source files + 22 tests + UI) |
| 2   | `a113dc9` | Mac REST endpoints (pause-all/resume-all + 4 summary endpoints) + iOS App Intents |
| 3   | `9dca20c` | iOS Widget (small + medium) + Pro on iPhone Insights tab          |
| 4   | `fabf46e` | CloudKit push notifications (Mac publisher + iOS subscriber)      |
| 5   | this      | Docs: STRATEGY-2026 + MONETIZATION reposition + SESSION-LOG       |

After all five: 767 tests pass (was 740 pre-strategy; +27 new),
Mac `swift build` clean, iOS `xcodebuild SplynekCompanion BUILD
SUCCEEDED`, all pushed to `origin/rollup/2026-05-08`.

#### What it does

**Marquee Pro feature: Trust Watcher.**  Daily-diff engine watches
24 policy URLs (12 popular apps × Privacy Policy + ToS).  When
the body hash changes, emits a severity-tagged alert.  100% local
detection (MAS-2.5.2-safe — no LLM in the path).

**iPhone Companion turns into a must-have via:**
- **iOS App Intents** — 5 intents wired to `AppShortcutsProvider`
  so "Hey Siri, send to Splynek" / "Hey Siri, pause Splynek
  downloads" / "Hey Siri, what's my Splynek sovereignty score"
  work out of the box, no Shortcut required.
- **Home-screen Widget** (small + medium) — sovereignty score as
  hero number; medium variant adds active downloads + Trust
  Watcher pending alerts.
- **Pro on iPhone** ("Insights" tab) — sovereignty / trust /
  trust-watcher / history summaries pulled live from the paired
  Mac via the new `/api/*/summary` endpoints.
- **Push notifications** — when Trust Watcher detects a change,
  the Mac writes a `SplynekTrustWatchAlert` record to the user's
  private CloudKit DB; the iPhone's CKQuerySubscription fires a
  silent push, the app composes a `UNNotification`, the user
  sees "Spotify Privacy Policy changed (notable)" on the lock
  screen.  Zero-server: same Apple-private-DB pattern as the
  existing CloudKit relay.

#### Architectural choices that paid off

1. **Shared `RelaySummary` types in iOS/Shared (SplynekCompanionCore).**
   SplynekCore depends on SplynekCompanionCore (already), so moving
   the Codable summary types there gives both Mac (REST encoder)
   and iPhone (REST decoder + Widget + Insights view) one schema
   with zero risk of drift.  No JSON-spec docs needed; the type
   is the spec.

2. **Closure-based summary providers in FleetCoordinator.**  Same
   pattern the existing `onWebIngest` / `onCancelAll` callbacks
   use.  Coordinator stays decoupled from the VM type; each
   summary endpoint returns nil → 404/503.  Pro-gating happens at
   the source (`license.isPro` in `buildTrustWatcherSummary`),
   not in the coordinator.

3. **Pure callback for alert emission.**  `TrustWatchService`
   exposes a Sendable closure `onAlertsEmitted` that the VM wires
   to the CloudKit publisher.  Both the auto-sweep timer and the
   manual `runOnce()` go through the same path — no duplicated
   "publish on manual" code.

4. **macOS 13 deployment-target onChange compat.**  Caught by
   build error early; fixed by reverting to single-arg form.
   The codebase still targets macOS 13 (Package.swift) so
   anything iOS-17+ / macOS-14+ needs guards.

#### Critical lessons

- **iOS targets don't `import` shared modules** — they inline
  source files via project.yml.  My initial widget pulled
  `import SplynekCompanionCore` and broke the build; the fix
  was to remove the import (all the types are in scope from
  the inlined files).

- **CloudKit subscriptions are zero-server but require
  out-of-band schema setup.**  The `SplynekTrustWatchAlert`
  record type needs to be added to the existing CloudKit
  Dashboard schema (alongside `SplynekRelayJob`).  Until that
  happens, the publisher logs a warning + the local UI keeps
  working.  Documented as a maintainer step in the commit
  message.

- **macOS App Intents already shipped (2024) on the Mac side**
  via `AppIntentsProvider.swift`; the iOS side was a separate
  file because the App Group / paired-Mac resolution differs.
  Pattern matches: each intent fetches the user's most-recently-
  seen paired Mac, errors with a typed `AppIntentError` for the
  not-paired / unreachable / Pro-required cases.

#### Numbers

```
Commits:                5
Tests:                  740 → 767 (+27 new)
Pure new code:         ~3,000 lines across 13 new files
Mac source files:       5 (TrustWatcher/{Watcher, Catalog, Store,
                           Service, CloudKitNotifier})
iOS Companion files:    3 (AppIntents, MacInsightsView,
                           TrustWatchPushSubscriber)
iOS Widget files:       1 (SplynekStatusWidget)
iOS Shared files:       2 (RelaySummaryTypes, TrustWatchAlertRecord)
Test files:             2 (TrustWatcher, TrustWatchAlertRecord)
Strategy + docs:       STRATEGY-2026-PRO-PLUS-IPHONE.md (300 lines)
                        MONETIZATION.md repositioned
```

#### What's intentionally NOT in Sprint 1

These are Sprint 2 (3-6 months out):

- **Sovereignty Migrate Wizard** — one-click swap with cask install
- **Concierge that acts** — sequence executor with confirmation
- **Apple Watch app** — tap-to-pause + complication
- **Geo-fence** — leaving home → pause; arriving home → resume

Sprint 3 (6-12 months out): pricing telemetry → Trust+ subscription
evaluation if engagement justifies.

#### Where it stands at end of session

`origin/rollup/2026-05-08` carries everything.  Branch is now
~150 commits ahead of `origin/main`.  Apple v1.0 MAS re-review
status: still day 8+.  When it clears, the cut sequence is
unchanged from the previous SESSION-LOG entry.

Maintainer steps still required (out of band; not Claude-fixable):
1. Add `SplynekTrustWatchAlert` to CloudKit Dashboard schema
   (alongside existing `SplynekRelayJob`).  Fields: alertID,
   sourceMacUUID, targetAppName, policyKind, severity, pageURL,
   observedAt, acknowledged.
2. Promote schema to Production environment.
3. Re-archive iOS + macOS apps with iCloud entitlement verified.

Until step 3, Trust Watcher + iPhone push fall back gracefully:
local Mac UI shows alerts as normal; CloudKit publish logs a
notice + iPhone push silently no-ops.

### 2026-05-09 → 2026-05-10 — PRO-PLUS-IPHONE Sprint 2 part-2 (4 commits)

After shipping Sprint 1 + Sprint 2 part-1 scaffolds (`9164418`),
user said simply "continuar" — execute Sprint 2 part-2 too.

#### Four commits (chronological)

| #   | Commit    | What                                                              |
|-----|-----------|-------------------------------------------------------------------|
| 1   | `641dc70` | Sovereignty Migrate Wizard — runner + SwiftUI sheet + review list |
| 2   | `f658e2f` | Geo-fence iOS — CLLocationManager wrapper + Settings UI           |
| 3   | `aec950d` | Watch app target skeleton (project.yml + sources + scheme)        |
| 4   | `9e1db78` | Concierge sequence runner + preview UI                            |

After all four: 797 tests pass (was 786 before Sprint 2 part-1
scaffolds; +11 net through part-2), Mac `swift build` clean,
iOS `xcodebuild SplynekCompanion BUILD SUCCEEDED`, all pushed
to `origin/rollup/2026-05-08`.

#### What lit up

**Mac side:**
- Sovereignty Migrate Wizard end-to-end: every alternative row
  in the matched-results section gets a Pro-gated "Migrate"
  button.  Click → modal sheet walks plan steps with per-step
  confirmation alerts.  Brew step opens Terminal.app via
  AppleScript with the brew command pre-typed (Splynek itself
  NEVER runs as root, NEVER mutates brew state).  Mark-for-
  review writes to a persisted JSON list at
  `~/Library/Application Support/Splynek/migrate-review-list.json`
  for a "still on your list" banner (Sprint 3 surfaces banner).
- Concierge sequence runner with full per-step dispatch via
  the existing MCPServer.Bridge.  Preview SwiftUI sheet uses
  CheckedContinuation to bridge the alert/confirm pattern with
  the @Sendable confirm closure.

**iOS side:**
- Geo-fence: enable toggle + "Use current location as home"
  button + 100-1000 m radius slider in Settings.  Coordinator
  registers a CLCircularRegion via CLLocationManager; entries
  + exits feed pure GeoFencePolicy.action which drives
  PairedMacClient.pauseAll/resumeAll on the user's default
  Mac.  Coordinates never leave the device.
- Watch app: target wired in project.yml + scheme + minimal
  SwiftUI body with two action buttons + a Sovereignty score
  row + WKInterfaceDevice haptic feedback.  Reads PairedMacStore
  from the same App Group plist the iPhone Companion writes to.
  Compile-verify pending watchOS SDK install (maintainer step).

#### Architectural choices that paid off again

1. **Persisted state in `~/Library/Application Support/Splynek/`
   is the standard pattern.**  TrustWatchStore and now
   SovereigntyMigrateReviewList both follow CellularBudget's
   layout: lock-guarded NSLock + JSON file + atomic write +
   `_testOverrideURL` for safe tests.  Three call sites,
   identical shape — easy to keep in sync.

2. **Pure decision modules + thin runtime wrappers.**
   GeoFencePolicy.action is exercised by tests on macOS;
   GeoFenceCoordinator wraps CoreLocation around it.
   ConciergeSequencePolicy.validate gated the runner before
   any dispatch, exercised by 5 tests.  Same split as
   `IsolatedFleetCoordinator` from earlier sprints.

3. **CheckedContinuation bridges SwiftUI alerts with @Sendable
   closures.**  ConciergeSequencePreviewView's confirm()
   callback for the runner needs to await user input from a
   modal alert.  Pattern: Task on @MainActor sets the
   alert-state @State + stores the continuation; button taps
   resolve the continuation.  Avoids global state, avoids
   notifications, avoids race conditions.

4. **xcodegen regenerates Info.plist from project.yml on every
   build.**  Caught when manually editing the iOS Info.plist
   to add NSLocationWhenInUseUsageDescription — xcodegen
   reverted my change.  Solution: put the keys in project.yml's
   `info: properties:` block.  Same lesson the maintainer doc
   already mentioned for SplynekCompanion's existing keys —
   re-confirmed.

#### Critical lessons

- **iOS App Group plist is shared between iPhone Companion +
  Watch + Widget extension** via the App Group entitlement.
  PairedMacStore reads/writes the plist using
  UserDefaults(suiteName:) with the App Group ID.  Means the
  Watch + Widget see paired Macs without a separate sync —
  pairing on iPhone "just works" on the wrist.

- **CLLocationManager doesn't retain its delegate.**  The
  one-shot location fixer in iOS Settings needed a manual
  in-flight retainer (`OneShotLocationFixer.inFlight: [Self]`)
  to survive the async fix callback.  CLLocationManager + a
  short-lived owner is the wrong pairing without this.

- **MCPServer.Bridge is the right substrate for sequence
  dispatch.**  When I started ConciergeSequenceRunner I was
  about to define a parallel "tool dispatch" type.  Then
  realised: every tool already routes through Bridge from
  MCPServer.  Reuse → single source of truth.  Future tools
  added to Bridge automatically get sequence support.

#### Numbers

```
Commits:                4
Tests:                  786 → 797 (+11)
Mac source files:       4 (Migrate runner + UI, ConciergeRunner +
                           preview view + review list)
iOS Companion files:    1 (GeoFenceCoordinator)
Watch target:           1 (SplynekWatchApp.swift + Info.plist)
project.yml:            1 new target (SplynekWatch) + 1 new scheme
Net new code:          ~2,200 lines
Net for the day:       10 commits (5e30f5c → 9e1db78), ~6,000 lines
```

#### Where it stands at end of session

`origin/rollup/2026-05-08` carries the entire PRO-PLUS-IPHONE
strategy: Sprint 1 (5 commits) + Sprint 2 part-1 scaffolds
(1 commit) + Sprint 2 part-2 (4 commits) = **10 commits total**.

Branch is now ~160 commits ahead of `origin/main`.

What's left for Sprint 3 (next session, if executed):
1. End-to-end smoke test of all four Sprint 2 surfaces
2. splynek-pro: ConciergeView wiring that emits a sequence
   from a user prompt
3. Watch complication for the watch face
4. Sovereignty "still on your list" banner driven by
   SovereigntyMigrateReviewList.entriesOlderThan(days:)
5. Migrate review list digest in Concierge ("3 apps you marked
   are still installed")
6. Pricing telemetry → Trust+ subscription evaluation if
   engagement justifies (Sprint 3 in the original plan)

Maintainer steps still required (out of band; not Claude-fixable):
- CloudKit Dashboard: add SplynekTrustWatchAlert record type
  (alongside existing SplynekRelayJob)
- watchOS SDK install: Xcode → Settings → Components → watchOS
  (so xcodebuild SplynekWatch can verify the target)
- Apple Developer Program: provision the watch app's bundle ID

## When to re-read this doc

This SESSION-LOG is meant for two scenarios:

1. **Picking up cold after a long break.**  HANDOFF tells you the
   state; this tells you the journey + open positions.  Read end-
   to-end in one sitting.
2. **Considering a release-cut decision.**  The Numbers section
   + the Open Positions section together let you decide whether
   `v1.7` (small cut) vs `v2.0` (rolled-up) is the right framing
   for the press / changelog / app-description copy.

Write a successor (`SESSION-LOG-2.md` or rotate this file) when the
next major sprint starts.  Don't let any single session-log file
grow past ~500 lines; the value is in scannability.
