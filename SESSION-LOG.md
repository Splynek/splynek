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
Tests grew **148 → 340** (×2.3).  Public-repo Swift files **49 → 67**.
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
| Tests | 148 | **340** | ×2.3 |
| Public-repo Swift files | 49 | **67** | +18 |
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
