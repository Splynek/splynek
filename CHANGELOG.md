# Splynek changelog

A condensed one-line-per-release log. For details, see the relevant
`## What's new in v0.N` section in [README.md](README.md).

## v3.0.0 — Direct ship: IA v2 + Trust Watcher + bonded download (2026-06-08)

**The biggest Splynek ever — and the first shipped direct, outside
the Mac App Store.**  Apple's MAS re-review queue crossed 30+ days
with no human reply; the product was finished, so v3.0.0 ships from
splynek.app via notarized DMG + Sparkle auto-update + LemonSqueezy
for Pro.  MAS becomes a parallel channel when Apple clears.  See
LAUNCH-WITHOUT-APPLE.md.

### Information architecture v2
- 17-tab sidebar collapsed to 4 lifecycle tabs (Discover / Download /
  My Apps / Coordinate) with rich colored tile buttons + per-tab chip
  strip.
- Floating-card sidebar chrome with traffic-lights visually inside
  the pane (the Apple TV.app look).
- First-run welcome card with 4 colored story tiles.
- Concierge as a sheet ("Ask Splynek" pill); Settings/Legal/About as
  a gear-sheet.
- Installed inventory + Trust Watcher inbox under My Apps.

### Direct-sale infrastructure
- Ed25519-signed `.splynekkey` licence files; offline verification,
  no account, no phone-home.
- Sparkle 2.x auto-update from splynek.app/appcast.xml.
- Cloudflare Worker: LemonSqueezy webhook → signed-licence email.
- "Check for Updates…" menu command.

### Carried from the 2026 Bets rollup
- Unbreakable Resume, yt-dlp swallow, Browser Accelerator, File
  Witness signed receipts, Fleet 2.0.

### L10n
- 220 new translations across pt-PT / es / fr / de / it; catalog at
  948 strings × 5 locales, 100% coverage.

### Pricing
- $24 launch-week (first 30 days) / $29 lifetime.  One-time, no
  subscription.

## v2.0.1 — Launchable DMG + Watch polish + paste-to-pair (2026-05-13)

**v2.0.0 was unlaunchable. This is the fix.**

### Release-blocking fix

The v2.0.0 Developer-ID DMG signed against an entitlements file
that declared `com.apple.security.app-sandbox = true` alongside
iCloud container access — a combination that requires an
`application-identifier` entitlement, which only ships through a
provisioning profile (the MAS distribution path).  Developer-ID
signing doesn't include a profile, so Launchd refused to spawn
the binary with `RBSRequestErrorDomain Code=5 / POSIX 163` on
every fresh user machine.  Notarisation passed because signatures
were valid; runtime sandbox init failed.

`Resources/Splynek.entitlements` now drops iCloud entitlements
from the DMG variant (CloudKit over-cellular relay is gated behind
`#if MAS_BUILD` and was never exercised from the DMG variant
anyway) and adds the missing `com.apple.security.network.server`
entitlement for the LAN HTTP API + Bonjour listener.

Test-launch is now a permanent step in the release runbook.

### iOS Companion (paired-Mac UX)

- **Paste-to-pair**: a SwiftUI `PasteButton` in the pairing sheet
  consumes the Mac's "Copy pair URL" output in a single tap.  No
  IP, no port, no token typing.
- **`splynek://pair?…` deep links**: tap the same URL from
  Messages, Mail, Notes, Universal Clipboard, or AirDrop, iOS
  shows its standard "Abrir com Splynek?" gate, tap Abrir, paired.
- **Tap-discovered-Mac actually prefills the form**: Bonjour
  list entries previously wrote a UserDefaults hint that the
  pairing sheet never read — fixed so the form opens with name,
  host, and port populated; only the token remains.

### Apple Watch

- **Splynek logo on the home screen**: scaffolded the watchOS 10+
  asset catalog so the installed Watch app shows the Splynek icon,
  not the blank placeholder.
- **WKCompanionAppBundleIdentifier declared**: lets the Watch app
  install on simulator + paired hardware (previously rejected with
  MIInstallerErrorDomain code 97 / InvalidCompanionAppBundleIdentifier).
- **WatchConnectivity wired end-to-end**: the iPhone Companion
  now pushes the paired-Mac snapshot to the Watch via
  `WCSession.updateApplicationContext`, so the Watch's
  PairedMacStore actually populates.  Without this the Watch
  showed "No Mac paired" even on a paired physical Watch — App
  Group containers are not auto-synced across iPhone ↔ Watch.

### Mac + build

- **App Intents metadata extraction now works under the Xcode
  build path**.  Three Sprint 1 source files had unguarded
  `import SplynekCompanionCore`; Xcode's `appintentsmetadataprocessor`
  silently skipped the metadata step.  Imports are now gated on
  `#if SWIFT_PACKAGE` + shared types are added to the Xcode
  Splynek + Splynek-MAS target sources so Shortcuts.app sees the
  five Mac App Intents in DMG builds.
- **Bonjour TXT-record `ver` is dynamic**: was hardcoded to
  "0.19", now reads `SplynekVersion.current`.
- **iOS Companion L10n round 5**: 23 strings × 5 locales = 115
  new translations.  Catalog now at zero audit gaps across 5
  locales for both Mac (841 strings) AND iOS Companion.

## v2.0.0 — PRO-PLUS-IPHONE strategic arc (2026-05-10)

Eight-sprint arc that pivots the Pro tier marquee from "AI Concierge"
to **Trust Watcher** + **Pro on iPhone**, ships three external
API-token clients (Raycast / CLI / Alfred), and live-validates the
whole surface on a Mac DMG dev build + iPhone 17 Pro simulator.

### Marquee Pro features

- **Trust Watcher** — daily-diff engine for Privacy Policies + Terms
  of Service of installed apps.  When a vendor materially changes a
  document, an alert lands on your Mac and a push notification on
  your iPhone.  100% local detection (SHA-256 hashing of public
  policy pages; no LLM in the diff path; aligns with MAS-2.5.2).
  Seeded with 12 popular apps × 2 URLs (Spotify, Netflix, Slack,
  Discord, Zoom, Adobe, Notion, Dropbox, Chrome, Firefox, ChatGPT,
  Claude); catalog grows via PR.
- **Sovereignty Migrate Wizard** — guided one-click swap from a
  paid US-controlled app to a European or open-source alternative.
  Per-step confirmation; nothing destroyed; original app stays
  installed unless you uninstall it manually.  Plus a "still on
  your migration list" banner in Sovereignty + a Concierge tool
  (`migrate_review_digest`) for natural-language queries.
- **API tokens for power users** — mint persistent named tokens
  for Raycast, Alfred, BetterTouchTool, shell scripts.  Two scopes
  (read-only / read+write); revoke any time.  Three external
  client scaffolds shipped:
  - `Extensions/Raycast/splynek/` — 5 Raycast commands
  - `Extensions/CLI/splynek` — bash wrapper + curl/jq cookbook
  - `Extensions/Alfred/splynek/` — Alfred workflow scaffold
- **Engagement viewer** — privacy through transparency.  Settings
  card surfaces every counter the engagement store records; the
  user reads the same JSON the future Trust+ subscription gate
  reads.  No telemetry leaves the device.

### Pro on iPhone

- **Insights tab** — fourth tab on the iPhone Companion.  Live
  Sovereignty / Trust / Trust Watcher / Recent Downloads cards
  fetched from the paired Mac via token-gated relay endpoints.
- **App Intents (Hey Siri)** — five intents wired through
  `AppShortcutsProvider`: Send URL to Splynek / Pause All Splynek
  Downloads / Resume All / Active Splynek Downloads / Splynek
  Sovereignty Score.
- **Home-screen Widget** — small + medium families with traffic-
  light Sovereignty score.  30-min refresh budget.
- **Geo-fence** — Settings toggle + "Use current location as home"
  + radius slider (100-1000 m).  CLLocationManager monitors a
  single CLCircularRegion; entries / exits drive PairedMacClient
  pause-all / resume-all.  Coordinates never leave the device.
- **CloudKit push notifications** — Trust Watcher alerts published
  to the user's private CloudKit DB; iPhone CKQuerySubscription
  fires a UNNotification with severity-aware body.

### Apple Watch

- App with two action buttons (Pause All / Resume All) + Sovereignty
  score row + WKInterfaceDevice haptic feedback.  Reads paired Mac
  from the App Group plist (no separate Watch pairing).
- Three watch-face complication families (`accessoryCircular`
  Gauge with traffic-light tint, `accessoryRectangular` two-line,
  inline one-line).

### Concierge sequences

- `ConciergeSequence` Codable type + `ConciergeSequenceRunner` actor
  wrapping `MCPServer.Bridge` (single dispatch source-of-truth).
  Per-step user confirmation for every mutating step.  Halt on
  first decline OR first failure.

### Settings decentralization

- 6 cards moved out of Settings into their feature tabs (Trust
  weights → Confiança, Schedule + Watched folder → Fila, Swarm
  token + Security → Frota, Web dashboard + iPhone pairing QR →
  Agentes).  Settings now holds only the four genuinely
  cross-cutting cards (Pro license, browser helpers, local AI,
  background mode).  Brand footer restored at the bottom of the
  sidebar with About + Settings buttons.

### L10n catalog reaches zero gap

- Mac `Localizable.xcstrings`: 740 → **841 strings × 5 locales =
  4,205 translations**.  Audit script reports **0 missing** for
  the first time in the codebase's history.
- iOS Companion `Localizable.xcstrings`: +37 strings auto-extracted
  by Xcode during the smoke build; English-only as committed.
  v2.0.1 candidate for translation pass.

### Architectural patterns

- **5 pure decision modules**: APITokenValidator, EngagementGate,
  GeoFencePolicy, ConciergeSequencePolicy, TrustWatcher.diff.
- **5 persisted JSON stores** following the same lock-guarded
  pattern (CellularBudget + TrustWatchStore + Sovereignty­Migrate­
  Review­List + EngagementStore + APITokenStoreFile).
- **3 documentation artifacts** for v2.0+ release flow:
  STRATEGY-2026-PRO-PLUS-IPHONE.md, SMOKE-TEST-RUNBOOK.md,
  LANDING-V2-DRAFT.md.

### Numbers

- 39 commits in the PRO-PLUS-IPHONE arc (Sprints 1-8)
- 740 → **820 tests** (+80)
- ~12,500 lines of new code across ~60 files
- ~500 new translations

### Maintainer post-tag steps

- `xcrun notarytool submit build/Splynek.dmg --keychain-profile
  AC_PASSWORD --wait` + `xcrun stapler staple build/Splynek.dmg`
- `./Scripts/build-mas.sh` → MAS pkg + Application Loader upload
- Refresh `Packaging/splynek.rb` cask with new SHA-256 + version
- Adapt `LANDING-V2-DRAFT.md` into the splynek-landing repo
- Show HN + Product Hunt + Mac-app blogger emails per the
  press kit in LANDING-V2-DRAFT.md
- CloudKit Dashboard: provision `SplynekTrustWatchAlert` schema
  to Production
- v2.0.1 follow-up: iOS Companion L10n round 5; Bonjour TXT-
  record version string fix; Concierge / Recipes UI verification
  via MAS build; physical-iPhone push test.

## v1.6.2 — validation pass + build-pipeline fixes (2026-04-30)

End-to-end validation of v1.6 surfaces via computer-use surfaced
three real bugs along the way; all fixed.

**Localization gaps fixed across the rest of the UI**:

- `TitledCard.title` was `String` (verbatim) — every card title
  ("Source", "Options", "Trust score weights", "MCP server", etc.)
  bypassed localization.  Type changed to `LocalizedStringKey`;
  string-literal call sites auto-coerce.  Two dynamic-String
  callers (LegalView, ProLockedView) explicitly wrap their
  Strings in `LocalizedStringKey(...)`.
- `DownloadView.windowTitle` was `String` returned to
  `.navigationTitle(_:)` (verbatim overload) — pane title stuck
  in English even when the rest of the UI rendered in pt-PT.
  Type changed to `LocalizedStringKey`.
- `labelWithInfo(_:tooltip:)` Text rendered the label String
  verbatim — "Speed per network" / "Downloads at once" stayed
  English on translated locales.  Now wraps in
  `LocalizedStringKey(text)`.
- 12 new strings added to the catalog: tab pane titles
  (Downloads / Torrents / Live / Concierge / Recipes / Queue /
  Fleet / Benchmark / History — translated across all 5 locales,
  Concierge + Torrents kept identical to English as international
  proper nouns), card titles, common buttons (Save / Done / Open /
  Close), pane subtitles ("Paste a URL...").
- Catalog: 127 → 139 strings × 5 locales = 695 translations.

**App Intents metadata for SPM-built DMG**:

- `swift build` doesn't run `appintentsmetadataprocessor`, so the
  SPM-built .app shipped without `Metadata.appintents` —
  Shortcuts.app and Siri couldn't discover Splynek's 10 Intents.
  Verified against `pluginkit -m -A | grep splynek` (empty) and
  `nm` (all 10 Intent symbols present in binary).
- `Scripts/build.sh` now opt-in-runs an Xcode build of the
  Splynek scheme (NOT the MAS scheme — no Pro deps needed) into
  scratch DerivedData, copies the generated Metadata.appintents
  into the SPM .app's Resources/.  Adds ~60 s; opt out with
  `SKIP_APP_INTENTS=1`.
- Hit a real bug along the way: `LookupSovereigntyIntent` and
  `LookupTrustIntent` had AppShortcut phrases interpolating
  `\(\.$query)` — the metadata extractor only allows AppEntity
  / AppEnum interpolations, not String.  Phrases simplified to
  static text; the user types the query in the Shortcuts editor.

**Spotlight indexing**:

- `mdfind` was returning empty for the Splynek catalog domains
  even after a clean app launch — initially looked like a
  regression.  Investigation: `mdfind` queries the filesystem
  metadata index (`.pdf`, etc.), while `CSSearchableIndex` writes
  to a SEPARATE app-provided-items index queryable via Cmd+Space
  Spotlight UI or `CSSearchQuery`.  Two different indexes.
- Verified working via the new explicit logging:
  `Spotlight reindex done: 1215 items indexed`
  (1155 Sovereignty + 60 Trust).
- `SplynekSpotlight.reindexCatalog` now logs success/failure via
  `Log.scan` so future false alarms are diagnosable in
  `log show --predicate 'subsystem == "app.splynek"'`.

**MCP smoke test (Scripts/validate-mcp.sh)**:

- The `call()` function leaked display output onto stdout,
  breaking jq parsing in callers ("▸ desc\n{pretty}\n\n{raw}"
  instead of just `{raw}`).  Display output now goes to stderr;
  stdout is the raw JSON only.  All 4 smoke tests pass against
  the live endpoint.

**Build pipeline (Scripts/build.sh)**:

- Compiles `Localizable.xcstrings` → per-locale
  `Localizable.strings` files via the new
  `Scripts/compile-xcstrings.py` (SwiftPM ships the raw catalog;
  Foundation reads only compiled .strings).
- Mirrors the compiled .lproj/ directories from the SwiftPM
  resource bundle up to the .app's main `Contents/Resources/` —
  SwiftUI's `Text("foo")` resolves through `Bundle.main`, not
  `Bundle.module`.
- Accepts positional `debug`/`release` arg in addition to env var.

Tests: 166/166 pass.  Catalog: 139 strings × 5 locales.  App
builds clean to v1.6.2 .app with localizations + App Intents
metadata + os.Logger output for Spotlight reindex.

## v1.6.1 — onboarding, human-language sweep, ASC monitor, localization (2026-04-30)

**First-launch onboarding** (`Sources/SplynekCore/Views/OnboardingSheet.swift`):
3-step sheet — Welcome / Output folder / Optional audit — gated by
the new `vm.hasCompletedOnboarding` UserDefaults flag.  Sets the
"this is for everyone" tone at the entry point instead of dumping
users straight onto the Source URL field.  Skippable at every step.

**MCP promoted to its own tab** (`Agents` in a new `Connect` sidebar
group).  `AgentsView` carries: status card with copy-paste-able
endpoint, 8-tool LazyVGrid gallery (read-only tools first, mutating
tools labeled WRITES), live quick-test playground that hits the
real endpoint, segmented client-setup picker (Claude Desktop /
Claude.ai / curl / custom) with copyable snippets, and a five-bullet
privacy-+-safety story.  The single Settings card is gone.

**Human-language sweep on Downloads → Options card.**  "Connections
per interface" → "Speed per network" with live `polite/balanced/
aggressive` next to the stepper.  "Max concurrent downloads" →
"Downloads at once".  "Per-interface DoH" → "Encrypt DNS lookups".
Tooltips rewritten as plain English.  Metalink + Merkle moved
behind a "Advanced source formats" disclosure that auto-expands
when a manifest is loaded.  Pill copy: "LEAVES" → "CHUNKS".

**SHA-256 source field** rewritten as a friendly disclosure:
collapsed by default with "Verify this download is authentic
(optional)", expands to a plain-language explanation paragraph
+ paste field, auto-opens with a green check + "AUTO-DETECTED"
pill when the auto-detector finds a hash on the publisher's page.

**ContextCard layout bug** (visible as a giant ~600 px empty
rectangle on Trust + Sovereignty in the v1.6.0 screenshots) fixed
with a one-line `.fixedSize(horizontal: false, vertical: true)`.
Root cause: leading accent bar (Shape with no intrinsic height)
was happily growing into leftover vertical space distributed by
TrustView's GeometryReader-driven fixed-height parent VStack.

**Ask-group splash alignment standardized.**  Sovereignty + Trust
empty states rewritten to match the Concierge / Recipes splash
rhythm exactly — 56 pt icon, .title.rounded.bold,
.title3.secondary subtitle, maxWidth 440 bullets, padding 24
outer.  All four Ask tabs now share the same vertical cadence.

**Stale version-string fallbacks killed.**  Added
`Sources/SplynekCore/SplynekVersion.swift` as a single source of
truth.  AboutView, Sidebar.appVersion(), UpdateChecker.currentVersion
now all read `SplynekVersion.current` (Info.plist when the bundle
is around, falls through to `SplynekVersion.fallback` otherwise).
ReleaseCoherenceTests grew a new invariant asserting fallback
matches Info.plist so the next drift can't sneak in.

**App Store Connect monitor** (scheduled remote agent
`trig_01FdTsuA5J9d85sknvtFZTHj`):  daily at 09:00 UTC.  Hits the
iTunes Lookup API on US + PT storefronts; sends a HIGH-priority
push notification the moment Splynek v1.0 flips from `resultCount:0`
to live.  Manual ASC-checking loop closed.

**Localization infrastructure + Portuguese (Portugal).**  56
existing catalog strings now ship pt-PT alongside de/es/fr/it.
Added 62 new v1.6 strings (onboarding, Agents tab, Downloads
relabels, empty states, sidebar groups) translated to all five
locales — 100 % coverage at 118 strings × 5 languages = 590
translations.  `Sources/SplynekCore/Localizable.xcstrings`
auto-regenerated by `Scripts/regenerate-localizations.py`
(human-readable Python dict → catalog JSON).
`CFBundleLocalizations` + `CFBundleDevelopmentRegion` set on
both DMG (`Resources/Info.plist`) and MAS targets (`project.yml`).

**MCP smoke test** (`Scripts/validate-mcp.sh`) — reads the fleet
descriptor, exercises initialize / tools/list / tools/call /
methodNotFound paths against the live endpoint.  Self-documenting;
exits 0 on full pass.

## v1.6.0 — Splynek as a programmable platform (2026-04-29)

Three innovation surfaces ship together to turn Splynek from a download
manager into a programmable substrate any agent can drive:

**MCP server** — JSON-RPC 2.0 endpoint at `/splynek/v1/mcp/rpc` exposes
8 tools (download_url, queue_url, get_progress, cancel_all, list_history,
lookup_sovereignty, lookup_trust, run_sovereignty_scan).  Off by default;
opt in via Settings → MCP server.  Same fleet token gates it as the web
dashboard — no new auth surface.  Conversations like *"download these
five papers, run a sovereignty check, and summarise what I'm installing"*
become one-shot prompts.  Setup docs in `MCP_SETUP.md`.  Compatible
clients: claude.ai (HTTP transport), Claude Desktop (via stdio shim
until they ship HTTP transport), any MCP-compliant agent.

**Spotlight catalog indexing** — Sovereignty + Trust catalog entries
are now system-wide searchable.  Cmd-Space "Notion" returns
"Notion — Sovereignty: EU/OSS alternatives" + "Notion — Trust: 4 concerns"
as Spotlight hits.  Activating one routes via `splynek://sovereignty/<id>`
or `splynek://trust/<id>` deep links into the matching tab.  Index lives
in two new domains: `app.splynek.sovereignty` and `app.splynek.trust`.

**Catalog-aware App Intents** — three new Shortcuts / Siri intents:
`LookupSovereigntyIntent`, `LookupTrustIntent`, `RunSovereigntyScanIntent`.
All return text summaries the user can route to notifications, HomeKit
cards, or further-process steps.  Hits the same catalog as the in-app
tabs; no network access.

**MCP server architecture:**

- `Sources/SplynekCore/MCPServer.swift` — JSON-RPC 2.0 parser +
  dispatcher.  Methods: initialize, tools/list, tools/call, ping, plus
  the standard `notifications/initialized` no-op.  Bridge struct with
  8 `@Sendable` closure slots so unit tests can stub without spinning
  up the VM.
- `Sources/SplynekCore/MCPTools.swift` — tool registry.  Every tool
  returns human-readable text; structured payloads are formatted
  inside the text so an LLM can re-parse if needed.
- `Sources/SplynekCore/MCPBridge.swift` — wires the bridge to the
  live ViewModel.  Mutating tools route through `fleet.onWebIngest`
  — same ingest contract drag-drop / browser extension / menu-bar
  use, so all scheme guards / size confirmations / host caps fire
  automatically.
- `Tests/SplynekTests/MCPProtocolTests.swift` — 12 protocol tests
  (initialize, tools/list, tools/call, error mapping, notifications,
  catalog bridge round-trips).  Async overload added to `TestHarness`
  so async/await test bodies work in the self-hosted runner.

**App Store v1.0 safety:**  no new entitlements (MCP reuses the
existing `network.server` scope).  No archive submitted.  All work
shipped local; user opts in deliberately for any of these surfaces
to be active.

## v1.5.6 — weekly workflow hardening (2026-04-28)

CI: real-rot vs transient classification in `Scripts/check-urls.swift`
so 429 / 403 / 5xx / `-1003` / `-1004` / `-1005` / timeout no longer
page as "rotted URLs". Workflow now reads the new `rotted` /
`transient` JSON arrays separately, only opens an issue on true rot,
and lists the transient-set's first 10 with a link to the artifact
for the rest.

Also: `permissions: issues: write` at workflow level (default
GITHUB_TOKEN went read-only in 2023, blocking the issue-create call
with a 403). Removed `swift run splynek-test` from the lint job —
emit-module on the 22k-line generated `SovereigntyCatalog+Entries.swift`
was OOM-killed (signal 9) on macos-latest's 7 GB runner. Catalog
invariants are still covered by the offline validator + the
regenerator round-trip step. General test-suite coverage will move
to a dedicated `test.yml` workflow with reduced parallelism.

## v1.5.5 — debt clearance (2026-04-26)

Sovereignty validator runs at zero warnings. Replaced the dead BIS
URL (`bis.doc.gov/index.php/policy-guidance/ict-supply-chain` →
homepage redirect) with the canonical Federal Register Final
Determination 2024-13869 reference; added "Federal Register" to the
validator's known-source allowlist. Stale files purged.

## v1.5.4 — Trust score weights + version-sync test (2026-04-26)

Settings card with four sliders for the per-axis Trust weights
(privacy / security / trust / business model). Each setter persists
to its own UserDefaults key (`trustWeight.privacy` etc.) so a
corrupted preference can only break one axis. `Reset to defaults`
button restores the documented defaults via
`SplynekViewModel.resetTrustWeightsToDefault()`.

Added `InfoPlistSyncTests` — invariant test that catches the bug we
shipped twice in v1.4 + v1.5.x where `Resources/Info.plist` (DMG /
SPM build) drifted out of sync with `project.yml`'s
`MARKETING_VERSION` (XcodeGen / MAS build) and the Alfred workflow's
plist. Caught a real drift on first run and forced this fix.

A11y polish on the Trust slider labels (`accessibilityLabel(_:)`
takes plain `String` not `LocalizedStringKey`, otherwise VoiceOver
reads the raw key). Score-breakdown disclosure with per-axis bars on
each row. Refined press-kit angles + comprehensive HANDOFF rewrite.

## v1.5.3 — ContextCard refactor + marketing prep (2026-04-25)

Replaced `PageHeader` (which duplicated the tab name shown by
`.navigationTitle(_:)` in the window chrome) with a new sticky
`ContextCard` component across all tabs. Card sits above the scroll
area with a per-tab tint accent + subtle outer glow. Background is
`.ultraThinMaterial`; SF Symbols rendered `.hierarchical` for
natural depth. PageHeader stays in the codebase for fallback but is
deprecated for new tabs.

Marketing materials shipped: `LANDING.md`, `SHOW_HN.md`, `PRESS_KIT.md`,
`DIRECTORIES.md`, `Scripts/capture-screenshots.sh`,
`docs/index.v1.5.3.html.draft`. Homebrew cask cleaned up (Splynek's
own self-hosted tap at `Splynek/homebrew-splynek` after upstream
rejection on notability heuristics).

## v1.5.2 — Trust polish, sticky context card (2026-04-25)

Trust tab: `Install` button on each fallback alternative
(downloadURL added to `FallbackAlternative`). Neutral copy
("better alternatives" → "fallback options"). Settings gear moved
from sidebar menu to bottom-right of the pane near the logo. Pill
chip contrast inverted when selected so PRO / NEW tags stay legible.

## v1.5.1 — Trust tab polish round 1 (2026-04-25)

Better alternatives now have an `Install` button beside the existing
homepage / store-page links. Pill chips on selected sidebar items
flip to inverted colour scheme so the white-on-white legibility
issue is fixed.

## v1.5 — Trust tab: public-record audit of installed apps (2026-04-25)

A new tab paired with Sovereignty: where Sovereignty asks "where is
this app controlled from", Trust asks "what does the public record
say about this app's privacy, security, and behaviour".

**MAS-safe by design.**  Every concern shown cites a primary source:
Apple App Store privacy labels (which developers self-disclose), EU
DPA / FTC / SEC enforcement actions, the NVD CVE database, the HIBP
breach corpus, vendor security advisories.  No tech-press claims.
No subjective ratings.  No AI-generated risk assessments.  We surface
public record; users verify with one click.

**What ships:**

- New tab `Trust` (sidebar Ask section, NEW badge) with the same
  privacy contract as Sovereignty — opt-in scan, on-device, no
  network, no telemetry, no app-list leaving the device.
- `TrustCatalog` types in `Sources/SplynekCore/TrustCatalog.swift`:
  `Axis` (privacy / security / trust / businessModel), `Severity`
  (low / moderate / high / severe), `Kind` (14 fact-classes — App
  Store privacy labels, GDPR fines, FTC actions, sanctions, CVEs,
  breaches, vendor advisories, business-model self-disclosures).
- `TrustScorer` in `Sources/SplynekCore/TrustScorer.swift`: pure,
  deterministic, weight-aware 0–100 score plus categorical level.
  Default weights are public + documented; users will adjust them
  in Settings (planned v1.6).
- `Scripts/trust-catalog.json` — 30 deeply-cited entries covering
  Chrome, Edge, Messenger, WhatsApp, Slack, Zoom, Teams, Discord,
  Dropbox, LastPass, TikTok, WeChat, Yandex Browser, Kaspersky,
  Adobe (Creative Cloud + Acrobat), Notion, Evernote, OneDrive,
  Google Drive, ChatGPT Desktop, Spotify, Cursor, Grammarly,
  Airtable, Dashlane, Linear, Amazon Kindle, Amazon Music,
  Netflix.  Every concern cites a primary-source URL with a date.
- Pipeline (mirrors Sovereignty):
  - `Scripts/regenerate-trust-catalog.swift` — JSON → Swift codegen
    with strict gates: HTTPS-only, valid enum membership, no future
    dates, banned-editorial-phrase guard.
  - `Scripts/validate-trust-catalog.swift` — soft lint (stale-source
    warnings, terse summaries, unrecognised sourceNames).
  - `Scripts/check-urls.swift` covers Trust URLs too (already
    catalog-agnostic from v1.4).
- UI (`Sources/SplynekCore/Views/TrustView.swift`):
  - Filter chips (All / High risk only / per-axis), search bar.
  - Per-app row with score badge (color-coded), top 4 inline concern
    pills, expandable details with full citation list.
  - Each concern → factual summary + axis icon + severity pill +
    primary-source link with date.
  - Better-alternatives lookup chain: Sovereignty catalog first
    (EU/OSS), then Trust's own `fallbackAlternatives`, then a "no
    curated alternative — contribute one" fallback.
  - Legal footnote at the bottom of every scan: "How this works"
    block explaining the public-record source model.
- FR / DE / ES / IT localisation for all Trust strings (~25 keys
  added to `Localizable.xcstrings`).
- Accessibility: score badges + concern pills carry full
  `accessibilityLabel(_:)` text for VoiceOver — no letter-soup
  pronunciation.
- Tests: 18 new tests in `TrustCatalogTests` + `TrustScorerTests`
  — invariants for HTTPS URLs, banned phrases, ID uniqueness,
  scorer bounds, weight clamping, threshold correctness.
- `TRUST-CONTRIBUTING.md` documents the source allowlist + workflow.

Test count: 126 → 144 (+18).

## v1.4 — Sovereignty catalog pipeline (90 → 1167), AI hardening, FR/DE/ES/IT (2026-04-24)

Sovereignty-tab focused release.  Headline: the catalog grew by a
full order of magnitude (90 → **1167 entries — 13×** more apps
covered) via a new JSON-backed codegen pipeline.  Plus AI-fallback
hardening and FR/DE/ES/IT localisation for the tab's UI copy.

**Catalog pipeline refactor.** The catalog used to live as a hand-
typed Swift literal.  v1.4 splits it into:

- `Scripts/sovereignty-catalog.json` — the authoring source (1 entry
  per object; diffable; community-PR-friendly).
- `Scripts/regenerate-sovereignty-catalog.swift` — a pure-Foundation
  Swift script that reads the JSON, validates it (origins, URLs,
  duplicate IDs), and rewrites
  `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`.
- `Scripts/seed-sovereignty-bulk.swift` — a template-driven
  bulk-expander that pairs target tuples with category-keyed
  alternative sets.  Idempotent (skips bundle IDs already present).
- `splynek-cli sovereignty-dump` — reverse path: emits the current
  catalog as JSON for round-trip verification.

Compile-time type safety is preserved (the output Swift file is
normal code, compiled into the app module).  Contributors edit JSON;
Swift stays auto-generated.  Full workflow in
[SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md).

**Catalog expansion — 90 → 106 entries.** New categories/entries:

- **Cloud storage** — Microsoft OneDrive, Resilio Sync, Backblaze.
- **Communication** — Skype, Google Meet, Telegram, LINE.
- **Creative / writing** — Canva, Grammarly, iA Writer.
- **Dev tools** — Linear, Parallels Desktop, VMware Fusion.
- **Torrents** — µTorrent, BitTorrent Classic.
- **Streaming / academic** — Amazon Music, EndNote.

**AI fallback hardening.** The `sovereigntyAlternatives` system
prompt now includes an explicit FORBIDDEN PATTERNS block listing
the US/CN alternatives the 3B model most commonly hallucinates
(Netflix/YouTube/Prime Video, Discord/Slack/Teams, Dropbox/Google
Drive, ChatGPT/Claude, etc.).  On top of that, a deny-list
post-filter strips any suggestion whose normalised name matches
a known US/CN/RU product — the prompt tells the model, the filter
catches what the model emits anyway.  Valid European picks
(Spotify, Things, Todoist, Sketch — all EU-based) are intentionally
NOT on the deny-list so they continue to surface as suggestions.

**Localisation — FR / DE / ES / IT.** The Sovereignty tab's UI copy
(~30 strings) now lives in `Sources/SplynekCore/Localizable.xcstrings`
with native translations for French, German, Spanish, Italian.
Plumbing: `defaultLocalization: "en"` on Package.swift, PageHeader's
`title` / `subtitle` widened to `LocalizedStringKey` (string-literal
callers unchanged).  Other tabs stay English-only for now — the
pattern is proven and can roll out to Concierge / Recipes / Downloads
in a follow-up pass.

**Invariant tests for the catalog.** New `SovereigntyCatalogTests`
suite (8 tests) locks in: every target is outside the European
ecosystem; every alternative is .europe / .oss / .europeAndOSS /
.other (never US/CN/RU); every entry has at least one recommendable
(EU/OSS) alternative; alt IDs are unique; bundle-ID lookup
round-trips cleanly; catalog within ±50 of expected size; no
duplicate bundle IDs; no `(dup-chk)` placeholders.  Protects the
community PR pipeline from regressions.

**Audit hardening (round 2).** End-to-end audit pass found and fixed:

- *Critical*: scheme-validation gap let a poisoned upstream catalog
  trigger `file://` URLs through the Sovereignty "Install" button.
  Fixed at three layers: data (`Scripts/regenerate-sovereignty-catalog.swift`
  rejects non-https downloadURLs at regen time), merge
  (`Scripts/merge-proposals.swift` enforces http/https before write),
  and UI (`SovereigntyView.actionButton` only renders for safe schemes).
- *High*: `Scripts/ai-propose.swift` now redacts the endpoint URL in
  log output (strips userinfo, query, fragment) and refuses to call
  any non-localhost endpoint over plain http — MITM goldmine when the
  request body includes the user's app list.
- *High*: 12 `(dup-chk)` placeholder entries removed from the catalog
  (workflow markers from the bulk seeder that should never have shipped).
  New `SovereigntyCatalogTests` invariant fails the build if any return.
- *Medium*: AI request UUID dedup in `SovereigntyView` — rapid Ask-AI
  clicks no longer surface stale results from superseded requests.
- *Medium*: `Origin`, `Alternative`, `Entry`, `AISuggestion`,
  `AIRequestState` gained `Sendable` conformance for clean
  Swift-6-mode forward-compat.
- *Medium*: `swiftStringLit` in regenerator now escapes tab, null, and
  the full C0 control range — defends against catalog notes that
  picked up control chars from upstream sources.
- *Medium*: VoiceOver pronunciation fix — origin badges (EU / OSS /
  US / CN / RU) gained `.accessibilityLabel(_:)` with full-word
  descriptions ("European origin", "Open-source", etc.) instead of
  letter-soup defaults.
- *Medium*: `validate-catalog.swift` `try!` on regex compilation
  replaced with named `mustCompile()` that exits with a clear error
  on bad pattern; dictionary force-unwraps replaced with explicit
  default-then-write pattern.
- *Medium*: `searchHistoryViaAI` and `conciergeSend` in `ViewModel`
  gained `license.isPro` guards — defense-in-depth, the UIs already
  gate but the VM functions shouldn't silently hit the Pro stub.
- *Medium*: `merge-proposals.swift` pre-scans for duplicate bundle
  IDs within a batch (was first-wins, silently dropping later dupes).
- *High*: AI-fallback deny-list in `splynek-pro/AIAssistant.swift`
  expanded with brand variants the 3B model emits (chatgpt4,
  microsoftteams, discordpro, googlechrome, geminipro, etc.).

## v1.3 — Sovereignty catalog x2 + AI fallback (2026-04-24)

Same-day follow-up release focused on making the Sovereignty tab
more useful for more people.

**Catalog expansion — 50 → 90 entries.** New categories:

- **Browsers** — Arc (US), Opera (Chinese-majority-owned since 2016).
- **Mail/calendar** — Superhuman (US), HEY (US), Notion Calendar (US).
- **Tasks & project management** — OmniFocus, TickTick (CN),
  Microsoft To Do, Asana, ClickUp, Trello (Atlassian/AU),
  monday.com (IL), Jira + Confluence (Atlassian/AU), Basecamp.
- **Launcher / window mgmt** — Raycast, Magnet, Moom. Recommend
  Rectangle (OSS), Amethyst (OSS), Alfred (UK), LaunchBar (Austria).
- **Dev / terminal** — Warp, Nova, BBEdit, Transmit, Navicat (HK).
- **Media & streaming** — Plex, Emby → Jellyfin (OSS). Riverside,
  Descript → Audacity (OSS).
- **VPN** — NordVPN, ExpressVPN → ProtonVPN (CH), Mullvad (SE).
- **System utilities** — iStat Menus (AU), Amphetamine (US),
  Steam (US), Adobe Acrobat Pro.
- **AI tools** — Perplexity, Microsoft Copilot → Mistral Le Chat
  (France), LM Studio (OSS).

Every new entry has a properly-set `targetOrigin` (US / CN / RU /
OTHER) and 1–2 European or open-source alternatives with proper
license + country notes.

**Stable download URLs for more alternatives:** Thunderbird joins
Firefox in the list of alternatives with one-click "Install"
buttons.  Both leverage Mozilla's stable redirect service
(`download.mozilla.org/?product=…-latest&os=osx&lang=en-US`).

**New: AI fallback for uncataloged apps.** Scans occasionally turn
up apps that aren't in the handwritten catalog.  v1.3 adds a
collapsed disclosure at the bottom of the scan results —
"Apps we don't know yet (N)" — that expands to list up to 25 of
them.  Each has an **Ask AI** button that calls the local LLM with
a focused system prompt (European or open-source suggestions only,
never US/CN/RU, include homepage URLs when confident).  Results
render inline.

Caveats documented in the UI + the post-mortem:
- The 3B on-device model occasionally still suggests US alternatives
  despite the prompt.  Users should verify.
- AI-fallback is Pro-only (gated behind `vm.aiAvailable`).  Free-tier
  users see the catalog-based section but no AI fallback button.
- No probe validation on AI suggestions — we're showing project
  names + homepage URLs, not starting downloads.

## v1.2 — Sovereignty + smarter Concierge (2026-04-24)

**New tab: Sovereignty.** Splynek now scans your Mac's installed apps
locally and shows which ones are controlled from outside the European
Union, with European or open-source alternatives where they exist.

Framing is deliberately **pro-sovereignty, not anti-any-country**. An
app controlled from the US and an app controlled from China sit in
the same bucket from an EU user's perspective: both place control
outside the Union. The tab shows each app's country-of-origin as a
neutral grey badge (US / CN / RU / OTHER) so users see *where control
sits* — we inform, we don't shame — then recommend European or
open-source alternatives because those are the two buckets that
most reduce non-EU dependence.

What's in the launch:

- **Local-only scanner** — enumerates `/Applications`,
  `/Applications/Utilities`, and `~/Applications` via FileManager +
  `Bundle(url:)`. No Spotlight daemon access, no network calls, no
  telemetry, no persistence across launches. Sandbox-legal under
  MAS without any special entitlement. The scanner is
  [open-source in this repo](Sources/SplynekCore/SovereigntyScanner.swift)
  with an audited privacy contract at the top of the file.
- **Seed catalog** — ~50 hand-written entries covering the common
  non-European apps users have on their Macs. Browsers (Chrome,
  Edge, Brave, Yandex), communication (Slack, Zoom, Teams, Discord,
  WhatsApp, Messenger, WeChat, QQ, DingTalk, Webex, Tencent Meeting,
  TikTok), productivity (Office, OneNote, WPS, Notion, Evernote,
  Airtable), creative (Adobe CC + per-app, Figma), dev (VS Code,
  GitHub Desktop, Postman, Docker, Sublime, Sourcetree), cloud
  (Drive, Dropbox, Box, Baidu Netdisk), passwords (1Password,
  LastPass, Dashlane), AI (ChatGPT, Cursor, Claude Desktop), and
  security (Kaspersky, Avast, Yandex).
- **Origin taxonomy** with an `isRecommendable` invariant — catalog
  targets never use European or OSS origins, and catalog alternatives
  never use US / CN / RU. A US app suggested as an "alternative" to
  another US app wouldn't help.
- **One-click Install** for alternatives with stable direct-download
  URLs (Firefox at launch; community PRs expand). Clicking Install
  hands the URL to Splynek's own download engine — multi-interface
  aggregation, SHA-256 verification, the full stack.
- **Filter chips**: All alternatives / European only / Open-source
  only.
- **Community contributions** — [SOVEREIGNTY-CONTRIBUTING.md](SOVEREIGNTY-CONTRIBUTING.md)
  documents the schema, invariants, design principles, and PR
  submission flow.

**Concierge improvements:**

- **Regex short-circuit for obvious cancel/pause commands.** Cancel,
  stop, abort, kill, halt, pause, suspend, hold, freeze — with or
  without a direct object — now bypass the AI entirely. What took
  10–17 s on the on-device 3B model now takes microseconds.
- **Apple Intelligence prewarm on input-focus** — ~1–2 s off the
  first-response cold start, without paying the model-residency
  cost for users who just peek.

**Under the hood:**

- Architecture invariant #11 in [HANDOFF.md](HANDOFF.md) documents
  the load-bearing patterns for SwiftUI NavigationSplitView detail
  panes on macOS 26 (GeometryReader + dedicated ObservableObjects +
  MainActor-isolated @Observable system types).
- [POSTMORTEM-Concierge-Blank.md](POSTMORTEM-Concierge-Blank.md)
  from v1.1.1 remains the canonical reference for those patterns.

No user-facing behaviour change for existing Downloads / Queue /
Recipes / Concierge flows. Only additions.

## v1.1.1 — Concierge blank-state hotfix (2026-04-23)

**P0 fix.** v1.1 shipped with a macOS 26 SwiftUI regression that blanked
the entire Concierge split view the first time a user clicked a
suggestion chip (both sidebar and detail pane vanished, only the
toolbar chrome survived). Three combined changes fix it — all of them
required, removing any one lets the bug come back:

- **`GeometryReader` wrap on `ConciergeView.body`** pins the detail
  column to the parent's offered width, breaking the bottom-up
  intrinsic-size propagation that was collapsing the column when the
  transcript flipped from `emptyState` (intrinsic ∞) to `ScrollView`
  (intrinsic ≈ bubble width).
- **Dedicated `ConciergeState: ObservableObject`** holds `chat` +
  `thinking` so mutations re-render only `ConciergeView` — not Sidebar
  and RootView too. The simultaneous three-view re-render was what
  turned a local collapse into a window-wide blank.
- **`@MainActor AppleIntelligenceDriver` enum** wraps
  `LanguageModelSession` per Apple's WWDC25 sessions 286 / 259 / 301.
  Keeps `Observation.Observable` notifications on MainActor so SwiftUI
  can narrow invalidation to the specific leaves.

Full post-mortem with the four dead-end paths we chased first, the
clinching diagnostic, and six rules-of-thumb for NavigationSplitView
detail panes on macOS 26: [POSTMORTEM-Concierge-Blank.md](POSTMORTEM-Concierge-Blank.md).

No user-facing behaviour change other than "the Concierge works now."
No free-tier impact — the free DMG has never included the Concierge;
this only affects Pro / MAS builds.

## v1.1 — Apple Intelligence Concierge (2026-04-21)

**Strategy Bet S1 shipped** — the AI Concierge + Recipes now run on
**Apple's on-device Foundation Models** on macOS 26+, falling back
to LM Studio / Ollama on older hardware.

What changed:

- **Zero-install AI.** On any M-series Mac with Apple Intelligence
  enabled in Settings, the Concierge and Recipes work out of the
  box — no Ollama, no LM Studio, no model download. Inference runs
  on the Neural Engine (ANE) through Apple's `FoundationModels`
  framework shipped in macOS 26 (Tahoe).
- **Three-tier provider detection.** At launch, `AIAssistant.detect()`
  tries Apple Intelligence first, then LM Studio on :1234, then
  Ollama on :11434. Whichever is ready wins. If none are, the
  Concierge / Recipes tabs show three onboarding cards side-by-side
  (Apple Intelligence → Open Settings; LM Studio / Ollama → Install).
- **Transport-agnostic chat completion.** `chatCompletion()` now
  dispatches to either the in-process Foundation Models path or the
  existing HTTP `/v1/chat/completions` path based on the current
  provider. All upper-layer callers (resolveURL, searchHistory,
  generateRecipe, concierge) remain unchanged.
- **Compiles cleanly on older Xcode.** `#if canImport(FoundationModels)`
  guards the new code path so the SPM build still works on Xcode
  versions without the macOS 26 SDK — in that case Splynek gracefully
  falls through to the HTTP providers.
- **New Provider raw value** `"Apple Intelligence"` surfaces in the
  Concierge footer ("Using Apple on-device model via Apple
  Intelligence"), giving users a clear signal that their data isn't
  leaving the Mac.

Privacy positioning: Apple markets Apple Intelligence as strictly
on-device. That's now Splynek's AI story too — no telemetry, no
account, no cloud, no model download. Kills the "I have to install
Ollama first" friction for the vast majority of Apple-Intelligence-
eligible users.

## v1.0 — Launch (2026-04-21)

First stable release. Same binary as v0.50.4 with the marketing
version bumped to 1.0 for the Mac App Store submission.

What's in the launch build:

- **Multi-interface download engine.** Wi-Fi + Ethernet + iPhone
  tether bonded via `IP_BOUND_IF` into a single pipe with adaptive
  lane stats, per-host caps, cellular-aware scheduling.
- **Verified downloads.** SHA-256 checksums + Gatekeeper signature
  introspection for `.dmg`/`.pkg`. Failed verification doesn't move
  the file out of quarantine.
- **LAN cache + fleet.** Bonjour-advertised peers share completed
  downloads over the LAN. No cloud, no account. Free-tier is
  loopback-only; Pro opens it to the LAN.
- **BitTorrent v2.** Native libtorrent-rasterbar 2.x integration
  with session restore, choking, tit-for-tat, magnet + metalink.
- **Local-AI Pro tier** (Mac App Store only) — `$29` one-time:
  - **Concierge**: chat-first control — "download the latest
    Ubuntu ISO", "cancel everything", "find that iOS SDK". Routes
    through LM Studio or Ollama on your Mac.
  - **Agentic Recipes**: plain-English goals → multi-step download
    plans you review + queue in one click.
  - **Scheduled Downloads**: time-window + weekday + cellular-pause
    policy.
  - **LAN-exposed Fleet + iPhone pairing**: scan-a-QR web dashboard
    on your phone, paste URLs from its share sheet.
- **Integrations**: Alfred workflow, Chrome + Safari browser
  extensions (DMG only), Raycast commands, Spotlight intents,
  URL-scheme + CLI.
- **Native macOS**: Universal 2 (Apple Silicon + Intel), sandboxed
  MAS build, hardened runtime + notarised DMG, macOS 13+.
- **Pre-launch polish** (cumulative from v0.47 → v0.50.4):
  borderless app icon, PRO tags on upsells, LM Studio + Ollama
  hybrid detection, Concierge/Recipes full-bleed upsells,
  consolidated `info@splynek.app` contact address, website
  rewrite at splynek.app.

## v0.50.4 — Contact-email consolidation (2026-04-21)

- **All contact addresses now point to `info@splynek.app`.** Prior
  docs + in-app strings referenced `paulo@`, `support@`, `legal@`,
  and `privacy@` mailboxes that were never provisioned. Only the
  `info@` address (the DSA trader declaration contact) actually
  receives mail. Updated in: `docs/pro.html`, `docs/support.html`,
  `docs/privacy.html`, in-app Legal tab button + label
  (`LegalView.swift`), shipped EULA/AUP/PRIVACY markdown bundles
  (`Resources/Legal/*.md`), `MAS_LISTING.md`, and the `README.md`
  description of the Legal-tab contact button. The only remaining
  `*@splynek.app` is `test@splynek.app` — a deterministic unit-test
  fixture, not a real mailbox.

## v0.50.3 — Borderless app icon + PRO tag on AI-URL card (2026-04-20)

- **App icon: white tile removed.** The colored "S" glyph now fills
  the icon edge-to-edge with transparent corners, following the same
  "silhouette icon" pattern Apple uses for letter-mark brands. The
  prior build rendered the glyph at ~84 % of a rounded white tile,
  which read as "small logo on a white card" at Dock size.
- **PRO pill on the Downloads "Describe downloads in plain English"
  card.** The card was always a Pro upsell but the copy ("Install
  Ollama to type… Runs locally — free") hid that fact. Now shows an
  explicit "PRO" tag next to the title, clarified copy that names
  both LM Studio + Ollama as the local-LLM providers, and a button
  that goes to splynek.app/pro instead of ollama.com — so users who
  click aren't surprised when Ollama alone doesn't unlock the feature.

## v0.50.2 — Free-tier Concierge/Recipes upsell rewrite (2026-04-20)

- **Concierge and Recipes tabs are no longer visually empty in the
  free DMG.** The previous stubs rendered a small `ProLockedView`
  card pinned to the top-leading corner, which on a wide window got
  lost in blank space and read as a broken tab. Rewrote both stubs
  to mirror the Pro build's locked-state pitch: centred gradient
  glyph, bold title, four value bullets, "$29 on the Mac App Store"
  CTA. Covers the full detail column, matches the design of the
  Pro build's pre-unlock state, and stays on-brand with the
  `.windowBackgroundColor` + `navigationTitle` other tabs set.

## v0.50.1 — Concierge sidebar fix + amplified app icon (2026-04-20)

- **Concierge no longer collapses the sidebar.** The outer VStack
  now claims `maxWidth/maxHeight: .infinity`; without that, the
  empty-chat Pro state (no PageHeader, 440-px-wide onboarding cards)
  gave NavigationSplitView an intrinsic width too narrow to satisfy
  the detail column's `min: 640`, so the split auto-hid the sidebar.
- **App icon glyph enlarged.** The colored "S" inside the icon tile
  was filling only ~35 % of the canvas, which read as "tiny logo
  floating in a white square" at Dock size. Re-rendered the iconset:
  auto-trimmed the glyph's bounding box, scaled it to ~84 % of the
  1024-px canvas, composited onto a rounded-rect white tile with
  transparent outer corners (macOS app-icon convention). Rebuilt
  .icns; refreshed docs/icon-256.png + docs/icon-1024.png.
- **Hero logo now actually transparent.** The embedded-JPEG source
  under the Canva SVG was bleeding white; color-keyed it out so
  `docs/logo-transparent.png` renders with a true RGBA-transparent
  background against the dark site.

## v0.50 — LM Studio support + marketing-site rewrite (2026-04-19)

- **LM Studio + Ollama hybrid.** `AIAssistant` now probes both
  `localhost:1234` (LM Studio) and `localhost:11434` (Ollama) in
  parallel at launch, picking whichever answers first. All LLM calls
  route through a single `chatCompletion(...)` helper that speaks
  OpenAI's `/v1/chat/completions` format — native for LM Studio,
  supported by Ollama since 0.1.14. Same code path for URL resolution,
  history search, Recipes, and Concierge.
- **New Provider enum.** `Provider { .ollama, .lmStudio }` carries
  per-provider URLs (chat, models list, download page). State shape
  changes to `.ready(provider:model:)` — the VM surfaces both so the
  Concierge empty state can show "Using llama3.2:3b via LM Studio".
- **Dual-provider onboarding UI.** Concierge empty state + Recipes
  `aiMissingCard` now show two cards — LM Studio ("EASIEST", green)
  and Ollama ("LIGHTER", blue) — each with a one-click install button
  and a shared "Check again" refresh. Prior copy assumed every user
  would `ollama pull llama3.2:3b` from a terminal, which landed badly
  with non-technical testers.
- **pro.html / support.html / privacy.html restyled.** Extracted the
  v0.49 inline CSS into `docs/splynek.css` and rebuilt each supporting
  page on the same card-panel + page-hero grammar as the landing page.
  Privacy page lede now calls out LM Studio alongside Ollama as a
  non-cloud LLM option.

## v0.49 — UX overhaul + new logo (2026-04-19)

- **Sidebar reordered ASK → ACTIVE → LIBRARY.** Pro-discovery tabs
  (Concierge, Recipes) now sit above the fold. `Settings`, `Legal`,
  `About` moved out of the sidebar into the macOS menu bar — Apple
  menu → About / Settings… (⌘,) and Help menu → Legal…. Sidebar
  ends with a compact "Welcome to Splynek" brand footer so first-
  paint still carries the wordmark.
- **New logo.** Canva-authored Splynek mark replaces the v0 glyph
  everywhere — in-app `.icns`, docs/icon-{256,1024}.png, the website
  hero, Pro-tab empty states.
- **Website landing rewrite.** Gradient hero with 144pt mark,
  "Use every network, at once." headline, proof bars (38 MB/s Wi-Fi
  vs 117 MB/s Splynek), 6-card feature grid, Pro teaser panel,
  closing CTA. Shrunk the QR panel on the in-app Web Dashboard tab
  (170 → 110 px).

## v0.48 — Pro tab discovery (2026-04-19)

- **Concierge + Recipes always visible.** Free-tier users see the
  Pro tabs in the sidebar with PRO badges. In-tab locked upsells
  replace the empty chat / goal editor with a sneak-peek of what
  they'd get and a $29 CTA to the Mac App Store. Rationale: you
  can't want what you don't see.
- **AI Assistant renamed Concierge.** More aspirational, less
  utilitarian. The pitch is "your personal download concierge."
- **Themed Ideas panel in Recipes.** 24 starter goals grouped by
  theme (Dev setup, Linux distros, Media, AI + ML, Games, Writing).
  Clickable chips auto-fill the goal field.

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
