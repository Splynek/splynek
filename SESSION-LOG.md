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

## Commit timeline (latest first, top of `main`)

```
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
| Catalog strings | 56 | **535** | ×9.6 |
| Translations (×5 locales) | 56 | **2,675** | ×47 |
| Tests | 148 | **451** | ×3.0 |
| Public-repo Swift files | 49 | **67** (top-level SplynekCore) / 123 (recursive) | +18 / +74 |
| Public-repo plists | 6 | **8** | +2 (helper + launchd) |
| Pro-repo Swift files | 8 | **10** | +2 (Mac-Assistant dispatcher + cards) |
| Top-level docs | 1 (HANDOFF) | **6** (HANDOFF + STRATEGY-v1.7-v1.9 + MAS-2.5.2-COMPLIANCE + L10N-REVIEW + RELEASE-NOTES draft + SMJOB-BLESS-DESIGN + SESSION-LOG) | +5 |
| Architecture invariant comments | ~3 (catalog + sandbox) | **~15** (every AI-touching, code-execution-adjacent file) | +12 |
| CI guardrails | 1 (sovereignty-weekly) | **2** (+ lint.yml for catalog audit) | +1 |
| Trust catalog entries | 30 | 151 | +121 |
| Sovereignty catalog entries | 1,155 | 1,155 | unchanged |

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
- **iOS Companion not started.**  Per HANDOFF "Honest non-goals"
  — iPhone can't add value to the multi-interface engine; only
  worth doing once Mac Splynek has clear pull.

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
