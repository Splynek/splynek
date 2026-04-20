# Splynek

Native macOS multi-interface download aggregator. Binds outbound connections
to every active network interface on your Mac (Wi-Fi, Ethernet, iPhone USB /
Personal Hotspot, Thunderbolt NICs) and downloads a single HTTP file in
parallel across all of them using byte-range requests. IPv4 and IPv6.

A proper `.app` bundle — SwiftUI, `Network.framework`, zero third-party
dependencies, no Python, no Electron.

## Build

Requires Swift 5.9+ (Swift 6.3 tested). Xcode Command Line Tools is enough.

```sh
./Scripts/build.sh
open build/Splynek.app
```

Install system-wide:

```sh
cp -R build/Splynek.app /Applications/
```

## What's new in v0.47 (P3 polish — Queue Summary redesign + tooltips pass)

v0.46 shipped the urgent-bug + polish pass. v0.47 is the deliberate-
polish round: the last batch of user-QA feedback that didn't make
the P1/P2 cut, plus a tooltips sweep on the jargon-heavy controls
that scare off non-technical buyers.

### Queue → Summary card redesigned

The old layout (four bare MetricViews in a row) read as visually
flat and gave no sense of scale. New layout:

- **Hero line** — 40pt rounded-display total count + state-aware
  subtitle. The subtitle swaps between "Running 2, 3 queued." /
  "Running 1 right now." / "5 waiting to start." / "All clear — 5
  finished." / "Empty. Paste a URL on Downloads."
- **Status pills** — coloured dot + count + label for each state
  (Running / Pending / Done / Failed). Cancelled only shows up when
  non-zero so the card isn't permanently five-columned.
- **Bulk-action bar** — **Retry all failed** + **Clear finished**
  appear contextually. Tooltip on each explains the exact behaviour.
  Backed by a new `vm.retryAllFailed()` method that flips every
  failed/cancelled entry back to pending and kicks the runner. Saves
  users clicking through the per-row menu after a Wi-Fi blip kills
  ten entries.

### Tooltips pass — 12 new `.help()` on jargon controls

Non-techie users bounce off terms like "Connections per interface"
and "Per-interface DoH." Added explanatory tooltips + a new
`labelWithInfo(_:tooltip:)` helper that renders a caption label with
a small ⓘ icon. Applied so far:

- **Connections per interface** — "How many parallel HTTP connections
  per network interface. More = higher peak throughput, but also
  more load on origin servers. 1–2 is polite; 4–6 is aggressive."
- **Max concurrent downloads** — explains queue behaviour + when to
  bump it.
- **Per-interface DoH** — full paragraph on what DNS-over-HTTPS-per-
  interface actually buys (DNS leak prevention + ISP-blind lookups,
  slight first-request latency penalty).
- **Load Metalink…** — explains the .metalink / .meta4 XML format
  and when it's useful (Linux distros).
- **Load Merkle…** — explains per-chunk verification vs end-of-file
  SHA-256.
- Assorted Clear / Remove secondary buttons.

### Dev override for Pro audit

New `splynekDevProUnlocked` UserDefaults flag in splynek-pro's
`LicenseManager`. When YES, `isPro` flips true at init and stays on
through `refreshEntitlements()`. Used for Pro-feature QA without
needing a real StoreKit sandbox purchase. Also documented in the
App Store review notes so Apple reviewers can toggle it if they
prefer to skip the TestFlight / Sandbox Apple ID flow.

Activation:
```sh
defaults write app.splynek.Splynek splynekDevProUnlocked -bool YES
# relaunch → Assistant + Recipes tabs visible
defaults delete app.splynek.Splynek splynekDevProUnlocked
# relaunch → back to normal StoreKit-gated behaviour
```

### Tests + builds

117 tests green. Three build paths all clean (SPM, Xcode DMG, Xcode
MAS). The `Splynek-MAS.xcarchive` at v0.47 is Apple-Distribution-
signed and ready for ASC upload; the DMG is Developer-ID-signed,
notarised, and stapled. Free DMG download on the GitHub Release now
opens without any right-click dance (notarised since v0.46).

---

## What's new in v0.46 (P1 + P2 pre-submission QA fixes)

A full user-QA pass on v0.45 found 17 bugs + UX issues before the
first App Store submission. v0.46 addresses the P1s (real functional
bugs that would earn an App Review rejection or a bad first-review
score on the Store) and the P2s (polish items visible in Store
screenshots).

### P1 bugs fixed

- **Pause no longer shows as "Cancelled"** — `settleAfterRun()` in
  `DownloadJob.swift` was letting the engine's end-of-run
  "Cancelled." `errorMessage` bleed into the paused state (red
  banner on paused rows). Now explicitly cleared on the paused
  branch. Pause is visibly pause.
- **Phase no longer frozen on "Downloading" after pause/cancel** —
  `settleAfterRun()` resets `progress.phase` to `.pending` on every
  non-completed exit so the Live pipeline strip reads correctly.
- **Trash icon works on paused jobs** — `removeJob()` previously
  guarded on `isActive` (which includes paused); now cancels the
  engine inline and removes regardless.
- **Bad-URL feedback now visible** — the error banner was rendered
  below the active-jobs list, so on an empty state (typical first
  use) it was below the fold. Moved INSIDE the Source card,
  directly under the Start button. Also: `Probe.swift` now returns
  human-actionable HTTP error hints ("HTTP 404 — the file doesn't
  exist at that URL. Check the path." instead of just "HTTP 404.").
- **Throughput no longer spikes to fantasy GB/s** — `LaneStats.record()`
  was clamping the sample-window divisor to 0.001 s, so a 5 MB chunk
  arriving mid-session would display as 5 GB/s for a frame. Bumped
  to 0.5 s minimum; worst-case under-shoot is now ~2× during the
  first 500 ms, but the display is always in believable territory.

### P2 polish

- **Phase pills readable again** — the old layout packed icon + text
  + divider per pill, which squeezed narrow cells until SwiftUI
  broke the label into stacked single characters ("Q u e u e d"
  vertically). Now icon-only for past/future pills, icon + label
  for the current one, with `.help()` on every pill providing the
  hover tooltip.
- **iPhone USB tether correctly detected + labeled** — macOS
  presents it as wiredEthernet (it IS Ethernet-over-USB), so prior
  UI showed a mysterious "ETH" row next to Wi-Fi. Detection via
  the 172.20.10.0/28 IP range + wiredEthernet link type; new
  `.iPhoneUSB` `DiscoveredInterface.Kind`; new icon (`iphone`),
  label ("iPhone"), cyan tint. Also treated as metered for the
  cellular-budget check (the carrier IS cellular bandwidth).
- **Wi-Fi icon changed from yellow to blue** — yellow read as a
  warning badge. Blue matches the rest of macOS's Wi-Fi styling.
- **Queue 3-dots menu enriched** — completed rows previously held a
  single "Remove" item, which rendered as an apparently empty menu
  on macOS 14. Now every state has 2+ entries (Retry, Open URL,
  Copy URL, Remove) so the menu reads as functional at a glance.
- **Duplicate Start/Queue toolbar buttons removed** — the top-right
  toolbar's Start and Queue buttons were pixel duplicates of the
  big buttons inside the Source card below. Users flagged as
  clutter. Toolbar keeps only Cancel All (contextual), Copy curl,
  Advanced; keyboard shortcuts (⏎ and ⌘⇧Q) moved to the card
  buttons.
- **Benchmark Run button surfaced inline** — was tucked in the
  top-right toolbar where most users never found it. Now a large
  "Run benchmark" button sits directly below the target URL, with
  a "Results below ↓" hint when results are available. Toolbar
  keeps only post-run Copy / Save-image actions (they export the
  whole-tab state, making toolbar placement appropriate).
- **History row actions reduced 3 → 2 icons** — was info + eye +
  magnifying-glass; users couldn't tell the info from the eye.
  Now two visibly distinct icons (Details = blue info-filled,
  Reveal in Finder = folder). Quick Look still accessible via
  right-click context menu and via Finder's spacebar after Reveal.
- **Fleet sharing → per-file "Stop sharing"** — new eye-slash
  button on each file row in the "What this Mac is sharing" card.
  Exclusion list persisted in UserDefaults under
  `fleetExcludedURLs`; a "Restore all" link surfaces at the card
  footer when any files are hidden. File and history entry stay
  intact; only fleet peer-sharing stops.
- **About logo shrunk** — 128 → 88 px with tighter padding. The
  hero was overwhelming on the current card-grid layout.

### Notarisation shipped

Signing certificates lived elsewhere until this session. v0.46:
- Apple Distribution cert installed (MAS signing)
- Developer ID Application cert installed (DMG notarisation)
- `notarytool store-credentials AC_PASSWORD` keychain profile set
- DMG re-signed with Developer ID, submitted to Apple notary
  service, `Status: Accepted`, stapled, uploaded as the GitHub
  Release asset. Users who `brew install splynek` or download the
  DMG directly no longer see the right-click-to-open Gatekeeper
  dance.

---

## What's new in v0.45 (MAS build infrastructure — the Xcode project scaffold)

v0.44 split the source tree (public free core + private `splynek-pro`
Pro modules) and replaced the HMAC license with "Pro is on the Mac
App Store" stubs. v0.45 is the plumbing that actually makes the MAS
build possible: Xcode project, sandbox entitlements, StoreKit 2
integration, and `#if MAS_BUILD` guards on features the App Store
sandbox rejects.

### What's in this release

- **`project.yml`** — [XcodeGen](https://github.com/yonaskolb/XcodeGen)
  spec that generates `Splynek.xcodeproj` with two targets:
  - `Splynek` (DMG) — direct-source compilation, same behaviour as
    `./Scripts/build.sh`, for Developer-ID-notarised distribution.
  - `Splynek-MAS` — sandboxed, IAP-capable, excludes
    `ProStubs.swift` + the three stub view files, includes
    `splynek-pro/Sources/SplynekPro/` from the sibling private repo.
- **`Resources/Splynek-MAS.entitlements`** — sandbox entitlements
  with `network.client`, `network.server`, files.user-selected,
  files.downloads, and bookmarks.app-scope. See
  `splynek-pro/SANDBOX_AUDIT.md` for the per-entitlement rationale.
- **`Resources/Splynek.storekit`** — local StoreKit test config
  (product `app.splynek.Splynek.pro` @ $29) so the purchase flow can
  be driven without an App Store Connect submission during dev.
- **`#if MAS_BUILD` guards** on `GlobalHotkey` and `UpdateChecker` —
  both no-op in MAS (Accessibility API unavailable in sandbox; App
  Store handles updates directly).
- **DMG-build Pro card rewritten** (`SettingsView.proFreeContent`):
  the old email+key form is gone. Free-tier users see a single
  "Get Splynek Pro on the Mac App Store" link. The MAS build shows
  a StoreKit IAP "Buy — $29" + "Restore Purchase" pair instead.
- **StoreKit 2 integration in `splynek-pro/Sources/SplynekPro/LicenseManager.swift`**
  — replaces the HMAC implementation. Flips `isPro` when the
  `app.splynek.Splynek.pro` non-consumable IAP verifies; reacts to
  Apple-side refunds via `Transaction.updates`; exposes `purchase()`
  and `restore()` async methods consumed by the MAS settings card.

### What builds where

| Build | Command | Result |
|---|---|---|
| Free DMG (ad-hoc) | `./Scripts/build.sh` | `build/Splynek.app`, no sandbox |
| Free DMG (notarised) | `xcodebuild -project Splynek.xcodeproj -scheme Splynek archive` | `.xcarchive` → Developer ID export |
| Mac App Store | `xcodebuild -project Splynek.xcodeproj -scheme Splynek-MAS archive` | sandboxed `.xcarchive` → MAS upload |
| SPM (dev) | `swift build -c release --product Splynek` | unchanged, still Xcode-optional |
| Tests | `swift run splynek-test` | 117 green |

### What's NOT in the MAS build (by design)

- **Global hotkey** — Carbon API isn't permitted for sandboxed apps.
  DMG users keep the ⌘⇧D show-Splynek shortcut; MAS users don't.
- **`splynek-cli` helper** — MAS can't install `/usr/local/bin/`
  binaries. DMG users get the CLI; MAS v1 doesn't ship it.
- **Self-update banner** — Apple enforces "App Store is the only
  update channel." Users get MAS-native updates.
- **DMG→MAS data migration** — on first launch, MAS is a fresh
  install; existing history/queue stays with the DMG copy. Proper
  one-way migration is tracked for MAS v2.

### Setup for building MAS locally

```sh
brew install xcodegen
git clone https://github.com/Splynek/splynek.git
cd splynek
# splynek-pro clone required as a sibling, private-repo access needed
git clone git@github.com:Splynek/splynek-pro.git ../splynek-pro

xcodegen generate
open Splynek.xcodeproj
# Product → Archive (scheme: Splynek-MAS)
```

Developers without private-repo access can still build the free
`Splynek` target (DMG variant). The MAS target just won't compile —
it references `splynek-pro` sources.

---

## What's new in v0.44 (the public/private split — free core on GitHub, Pro on the Mac App Store)

v0.33–v0.43 shipped the commercial substrate (license gate, AI Concierge,
Recipes, scheduled downloads, LAN-exposed Fleet) and pushed the first
open-source Release to GitHub. A day later the obvious question arrived:
*if every line of Pro is MIT-licensed in the public repo, what exactly is
there to charge $29 for?* Answer: nothing cryptographic — the "gate" was
a one-line edit away from unlocked. v0.44 is the architectural fix.

### What moved

Five modules moved to a **private** repo (`Splynek/splynek-pro`, not
browsable outside the Splynek team). They now ship only in the Mac
App Store build, where StoreKit enforces the $29 one-time unlock:

- `LicenseManager` (soon replaced by `StoreKitManager` in the MAS build)
- `AIConcierge` + `AIAssistant` — local-Ollama chat router + URL resolver + history search
- `DownloadRecipe` — agentic multi-step planner
- `DownloadSchedule` — time-window + weekday + cellular rules
- `ConciergeView` + `RecipeView` + `ProLockedView` — the SwiftUI tabs
- `Scripts/gen-license.py` — obsolete HMAC issuer (superseded by StoreKit)
- Four test suites (`LicenseValidatorTests`, `ConciergeTests`, `RecipeParserTests`, `DownloadScheduleTests`)

### What the free DMG build still has

**Everything that was free at v0.43:** multi-interface HTTP aggregation,
torrents (v1 + v2, magnets, DHT, seeding), queue, history, Live
dashboard, History detail sheet, Benchmark, Watched folder, CSV export,
usage timeline, Fleet REST API (loopback-only — LAN exposure is a
Pro gate), web dashboard (localhost-accessible), Chrome / Raycast /
Alfred / bookmarklet integrations, menu-bar mode, login-item background
mode, Gatekeeper signature inspection, per-host caps, cellular budget.

### How the split works structurally

The public `SplynekCore` module now carries a small `ProStubs.swift`
that gives Pro types (`LicenseManager`, `AIAssistant`, `DownloadRecipe`,
`DownloadSchedule`, `RecipeStore`) API-compatible free-tier stubs —
`isPro` is always `false`, all AI methods throw `UnavailableError`,
`schedule.evaluate(...)` always returns `.allowed`, the recipe store
loads `[]` and persists nothing. `ViewModel` and the Pro-gated views
(`ConciergeView` / `RecipeView` / the Pro cards in `SettingsView`)
compile against these stubs unchanged.

In the MAS build, the Xcode project excludes `ProStubs.swift` and the
three stub view files, and links `SplynekPro` (from the private
package) in their place — same type names, real implementations,
StoreKit IAP drives `isPro`.

Public build ≈ "free core + stub placeholders." MAS build ≈ "free core
+ SplynekPro's real modules." One `Package.swift`, one `ViewModel`,
one source tree — only the leaf Pro files differ.

### Tests

117 (was 165 at v0.43). 48 tests moved with their sources to the
private repo.

### DMG

2.3 MB (down from 2.5 MB at v0.43) — ~1,400 LOC lighter for the free
build.

---

## What's new in v0.43 (QA pass — bug-fix release before launch)

v0.42 shipped Agentic Download Recipes; a full real-user walkthrough
surfaced a critical rendering bug, a recipe-URL safety gap, and a
dozen smaller UX issues. v0.43 is all fixes, no new features.

### P1 — ship-blocker fixed

- **Assistant + Recipes tabs rendered blank and wedged the whole
  `NavigationSplitView`** — the sidebar lost items, the detail pane
  went empty, and only a full app restart recovered. Root cause
  isolated via bisection against v0.31: SwiftUI on macOS 14
  miscomputes sidebar layout when a tab's destination view body has
  a top-level conditional returning structurally different subtrees.
  Every in-view workaround (Group wrapper, unified VStack, ScrollView
  wrapper, `.id()` splitting) failed. **The real fix: move the Pro
  gate out of the view bodies and into the sidebar** — when the
  user isn't Pro, the Assistant + Recipes rows simply don't appear,
  and a single "Unlock AI tools" row (with a PRO pill) jumps to
  Settings' unlock form on click. Same pattern Bear, iA Writer, and
  most Mac indies use for subscription-gated areas. Bodies of both
  views restored to their clean pre-gate shapes.

- **Recipe items with Mac App Store URLs silently failed in the
  queue.** The LLM sometimes returned `apps.apple.com/us/app/xcode/...`
  as Xcode's "url"; Splynek dutifully tried to range-download an
  HTML page and surfaced *"Server doesn't advertise Range support;
  aggregation impossible."* Fixed at two layers: the prompt
  explicitly forbids App Store URLs ("for Apple-only apps with no
  direct download, skip the item entirely"), and
  `RecipeParser.isNonDownloadableHost(...)` rejects
  `apps.apple.com` / `itunes.apple.com` / `play.google.com` /
  `apps.microsoft.com` / etc. client-side so hallucinated items
  never reach the queue.

### P2 — UX polish surfaced during the walkthrough

- **Goal text cleared after successful recipe generation** — users
  no longer have to delete their previous goal before typing the
  next one. Cleared via `.onChange(of: vm.currentRecipe?.id)`.
- **Queue row time display rewritten**:
  - COMPLETED rows show **"took 2s"** (actual download duration
    from `startedAt → finishedAt`).
  - FAILED / CANCELLED rows hide the clock entirely — the error
    message already carries the timing context.
  - PENDING / RUNNING keep the "added X ago" relative clock.
- **Queue Summary icon changed** from `chart.bar` (read as Wi-Fi
  signal strength) to `list.clipboard`.
- **Relative-time formatter** (`formatRelative(_:)`) — clamps
  sub-minute intervals to "just now" (no more `-2 min`), and uses
  `en_US_POSIX` so abbreviated units don't mix with Portuguese
  connector "e" (previously rendered as `3 min e 14 seg`).
- **Magnet display names decode `+` as space** — `dn=Ubuntu+Test`
  now resolves to "Ubuntu Test"; `dn=C%2B%2B+Guide` correctly
  resolves to "C++ Guide" (plus-decoded before percent-decoded).
- **Host-usage reconciliation on completion** — `DownloadEngine`
  tops up `HostUsage.credit(...)` if the per-lane crediting
  undercounted (happens on tiny files / single-shot paths).
  "Today by host" now reflects every completion.
- **Chart legend private-IP friendliness** — `172.20.10.4` in the
  Usage timeline legend now renders as "LAN (172.20.10.4)", same
  for `192.168.*`, `10.*`, loopback, and IPv6 ULA/link-local.
- **"Launch at login — Unavailable" message rewritten** from the
  scary `App not found in expected path.` to the actionable *"Move
  Splynek to /Applications first, then toggle this on."*
- **Toolbar tooltips** — every Downloads-toolbar button now has a
  `.help(...)` hint. Hover reveals the action + keyboard shortcut.
- **Inline Start / Queue buttons** in the Source card — users no
  longer have to hunt the toolbar for primary actions. Toolbar
  remains as the keyboard-shortcut home.

### Tests
5 new assertions across the QA-regression set:
- `App Store / marketing-host URLs are dropped` (recipe parser).
- `Display name with '+' decodes as space` (magnet parser).
- `A literal '+' escaped as %2B still round-trips` (magnet parser).
- Existing 158 assertions updated (canonical recipe fixture swapped
  its Xcode item for a VS Code URL since apps.apple.com now rejects
  at parse time).

**Suite: 165 green.**

### What this doesn't do yet
- **Trial period** — still no 14-day Pro trial. Tracked for v0.44+.
- **MAS StoreKit IAP** — still blocked on the €99 Apple Developer fee.
- **Phase-transition order assertion in integration test** — still
  only asserts monotonic subsequence, not exact order; fast
  loopback downloads skip phases between polls.

## What's new in v0.42 (Agentic Download Recipes — cutting-edge AI)

The AI so far resolved one URL at a time. v0.42 upgrades it to **plan
batches**. User types a goal in plain English — *"set up my Mac for
iOS development"*, *"everything I need to self-host a small Linux
server"* — and the local LLM returns a **structured recipe**: 5–10
downloads with URLs, rationales, self-rated confidence, and homepage
links for user verification. User reviews, unchecks what they don't
want, clicks **Queue N downloads**. Splynek runs the batch through
the existing multi-interface + checksum + schedule pipeline.

**Nothing else does this.** Homebrew bundles are static text. No
download manager generates a batch from intent. aria2, FDM, Motrix,
JDownloader — none of them. This is agentic AI + LLM structured
output + human-in-the-loop review + Splynek's existing execution
plumbing, all composing into a feature that's genuinely new.

### What landed
- **[Sources/SplynekCore/DownloadRecipe.swift](Sources/SplynekCore/DownloadRecipe.swift)** — `RecipeItem` +
  `DownloadRecipe` types + `RecipeParser` + `RecipeStore` (capped
  at 20 recent recipes). The parser is the robustness surface —
  tolerant of markdown fences, leading/trailing prose, embedded
  braces in string literals; strict about URL scheme, required
  fields, confidence clamping, and SHA-256 format.
- **`AIAssistant.generateRecipe(goal:)`** (in [AIAssistant.swift](Sources/SplynekCore/AIAssistant.swift))
  — few-shot prompted, `format: "json"` enforced, temperature 0.2
  for deterministic-ish output, 90s timeout (small models can take
  60s for structured output of this length). Returns a parsed
  `DownloadRecipe`.
- **[Sources/SplynekCore/Views/RecipeView.swift](Sources/SplynekCore/Views/RecipeView.swift)** — three
  states: **Pro-gated** (shows `ProLockedView`), **AI-missing**
  (shows Ollama install instructions + retry), **ready** (goal
  editor + recipe card + recent-recipes history). Recipe card
  renders each item with checkbox, name, confidence pill
  (colour-coded ≥85%/≥70%/<70%), rationale, URL (clickable),
  homepage link, size hint, truncated SHA-256 if present. Items
  under 70% confidence get an orange-tinted background.
- **VM integration** — `currentRecipe`, `recipeGenerating`,
  `recipeError`, `recipeHistory` `@Published`. `generateRecipe(for:)`,
  `queueCurrentRecipe()`, `toggleRecipeItem(id:)`,
  `discardCurrentRecipe()`, `reopenRecipe(_:)`.
- **Recipes sidebar tab** between Assistant and Queue. Accessory
  pill: `DRAFT` when a recipe is pending approval, spinner while
  the LLM is thinking.
- **Pro-gated** — aligns with [MONETIZATION.md](MONETIZATION.md).
  Concierge + Recipes are now the core Pro wedge.

### Safety
- **Every URL has a clickable homepage** for user verification.
- **Confidence scores are self-rated by the LLM** and surfaced as
  coloured pills. Below 70% flashes an orange stripe on the row.
- **No auto-queue.** The recipe is a *proposal*. The user
  explicitly clicks **Queue N downloads**. Nothing starts without
  approval.
- **Individual item toggles.** User can uncheck any item before
  queuing.

### End-to-end verified
Live test against `llama3.2:3b` on a real Ollama instance:
- *"set up my Mac for iOS development"* → 4 items, 12.2 s generation,
  Xcode App Store URL correct, others default to homepage URLs with
  lower confidence (the prompted fallback behaviour).
- *"latest Ubuntu desktop ISO plus VS Code and Docker"* → 3 items,
  7.4 s, Ubuntu + VS Code + Docker URLs from official sources.

### Tests
19 new assertions across 3 suites in `RecipeParserTests`:
- **Tolerance (5 tests)**: canonical response; markdown-fenced
  response; leading prose; trailing prose; braces inside JSON
  strings.
- **Strictness (10 tests)**: non-http URL dropped; missing-field
  item dropped; confidence clamped; missing confidence defaults to
  0.5; invalid SHA-256 dropped; non-http homepage dropped; all-
  items-dropped throws `.noItems`; no JSON throws `.noJSONFound`;
  malformed JSON throws; all items default `selected = true`.
- **Codable (1 test)**: round-trip through JSONEncoder/Decoder.

**Suite: 162 green (up from 146).**

### What this doesn't do yet
- **No version-freshness verification.** The LLM's URL knowledge
  is only as fresh as its training cutoff. User can always edit
  URLs before queuing. A future pass could HEAD-check each URL
  and warn on 404s.
- **No "retry with bigger model" button.** If the small model
  produces a thin recipe, users just re-prompt. Model-picker UI
  is a future improvement.

## What's new in v0.41 (Pro license gating — commercial substrate)

[MONETIZATION.md](MONETIZATION.md) has always described a freemium
split with five Pro differentiators. Through v0.40, every one of
those differentiators had silently shipped into the free tier —
including v0.34's scheduled downloads and v0.28's AI Concierge.
v0.41 is not new user-facing features; it's the commercial
substrate: an offline license validator, a Pro-gate at each of the
five call sites, and a Settings card that accepts a key.

The engineering is done so the product can actually *sell*. The
€99 Apple Developer fee is the only remaining blocker to hosting
the store and notarizing the binary; the license code itself runs
fine today against a test key generated via
[Scripts/gen-license.py](Scripts/gen-license.py).

### What landed
- **[Sources/SplynekCore/LicenseManager.swift](Sources/SplynekCore/LicenseManager.swift)** — pure
  `LicenseValidator.issue(email:)` / `.validate(email:key:)` over
  `HMAC-SHA256` with a compiled-in secret, returning keys in the
  `SPLYNEK-AAAA-BBBB-CCCC-DDDD-EEEE` format. Plus a
  `LicenseManager` `ObservableObject` that persists the key/email
  to `UserDefaults[splynekProEmail]` / `[splynekProKey]` and
  re-validates on every launch (tampered persisted data is
  ignored — defence in depth against hand-edited defaults).
- **[Scripts/gen-license.py](Scripts/gen-license.py)** — the
  server-side issuance tool. Same HMAC secret, same format. Runs
  in the Stripe-success webhook in production; a test asserts the
  Swift and Python implementations agree byte-for-byte on a known
  fixture (`test@splynek.app` → `SPLYNEK-250B-54AA-8108-AB17-ACA7`).
- **[Sources/SplynekCore/Views/ProLockedView.swift](Sources/SplynekCore/Views/ProLockedView.swift)** —
  reusable paywall placeholder. Takes over a feature's real
  estate with a title + summary + SF symbol + *Unlock Splynek
  Pro — $29* CTA. Design principle: visible but not functional,
  so users *see* what Pro offers.
- **Gates at 4 call sites** (the fifth — fleet >2 devices — is
  deferred to v0.42 because it touches the hot swarm path):
  - **Scheduled downloads** — `vm.scheduleEvaluation` short-
    circuits to `.allowed` when not Pro; Settings card renders
    `ProLockedView`.
  - **AI Concierge** — view body replaced with `ProLockedView`
    when not Pro.
  - **AI history search** — sparkle row hidden in both
    `HistoryView` (aiSearchBar) and `DownloadView` (aiRow).
  - **Mobile web dashboard** — `FleetCoordinator.proGateForcesLoopback`
    forces the listener to bind to 127.0.0.1 when free.
    Settings card shows `ProLockedView` so users know what
    they're missing.
- **Splynek Pro settings card** at the top of Settings. Two
  states: `FREE` with *Buy Pro* + *I already have a key* affordance,
  or `ACTIVE` with licensed-email display + *Deactivate on this Mac*
  button.

### What this unlocks commercially
- Every feature currently flagged Pro in [MONETIZATION.md](MONETIZATION.md:61)
  that was built is now correctly gated. The free tier matches
  what v0.27 was supposed to ship; the Pro tier matches what Pro
  was supposed to differentiate on.
- Direct-DMG → Stripe checkout → Postmark email → key works
  end-to-end as soon as the Stripe + email plumbing is set up
  (both are out-of-app configuration, not code work).
- MAS IAP path still needs a `StoreKit` receipt-validation
  helper, deferred to v0.42 once the €99 is paid and the MAS
  submission flow is real.

### Tests
13 new assertions across two suites:
- **License validator** (8 tests): Swift issue() matches Python
  gen-license fixture byte-for-byte; issue is deterministic;
  email normalisation tolerates case + whitespace; tampered or
  wrong-email keys are rejected; empty inputs rejected; key
  format matches the advertised shape.
- **LicenseManager state machine** (5 tests): fresh init → free;
  valid unlock → persisted → reborn manager sees Pro; wrong key
  → free + user-facing error; deactivate wipes persistence;
  hand-edited invalid persisted data is ignored on load.

**Suite: 146 green (up from 133).**

### What this doesn't do yet
- **No fleet-peer-count gate.** Touches the hot swarm code path;
  needs care. Tracked for v0.42.
- **No StoreKit IAP.** MAS distribution is still blocked on the
  €99 fee; a `StoreKit` receipt-validation helper slots in once
  the paid Apple Developer account exists.
- **No trial.** Adding a 14-day trial with a `trialStartedAt`
  UserDefaults entry is a small future pass.
- **Secret is in the binary.** A determined attacker can reverse-
  engineer it. For a $29 solo-dev Mac app, that's the accepted
  economics — see the threat-model comment at the top of
  `LicenseManager.swift`.

## What's new in v0.40 (Torrent session restore)

HTTP downloads resumed correctly from a sidecar file since v0.11.
Torrents didn't — every start wiped the partial payload because
`TorrentWriter.preallocate()` called `fm.removeItem(at:)` on each
declared file before creating it fresh. v0.40 fixes the data-loss
bug and adds a piece-level resume scan so any already-downloaded
bytes on disk are reclaimed instead of re-fetched from the swarm.

### What landed
- **`preallocate()` is now idempotent** in [Sources/SplynekCore/Torrent/TorrentWriter.swift](Sources/SplynekCore/Torrent/TorrentWriter.swift).
  Behaviour: missing file → create + truncate up; existing file at
  correct size → leave bytes alone; existing file smaller → truncate
  up (zero-fill tail); existing file bigger → truncate down. **No
  more removeItem.**
- **[Sources/SplynekCore/Torrent/PieceVerifier.swift](Sources/SplynekCore/Torrent/PieceVerifier.swift)** — extracted
  from the live-swarm `PeerCoordinator.acceptPiece` so the resume
  scanner and the swarm share one well-tested verifier. Carries a
  `resumeMode` flag: in resume mode, v2 magnets without piece
  layers refuse to verify (we can't pretend bytes are valid); in
  live-swarm mode, the same state accepts tentatively (the engine's
  existing behaviour — bytes arrived fresh from a peer).
- **[Sources/SplynekCore/Torrent/TorrentResume.swift](Sources/SplynekCore/Torrent/TorrentResume.swift)** — pure
  scan loop. Reads each piece via a new Sendable-friendly
  `TorrentWriter.read(info:rootDirectory:...)` static helper (no
  non-Sendable capture across the DispatchQueue), verifies via
  `PieceVerifier`, returns `(verifiedPieces: Set<Int>,
  bytesRecovered: Int64)`.
- **Engine wiring** — `TorrentEngine.run()` now phases in:
  `Announcing → Verifying existing pieces… → (swarm) → Done`. The
  scan is dispatched to `DispatchQueue.global(qos: .userInitiated)`
  so it doesn't stall the engine's cooperative Task. Verified pieces
  are fed into `picker.markDone(_:)` AND
  `seedingService.markPieceComplete(_:)` so partial-seed-while-leech
  sees them. If the scan restores the full torrent, we skip the
  swarm entirely and jump to the completion + seeding path.
- **Cancellation** — the scan respects `cancelFlag.isCancelled`
  (polled between pieces) so hitting Cancel during verification
  aborts promptly.

### Tests
9 new assertions in `TorrentResumeTests`:
- Full valid payload → every piece verified, bytes recovered match total length.
- Single-byte corruption rejects exactly one piece.
- Short final piece (BEP 3: final piece may be < pieceLength) is handled.
- Empty torrent info produces empty result.
- PieceVerifier resume-mode: correct v1 bytes verify; corrupt bytes don't.
- PieceVerifier resume-mode v2-magnet-without-layers: refuses to verify.
- PieceVerifier live-swarm mode v2-magnet-without-layers: accepts tentatively
  (regression guard so fixing resume doesn't regress the swarm path).

**Suite: 133 green (up from 124).**

### What this doesn't do yet
- **No per-piece mtime-based skip.** A full 10 GB torrent pays the
  SHA read+hash cost every startup. Cheap on SSD, noticeable on
  spinners. A future pass could persist a verified-piece bitmap
  alongside the torrent and skip re-hashing known-good pieces.
- **No partial-resume for v2-only magnets.** If you kill the app
  before the magnet's piece layers arrive, relaunching finds bytes
  on disk that `PieceVerifier` refuses to verify (can't
  authenticate). The swarm will re-fetch; once layers arrive, a
  rescan could be triggered manually. Not wired yet.

## What's new in v0.39 (Finer Gatekeeper signature panel)

The `gatekeeper` phase pill showed `accepted` or `rejected` — that was
all the detail a user got about what Splynek had just downloaded.
v0.39 fans the one-line verdict into a per-field signature panel so
the History detail sheet answers the questions that actually matter
for an unfamiliar `.app` / `.pkg` / `.dmg`: **who signed it, which
team, is it notarized, is the notarization stapled**.

### What landed
- **`GatekeeperDetail` struct** — `accepted`, `source`, `origin`,
  `authorities` (cert chain, outermost first), `teamID`, `cdHashSHA256`,
  `notarizationStapled: Bool?` (true/false/nil for offline-ambiguous),
  plus a `raw` blob concatenating the three tool outputs for the
  "Show raw" disclosure.
- **`GatekeeperVerify.parseDetail(...)`** — pure parser over merged
  stderr+stdout of `spctl`, `codesign -dv --verbose=4`, and
  `xcrun stapler validate`. Handles unsigned binaries (`TeamIdentifier=not set`
  → nil), missing tools (stapler absent → `notarizationStapled: nil`),
  and the three stapler failure modes (no ticket / validation failed /
  CloudKit unreachable).
- **`GatekeeperVerify.evaluateDetail(_:)`** — async wrapper that runs
  the three tools concurrently enough (well — serially, but each is
  fast on a completed file) and returns the parsed struct, or nil for
  file types Gatekeeper doesn't evaluate.
- **Signature card in [HistoryDetailSheet](Sources/SplynekCore/Views/HistoryDetailSheet.swift)** —
  shown only when the file is `.app` / `.pkg` / `.dmg` / `.mpkg`.
  Named fields: Source, Origin, Developer ID (first authority),
  Team ID, CDHash (truncated), Notarization ("Stapled (verified
  offline)" / "Not stapled" / "Unknown"). `ACCEPTED` / `REJECTED`
  pill in the card accessory. Terminal-icon button toggles a raw
  tool-output disclosure for diagnostics.
- **Lazy evaluation** — `.task` on the sheet kicks off
  `evaluateDetail` only once; spinner while it runs; result cached
  on `@State` so flipping the raw disclosure doesn't re-run the
  tools.

### Tests
7 new assertions in `GatekeeperDetailTests`:
- Accepted + notarized + stapled — all fields extracted from realistic
  canned spctl/codesign/stapler outputs.
- Rejected + unsigned — empty authority list, `TeamIdentifier=not set`
  normalised to nil, stapler missing-ticket → `notarizationStapled: false`.
- Authorities preserve cert-chain order (outermost first).
- Stapler non-zero exit + no-ticket sentinel → false.
- Stapler inconclusive ("xcrun: error: unable to find utility stapler")
  → nil, not a false positive.
- Raw blob carries all three tool outputs with stable section headers
  so support screenshots stay consistent across releases.
- `headline` summary renders the acceptance state + source + stapled
  state in one line.

**Suite: 124 green (up from 117).**

### What this doesn't do yet
- **No re-evaluation on staleness.** `GatekeeperDetail` runs once per
  sheet open. If Apple revokes the certificate mid-session, the
  cached pill doesn't flip — you'd need to close + reopen the sheet.
- **No background re-evaluation after app updates itself.** The panel
  only checks on user action, not periodically.
- **No trust-store details.** The "Apple Root CA" authority is taken
  at the codesign-report level; we don't fan out to the
  Security.framework trust-evaluation API for revocation or validity
  dates. Could be a v0.40+ pass.

## What's new in v0.38 (Usage timeline chart)

v0.37 wrote the history to disk. v0.38 renders it in-app — a stacked
bar chart of daily bytes with a Host / Cellular toggle, a window-size
menu, and a CSV export accessory that hands the live dataset to the
v0.37 formatter. No new source-of-truth changes; this is a pure
rendering pass over the history logs.

### What landed
- **[Sources/SplynekCore/UsageTimeline.swift](Sources/SplynekCore/UsageTimeline.swift)** — pure data-shaping
  helpers. `hostData(...)` picks top-N hosts by total bytes across
  the window (with an alphabetical tiebreak for determinism across
  renders) and rolls the rest into an `"Other"` series.
  `cellularData(...)` emits one point per day and splits the series
  name between `"Cellular"` and `"Cellular (over cap)"` so the
  over-budget days jump out in the legend.
- **[Sources/SplynekCore/Views/UsageTimelineView.swift](Sources/SplynekCore/Views/UsageTimelineView.swift)** — a
  SwiftUI Charts `BarMark` stacked on `x = date`, coloured by
  series. Today's bar is drawn at full opacity; history bars at 0.78
  so the current-day column pops. Segmented picker (Host / Cellular)
  + window-days menu (7 / 14 / 30 / 60 / 90) + an export-CSV button
  reusing the v0.37 VM helpers.
- **Wired into HistoryView** between the lifetime summary and the
  Today-by-host card. Shows an `EmptyStateView` when there's no
  activity yet (pre-first-download or pre-first-cellular-run).

### Tests
10 new assertions in `UsageTimelineTests`:
- Empty state emits no points (host) / always emits today (cellular).
- Top-N hosts picked by total bytes across the window.
- Today's points precede history points.
- `isToday` flag is only set on today's points.
- Zero-byte `Other` is suppressed when every host makes top-N.
- `lastNDays` caps the window for both variants.
- Top-N ties break alphabetically (regression guard against chart
  reshuffle between renders).
- Cellular over-cap series split matches the cap-vs-bytes rule.

**Suite: 117 green (up from 107).**

## What's new in v0.37 (CSV export — usage timeline lands on disk)

`HostUsage` and `CellularBudget` tracked today's byte tallies but
discarded yesterday's counters on every midnight roll-over. v0.37
preserves the rolled-day snapshot before the reset and ships an RFC
4180 CSV exporter so users can pull the timeline into Numbers / Excel
/ Sheets — for month-end reporting, for building a per-host bandwidth
chart, for forensics on "where did my hotspot plan go."

### What landed
- **History logs on roll-over.** `HostUsage.load()` and
  `CellularBudget.load()` both detect day-changes; v0.37 appends the
  closing snapshot to a dedicated `*-history.json` file before
  discarding the counters. Both logs are capped at 365 days so disk
  usage stays bounded indefinitely.
- **New persisted files** under `~/Library/Application Support/Splynek/`:
  - `host-usage-history.json` — list of `HostUsageDaily` (date +
    sorted entries)
  - `cellular-budget-history.json` — list of `CellularBudgetDaily`
    (date + total + cap-on-that-day, so post-hoc "was I over
    budget?" analysis stays honest even if caps change later)
- **[Sources/SplynekCore/UsageCSV.swift](Sources/SplynekCore/UsageCSV.swift)** — pure RFC 4180 formatter.
  Quotes fields containing `,` / `"` / `\r` / `\n`, doubles embedded
  quotes. Today's state comes first (most-recent-first answer to the
  "who used what" question), history rows follow reverse-
  chronologically. Within a day, hosts are sorted by bytes desc.
- **Export buttons** wired into:
  - **History → Today by host** card (`square.and.arrow.up` icon
    accessory on the card header).
  - **Downloads → Cellular budget** row (icon button after the OVER
    pill — only appears when a cellular lane is selected).
  - Both open an `NSSavePanel` pre-filled with a dated filename
    (`splynek-host-usage-2026-04-18.csv`).
- **VM helpers** — `exportHostUsageCSV()` / `exportCellularBudgetCSV()`
  on `SplynekViewModel`; use `UTType(filenameExtension: "csv")` so
  the save panel knows what kind of file it's writing.

### Tests
18 new assertions in `UsageCSVTests`:
- Header-only CSV for empty today, no history.
- Today's rows precede history rows in the output.
- Hosts within a day are sorted by bytes desc.
- `over_cap` flag honours `bytesToday >= dailyCap` (with cap > 0).
- Cellular: today always present, history reverse-chronological,
  over-cap flag matches the bytes-vs-cap rule.
- RFC 4180 escapes: plain pass-through, comma forces quoting,
  embedded `"` doubles, newline forces quoting, empty stays empty,
  full-formatter round-trip with a comma-bearing hostname.

**Suite: 107 green (up from 94).**

### What this doesn't do yet
- **No in-app timeline view.** Export writes the timeline; rendering
  a per-host bar chart in-app is a separate pass. CSV + Numbers
  covers the 80/20 for now.
- **No backfill.** The history log starts accumulating from v0.37;
  prior-day usage that was discarded pre-v0.37 is gone.

## What's new in v0.36 (Phase over REST)

The v0.35 integration test couldn't assert the pipeline order —
`/splynek/v1/api/jobs` didn't publish `DownloadProgress.phase`. v0.36
closes the gap: phase is now a first-class field on `ActiveJob`,
re-published on every transition via a Combine subscription so fast
downloads don't compress past the 2 Hz fleet-state timer.

### What landed
- **`phase: String`** added to `FleetCoordinator.LocalState.ActiveJob`.
  Sourced from `job.progress.phase.rawValue` in
  [Sources/SplynekCore/ViewModel.swift](Sources/SplynekCore/ViewModel.swift)'s `publishFleetState()`. Defaults
  to `""` for a pre-started job.
- **Per-job Combine subscription** on `job.progress.$phase` calls
  `publishFleetState()` immediately on transition — the 2 Hz timer
  alone would miss Probing → Planning → Connecting on a fast loopback
  download. Cancellable is torn down in the job's completion handler.
- **OpenAPI 3.1 spec updated** — `ActiveJob.phase` is listed as
  required, with an `enum` of all eight canonical values so generated
  clients can dispatch without string-compare drift.
- **CLI `splynek status`** now shows a `PHASE` column. The local
  `Decodable struct Job` keeps `phase: String?` so the CLI remains
  compatible with a pre-v0.36 Splynek (renders `—` if absent).
- **`Scripts/integration-test.py` upgraded** to collect the phase
  trail across polls and assert it's a monotonic subsequence of
  `["Queued", "Probing", "Planning", "Connecting", "Downloading",
  "Verifying", "Gatekeeper", "Done"]`. Poll interval tightened from
  500 ms → 100 ms so fast transitions land. Missing phases are a
  warning (`note: did not observe {'Downloading'} — loopback is fast`)
  rather than a failure, since on gigabit loopback the engine can
  compress phases past even a 100 ms poll. On a real-network test the
  full trail is observable.

### Tests
4 new assertions in `PhaseOverRESTTests`:
- ActiveJob JSON round-trips with phase populated.
- Phase strings exactly match `DownloadProgress.Phase.allCases`.
- OpenAPI spec lists phase in the required list + enum.
- Default phase is empty string.

**Suite: 94 green (up from 90).** Integration test passes end-to-end
with a monotonic `Planning → Done` trail on loopback.

### Why this unlocks more than the test script
- CLI `status` now tells you *what* Splynek is doing, not just
  how many bytes have arrived. Useful when a download stalls at
  0% — you can see if it's stuck in Probing (DNS / HEAD failing)
  vs. Planning (no interface picked) vs. Connecting (server down).
- Raycast / Alfred extensions can surface phase without a new
  endpoint. No changes needed there — they just start showing the
  field on their next release.
- Future `GetDownloadProgress` App Intent can include phase too.

## What's new in v0.35 (Integration tests + Watched folder — bets D & E)

Two items from the "do them all" queue landed together because they
share no code and both are small enough to ship in one pass: an
end-to-end REST integration test that would have caught v0.27's
silent-stale-binary regression, and a polled watched-folder ingester
that turns the app into a drop target.

### Bet D — End-to-end integration test
- **[Scripts/integration-test.sh](Scripts/integration-test.sh)** → wraps [Scripts/integration-test.py](Scripts/integration-test.py).
  Python 3 stdlib only — no third-party deps, tracks the zero-deps
  invariant.
- **What it does:**
  1. Stands up a local `http.server.ThreadingTCPServer` on a free
     port serving a deterministic 2 MiB SHA-256-known payload.
  2. Reads `~/Library/Application Support/Splynek/fleet.json` for
     port + token (optionally launches `build/Splynek.app` first
     via `--launch`).
  3. `POST /splynek/v1/api/download?t=<token>` with the URL.
  4. Polls `/api/jobs` until the job disappears, then confirms the
     entry lands in `/api/history` with the expected total-bytes.
  5. SHA-256-compares the file on disk.
  6. Cleans up the downloaded artefact + its `.splynek` sidecar.
- **Binds the payload server to the machine's primary LAN IP** (via
  a UDP-connect trick to discover the outbound interface) instead of
  127.0.0.1. Splynek pins outbound connections to `NWParameters
  .requiredInterface`, and 127.0.0.1 would route through `lo0`
  which never matches the chosen Wi-Fi / Ethernet interface — the
  job stalls at 0 bytes. Using the real LAN IP hairpins the request
  back through the correct route.
- **Honest limitation called out in the script header**: phase
  transitions (Probing → Planning → Connecting → Downloading →
  Verifying → Gatekeeper → Done) aren't exposed over REST, so we
  assert the transport-level equivalent (job appeared, bytes grew,
  history landed, SHA-256 matches) rather than the literal phase
  strip. Exposing phase over REST is a future change.
- First green run:
  ```
  ✓ job disappeared from /api/jobs after 1 progress ticks
  ✓ history entry present with totalBytes=2097152
  ✓ sha256 matches expected (0353e5bfa008…)
  ✓ integration test passed
  ```

### Bet E — Watched folder
- **[Sources/SplynekCore/WatchedFolder.swift](Sources/SplynekCore/WatchedFolder.swift)** — polled ingester
  (`DispatchSourceTimer`-equivalent `Timer`, 5 s interval) with a
  2-second file-age floor so mid-write drags don't trip the parser.
- **Default folder**: `~/Splynek/Watch/`. User-configurable via the
  Settings card. Handled files are moved to a `processed/`
  subdirectory with a Unix-timestamp prefix so each drop is traceable
  and never re-ingested.
- **Accepted file types**:
  - `.txt` — one URL (or magnet) per line; `# comments` and blank
    lines skipped; HTTP(S) → queue, magnets → populate the torrent
    UI state but don't auto-start the swarm (user picks an interface).
  - `.torrent` — parses via `TorrentFile.parse`; UI shows the Start
    button on the Torrents tab.
  - `.metalink` / `.meta4` — parses via `Metalink.parse`; first
    mirror goes into the queue with the declared SHA-256 pre-filled.
- **Settings card** between Schedule and Background. Toggle, folder
  picker, Reveal-in-Finder button.
- **Session persistence** — `watchEnabled` + `watchFolderPath` live
  in `UserDefaults`; `refreshWatcher()` runs on init so a toggled-on
  watcher survives app restarts.

### Tests
- 8 new assertions in `WatchedFolderTests` pin the pure parser:
  single-URL, multi-line, blank/whitespace/`#`-comment skipping,
  magnet pass-through, unsupported-scheme drop, plain-garbage drop,
  handled-extensions set. **Suite: 90 green (up from 82).**

### What this doesn't do yet
- **No phase exposure over REST.** The integration test asserts bytes,
  not phase transitions. A future pass could add a `phase` field to
  `LocalState.ActiveJob` in `FleetCoordinator`.
- **No RSS ingestion.** Watched folder was the 80/20; RSS is a
  separate ingress point the watcher doesn't cover.
- **No FSEvents.** 5-second polling is "good enough"; FSEvents can
  replace the Timer later without touching the parser or move-to-
  processed logic.

## What's new in v0.34 (Scheduled downloads — bet C)

"Only start downloads overnight on home Wi-Fi" was the most requested
policy gap in v0.33's queue. v0.34 adds a global `DownloadSchedule`
that sits between the queue scheduler and `start()`: window open →
runs the next pending entry; window closed → holds everything until
the window opens, then resumes on its own without UI interaction.

### What landed
- **`DownloadSchedule` model** in [Sources/SplynekCore/DownloadSchedule.swift](Sources/SplynekCore/DownloadSchedule.swift).
  Fields: `enabled`, `startHour`, `endHour`, `weekdays: Set<Int>`,
  `pauseOnCellular`. Persisted as `schedule.json` alongside the other
  session state under `~/Library/Application Support/Splynek/`.
- **Pure evaluator** — `evaluate(at:calendar:onCellular:) → .allowed
  / .blocked(reason, nextAllowed)`. Midnight-wrapping windows
  (e.g., 22:00–06:00) handled natively; weekday set uses
  `Calendar.weekday` values (1 = Sunday). Every branch is unit-tested.
- **ViewModel integration** — `runNextInQueue()` now short-circuits on
  `.blocked`; a 60-second retry timer re-enters the method so the
  window opening wakes the queue without a user poke. Setter routes
  through `updateSchedule(_:)` so persistence + immediate retry are
  one call.
- **Settings card** — "Download schedule" between AI and Background.
  Enable toggle, start/end-hour pickers (hours 0–23 / 1–24), Mon→Sun
  weekday chips with Weekdays/Every-day shortcuts, Pause-on-cellular
  toggle, live "window is open" / "next opening in 3h" status row.
  WRAPS MIDNIGHT pill appears when start > end.
- **Queue badge** — the head-of-queue pending entry gets a WAITING
  pill and "Next opening 4h" caption when the schedule is blocking.
  Every other entry renders as before.

### Tests
16 new assertions in `DownloadScheduleTests` cover: disabled schedule,
inside/at-edge/outside simple windows, midnight-wrapping windows at
morning and late-night, weekday exclusion, empty weekdays set,
cellular on/off gating, next-opening rollover, and the summary-label
strings. All tests run against a synthesised UTC calendar so they're
timezone-independent. **Suite: 82 green (up from 66).**

### What this doesn't do yet
- **No per-item schedules.** One global rule set. Per-torrent or
  per-URL schedules can come later once a user asks for them.
- **No grace-period pause on window close.** An in-flight job
  continues running past `endHour`. The schedule gates *starts* only.
  Mid-run throttling would need an engine-level callback pass.
- **No bandwidth-tier schedules** (e.g., "50 % throttle during
  business hours"). Call this v0.35+ if someone actually wants it.

## What's new in v0.33 (Torrent Live — bet B)

The `Live` dashboard was HTTP-only in v0.31. Torrents had their own
Progress card in the Torrents tab, but you couldn't glance at the Live
view and see what the swarm was doing. v0.33 closes the gap with a
dedicated `TorrentLiveCard` that sits above the HTTP job cards whenever
`vm.isTorrenting` is true.

### What landed
- **`TorrentLiveCard`** in `Sources/SplynekCore/Views/LiveView.swift`.
  Reuses the 72-pt headline + big-metric + phase-strip grammar of
  `LiveJobCard` so the two transports read the same story.
- **Shared pipeline vocabulary** — `TorrentLivePhase` has six cases
  (`announcing` → `fetchingMetadata` → `connecting` → `downloading`
  → `seeding` → `done`) that collapse `TorrentEngine`'s freeform
  `progress.phase` strings onto a stable pill set. The mapper is a
  pure function (primitives in, case out) so regressions are unit-
  testable instead of waiting for a real swarm to reproduce them.
- **Torrent-native metrics** — pieces done / total, active / known
  peers, percentage complete. `ENDGAME` and `SEEDING` pills hoist to
  the title row so you spot them at a glance.
- **Throughput sampling** — `TorrentRateSampler` observes
  `progress.downloaded` on a 1-Hz timer and derives a smoothed
  bytes-per-second over an 8-second rolling window. The engine doesn't
  publish a rate directly (pieces arrive in bursts), and samplers
  owned by the card avoid polluting `TorrentProgress` with view-
  specific state.
- **Seeding strip** — when `progress.seeding?.listening` is true, a
  subtle inline row shows port, connected leechers, bytes uploaded,
  and uptime. No separate card; the existing Torrents tab still has
  the full Seeding card for detail.
- **Cancel button** on the card calls `vm.cancelTorrent()` so you
  don't have to leave the Live tab to stop a run.
- **Empty state** updated — "No active downloads" now only shows when
  both HTTP and torrent activity are idle.

### Tests
10 new assertions in `LiveTorrentPhaseTests` pin the phase mapping
against every string the engine actually emits (`"Announcing to
trackers…"`, `"Probing DHT…"`, `"Fetching metadata (BEP 9)…"`,
`"Connecting to peers…"`, `"Seeding."`, `"Seeding stopped."`,
`"Done."`) plus the `piecesDone > 0` override that moves the pipeline
forward even when the engine leaves the freeform string unchanged.
Full suite: **66 tests, all green.**

### What this doesn't do yet
- No per-peer card grid. The Torrents tab has a single aggregate
  peer count; drilling into individual peer addresses is still a
  future pass.
- No throughput sparkline on the torrent card — the HTTP side uses
  per-lane charts backed by `LaneStats`; the torrent side would need
  the engine to publish per-peer stats. Out of scope for bet B.

## What's new in v0.32 (distribution pass — the repo goes public-ready)

The first release where "Splynek" is a thing that can actually leave
`~/Claude Code/`. All app code was already built; this pass is the
repo-shaped wrapper around it.

### What landed
- **Git repo initialised** on `main` with a single "initial public
  commit" + a **second commit** containing distribution artefacts
  + a **tag `v0.31`** on the last in-app feature release (Live
  dashboard, history detail, projection chip).
- **`LICENSE`** — MIT.
- **`CONTRIBUTING.md`** — onramp + architecture invariants copied
  forward from `HANDOFF.md` + style rules + "what we won't accept."
- **`.gitignore`** — excludes `.build/`, `build/`, Branding
  intermediates, Raycast `node_modules`, editor noise.
- **`docs/index.html`** — single-file GitHub Pages landing. Dark
  hero with the v0.31 logo at 128 px, six pitch cards, a
  single-vs-multi bandwidth-bar proof section, feature grid,
  install CTAs. GitHub Pages will serve it straight from `docs/`
  once the remote is added.
- **`SHOW_HN.md`** — launch-post draft with three title candidates,
  timing guidance, body copy, and **pre-seeded comment replies**
  for the HN questions that will inevitably land (aria2, FDM,
  2–3× claim, hostile-peer handling, public P2P, Mac App Store).
- **`build/Splynek.dmg`** — 2.1 MB compressed DMG of the v0.31
  `.app`, produced via `Scripts/dmg.sh`. SHA-256:
  `706aaee036b4a82e6daaef5663c55c1fdc80a8edff4ca020ba76739f22ea24d9`
  — paste into the Homebrew cask template once the release is
  hosted.

### Still local — no push yet
Nothing has been pushed. `git remote` is empty. To publish:

```sh
# on GitHub: create an empty "splynek/splynek" repo
cd /Users/pcgm/Claude\ Code
git remote add origin git@github.com:splynek/splynek.git
git push -u origin main
git push origin v0.31
# upload build/Splynek.dmg as an asset on the v0.31 Release
# Settings → Pages → Source: Deploy from branch → main / docs
```

### What's NOT in this release (tracked for v0.33+)
The "do them all" plan from the previous session had five items:

| Bet | Status |
|---|---|
| A — Distribution pass                    | **v0.32 ✓** (this release) |
| B — Torrent side of Live dashboard       | NOT started |
| C — Scheduled downloads                   | NOT started |
| D — Integration tests (REST API + local server) | NOT started |
| E — Watched-folder ingestion (FSEvents)   | NOT started |

Each is a fresh top-of-stack todo for the next session. See
`HANDOFF.md § Natural next bites`.

## What's new in v0.31 (the three Mush-inspired wins)

After a side-by-side look at a competitor (Mush), three of its UX
choices were clearly right. Skipped the four that were theatre.

### 1. `Live` — dedicated dashboard for active downloads
New sidebar section in the Active group. One card per running (or
paused) download, each with:

- **72-pt MB/s headline**, unit split into display/heavy typography.
- **Transport controls** — Pause / Resume / Cancel right on the card.
- **Phase strip** — pill-per-stage pipeline showing the engine's
  progress through Queued → Probing → Planning → Connecting →
  Downloading → Verifying → Gatekeeper → Done. Completed stages go
  green, current one is accented, upstream dimmed.
- **Per-interface cards** in a responsive grid — big throughput
  number, chunks done, share percentage, RTT, FAILOVER pill.
- Metrics row: phase / % / bytes / ETA.

Sidebar accessory shows a green `NOW` pill whenever `vm.isRunning`.

Backed by a new `DownloadProgress.phase` property
(`Phase.pending / probing / planning / connecting / downloading /
verifying / gatekeeper / done`), wired into `DownloadEngine.run()`
at each stage transition so the Live view reflects what the engine
is actually doing, not just the chunk count.

### 2. History detail sheet
Double-click any History row (or click the new info button) to
open a sheet with:

- **Big speedup factor** reconstructed from `HistoryEntry.secondsSaved`
  — the "1.8×" that used to vanish with the completion banner.
- **Interface-contribution stacked bar** + per-lane breakdown with
  percentages and bytes, colour-coded.
- **Duration / time-saved / avg throughput** metric trio.
- **Reveal / Open / SHA-256 / full path** details.

New file: [HistoryDetailSheet.swift](Sources/SplynekCore/Views/HistoryDetailSheet.swift).

### 3. Projected split chip on the Downloads form
When you paste a URL and Splynek has prior history against that
host, a subtle chip slides in between the Source card and the
Options card showing how it expects to split the download across
currently-selected interfaces, with a projected aggregate
throughput. Data is pulled from `DownloadHistory.laneProfile(host:)`
— the same signal v0.17's *interface preference learning* already
records. Live-updates as the user toggles interfaces on and off.

### What we deliberately didn't copy from Mush
- **Threads per interface at 100.** Marketing theatre — 100 TCP
  connections per NIC creates self-inflicted congestion; origins
  cap at 6–10. Splynek stays at its reasonable cap of 8.
- **User-tunable scheduler weights / modeler-alpha.** Implies a
  tuning surface that only makes sense if there's an ML scheduler
  the user needs to calibrate; adds complexity without value.
- **Destination IP:port setting.** Only relevant for
  single-endpoint benchmarking, not general URL fetching.
- **Dedicated Dry Run Mode.** Splynek's Benchmark tab already
  does "measure throughput without keeping bytes."

### Tests + build
Still 56 tests green (`swift run splynek-test`). Release build
clean. Live section shows up in the sidebar with a `NOW` pill
when a job is running, phase strip animates through stages as the
engine transitions, and `DownloadHistory.laneProfile` feeds the
projection chip without any new persistence.

## What's new in v0.30 (structure + legal — round 2 of live-user feedback)

Five direct asks from the previous review, all addressed. No new
features — structure and polish.

### 1. Chrome-extension button actually opens Finder now
The old code used `activateFileViewerSelecting(_:)`, which opens
the *parent* folder with Chrome highlighted — many users read
that as "nothing happened." Now `NSWorkspace.open(url)` on the
folder URL opens straight into it. New `presentMissingAssetAlert`
path replaces the silent `formErrorMessage` write so About
doesn't swallow errors anymore.

### 2. Logo: design brief instead of another attempt
Rather than throw another iteration at the wall, v0.30 ships
[DESIGN_BRIEF.md](DESIGN_BRIEF.md) — a designer-ready spec
covering concept, audience, palette, surface treatment, what to
AVOID (three-converging-lines, bright primary blue, cute
literals), reference icons to study, and an acceptance checklist.
Hand it to a designer or use it yourself in Affinity / Figma.

### 3. Titles + subtitles unified — `PageHeader`
Every view now renders a single `PageHeader` block at the top of
its scroll area: SF symbol + large rounded title + one-line
subtitle + a 1-pixel divider below. The navigation bar's
`navigationTitle` still sets the window title for ⌘W behaviour,
but the visible identification is the in-content header — no
more disconnected toolbar-label + separate explainer row.
Applied to Downloads, Torrents, Queue, Fleet, Benchmark, History,
Concierge, Settings, Legal.

### 4. About split into three sidebar sections
About was doing too much. Now:

- **About** — brand hero, Splynek name + version, feature grid
  (6 tiles), optional update banner, legal-shortcut pointer.
  That's it.
- **Settings** — new sidebar entry. *Browser helpers*, *Web
  dashboard with QR*, *Local AI*, *Background mode*, *Security &
  privacy* — all the things you actually *configure*. Five cards
  in a single column, all identical weight.
- **Legal** — new sidebar entry. In-app Markdown viewer for the
  three bundled legal docs (see below).

Card borders were weak (0.08 alpha); bumped to 0.16 + a subtle
drop shadow so each card clearly delineates from the window
background. Affects every view, not just About.

### 5. Legal protection — the real deal
New sidebar section backed by three bundled Markdown docs under
[Resources/Legal/](Resources/Legal/):

- **[EULA.md](Resources/Legal/EULA.md)** — End-User Licence
  Agreement. 11 sections: licence grant, ownership, restrictions,
  LAN-fleet-specific carve-out (you are responsible for what
  your Mac shares with LAN peers), AI disclaimer, warranty
  disclaimer, **liability cap at €5** or whatever you paid
  (whichever is greater), indemnification by user, termination,
  governing law (Portugal — swap to match your billing entity),
  miscellaneous.
- **[PRIVACY.md](Resources/Legal/PRIVACY.md)** — covers what
  Splynek doesn't collect (the list is long), what it stores
  locally, what it reveals over LAN Bonjour, and the local-AI
  integration posture.
- **[AUP.md](Resources/Legal/AUP.md)** — Acceptable Use Policy.
  Explicit bans on CSAM, malware, copyright infringement,
  infrastructure abuse, privacy violations, and fleet-feature
  abuse. Clear consequences (licence termination) + a "what if
  you're not sure?" escape hatch.

In-app `LegalView` renders the docs with a segmented picker,
reads them from the .app bundle's `Resources/Legal/` via
`Bundle.main.resourceURL`, and ships a hand-rolled Markdown block
parser so headings + bullets + numbered lists render correctly
(SwiftUI's `AttributedString(markdown:)` handles inline markup
but not block structure). Includes a *Reveal in Finder* action
and a *mailto:info@splynek.app* contact button.

**Important caveat in the docs themselves**: they are templates
provided in good faith. Before shipping commercially, have
qualified legal counsel review them for your specific
jurisdiction + business structure. Surfaced prominently at the
bottom of LegalView's contact card so users know the quality of
the cover they're getting.

Tests still 56 green. Release build clean. `fleet.json` writes,
the Chrome extension button opens into the folder, the legal
docs render, the Settings sidebar is populated.

## What's new in v0.29 (polish pass — UX fixes from live-user feedback)

Short targeted pass after watching the v0.28 build get actually
used. Four real issues + one confession.

### 1. Cancelled-job tombstones no longer linger
Before: cancel a download, hit Start on a new URL, the old red
"Cancelled" card sat next to the new live card until you
manually cleared it. That was confusing UX. Fix in
`SplynekViewModel.start()` — a one-liner that sweeps all
`.cancelled` and `.failed` jobs out of `activeJobs` at the top of
every new start. Completed (`.completed`) jobs stay, because
they're successes and the user may want to Reveal the file.

### 2. Every view now has an explainer line at the top
New `ViewExplainer` component in
[Components.swift](Sources/SplynekCore/Views/Components.swift) —
small SF symbol + one-line caption in secondary colour. Injected
above the first card in Downloads, Torrents, Queue, Fleet,
Benchmark, History, and Concierge (once a conversation is
active). New users always know what the current pane is for
without a tutorial.

### 3. Logo redesign — refined, Apple-ish
Previous logo read like a chart: three converging diagonals +
arrow + bar on bright blue. New design drops the diagonals
entirely — a single elegant down-arrow with rounded shaft and
tapered head on a deep dusk-blue gradient (navy → near-black),
with a gentle top-left glass highlight, a bottom-right vignette,
and a thin low-opacity landing bar. Closer in spirit to the Mail,
Safari, and Music icons. New generator at
[Branding/generate_logo.py](Branding/generate_logo.py) —
still pure-stdlib Python, no Pillow.

### 4. The confession
The Ubuntu download that appeared during the v0.28 screenshot
tour was me clicking the Concierge's "Download the latest Ubuntu
desktop ISO" suggestion chip while demoing. The AI query was me
too. Neither was automation — they were my test of the live
dispatch path. I should've cancelled them before handing back
the keyboard.

### Tests + build
Still 56 green (`swift run splynek-test`). Release build clean,
smoke-verified the fleet descriptor writes, the explainer rows
render, and the new icon lands in the Dock and the About hero.

## What's new in v0.28 (product + business pass)

Five asks from the roadmap session, landed together:

### 1. Brand logo
Pure-stdlib Python generator at `Branding/generate_logo.py` produces
a full `.iconset` (16 → 1024 px, @1x + @2x) + `Splynek.icns`. Design:
rounded-square (Apple superellipse), blue → indigo vertical gradient,
three diagonal lines converging on a bold white down-arrow above a
horizontal "file" bar — tells the multi-path-to-one story at a
glance, reads cleanly at 16×16. Wired into `Resources/Info.plist`
via `CFBundleIconFile`, bundled by `Scripts/build.sh`, surfaced in
AboutView's hero, and propagated to the Chrome extension + Raycast
assets so every surface shows the brand.

### 2. UI / UX audit — top wins

- **First-paint brand strip** on `DownloadView` when there's no
  history + no active jobs + no URL typed. Users land on a form;
  new users land on a hero + tagline + form.
- **AI upsell row** (purple-tinted) for users without Ollama, during
  their first few downloads. Links straight to ollama.com. The AI
  value prop is visible to 100% of users, not just those already
  set up.
- **Live throughput in the sidebar's Downloads row** — compact
  `"1.4MB/s LIVE"` instead of a bare `LIVE` pill. Sidebar now
  tells you what's happening without switching tabs.

### 3. AI Concierge — new sidebar section

`ConciergeView` is a chat-first entry point that hits a single
model pass to classify the utterance into one of six actions —
`download / queue / search / cancelAll / pauseAll / unclear`. Same
Ollama instance as v0.25's URL resolver + v0.27's history search,
now unified. Every other tab becomes optional: "download the latest
Ubuntu ISO", "add kernel.org's stable to the queue", "what did I
download from github last week?", "cancel everything" all route to
the right VM method with no manual navigation. Empty-state hero with
four clickable suggestion chips makes discovery effortless. If
Ollama isn't installed, the view pitches + links to
ollama.com/download.

### 4. Security / privacy hardening

Three new user-facing controls in *About → Security*:

| Control | What it does |
| --- | --- |
| Privacy mode | Fleet `/status` returns empty `active` + `completed` to LAN peers. Cooperative cache disabled. |
| Loopback only | Fleet listener binds to 127.0.0.1 at next launch. Phone can't reach the dashboard. |
| Regenerate token | 16-byte fresh secret, invalidates any shared QR immediately. |

Plus **per-IP sliding-window rate limiter** on the fleet listener —
60 requests per 10-second window. Overflow = 429 Too Many Requests.
Live-verified: 65 curls in a loop produced `first=200 last=429`.

New [SECURITY.md](SECURITY.md) documents the ten-threat model
(T1–T10) + mitigations + "what we deliberately don't do"
(no telemetry, no silent updates, no cloud sync, no DRM phone-home).

### 5. Monetization strategy

New [MONETIZATION.md](MONETIZATION.md) — honest analysis of pricing,
distribution, and the €99 question. Summary:

- **Model**: freemium + one-time **$29 Pro** (AI Concierge, mobile
  web dashboard, fleet beyond 2 devices, scheduled downloads,
  priority support) + a **Splynek Teams** subscription at $4 /
  seat / month (annual) for the small-studio persona.
- **Distribution**: MAS as primary, direct DMG + Stripe/Paddle as
  secondary, Homebrew cask as a free-tier driver.
- **The €99 truth**: you cannot make money from a Mac app without
  an Apple Developer account. The "zero-risk" stance is
  incompatible with any revenue path. €99/year is the cost of
  entry; y1 realistic revenue ranges from $1k (no signal) to ~$68k
  (HN front page + a Mac-focused publication).
- **First 90-day plan** with week-by-week milestones from "pay the
  €99" to "ship Pro gating".

### Tests

+2 new Concierge-specific tests. **56 total, all green** via
`swift run splynek-test`.

### Build.sh fix

`./Scripts/build.sh` now explicitly builds `--product Splynek`
(added in v0.27) and copies `Resources/Splynek.icns` into the
bundle. Verified with a live launch producing a valid `fleet.json`
on the first run — no more silent staleness.

## What's new in v0.27 (the platform pass — zero-risk distribution kit)

Five bets from the splash-inventory shipped together, all strictly
local, all without the €99 Apple Developer fee:

- **Documented REST API** at `/splynek/v1/api/*`, served on the same
  port the v0.24 web dashboard uses. Five new endpoints — `jobs`,
  `history`, `download`, `queue`, `cancel` — with a full OpenAPI
  3.1 spec served at `/splynek/v1/openapi.yaml`. Token-gated on
  mutating endpoints, open on reads (same posture as fleet LAN).
- **`splynek` CLI** — a new SPM executable target `splynek-cli`.
  Subcommands: `download <url>`, `queue <url>`, `status`,
  `history`, `cancel`, `openapi`, `version`. Discovers the running
  app via `~/Library/Application Support/Splynek/fleet.json`
  (port + token, auto-written on listener bind).
- **Raycast extension** in [Extensions/Raycast/](Extensions/Raycast/):
  `Download URL with Splynek` + `Queue URL in Splynek` (both
  no-view, clipboard-driven) and a live `Splynek Downloads` view
  that polls `/api/jobs`. `⌘⏎` from Raycast is now a first-class
  Splynek entry point.
- **Alfred workflow** in [Extensions/Alfred/](Extensions/Alfred/):
  keywords `dl`, `dlq`, `dlstatus` via a bash script that reads
  the fleet descriptor with JXA (no jq / python dep).
- **Three new App Intents** — `CancelAllDownloadsIntent`,
  `PauseAllDownloadsIntent`, `ListRecentHistoryIntent`. Together
  with the v0.12 intents, the Shortcuts surface now covers every
  load-bearing action.
- **AI second act — natural-language history search.** The VM's
  `aiAvailable` surface now extends to HistoryView: a purple
  sparkle input takes "that docker iso from last Tuesday" and the
  local LLM ranks matching entries. Same `AIAssistant` actor, same
  Ollama model, no embedding index — a ~6 KB JSON projection of
  the last 200 history rows plus a strict system prompt.
- **Benchmark *Save image…*** — renders a 1200×630 OG-aspect PNG
  (`BenchmarkImage.render`) with the N× headline, a per-interface
  bar chart, the device name, the URL, and a timestamp. One click,
  ready to paste into Twitter, Bluesky, LinkedIn, or a Slack.
- **Distribution materials**: `Scripts/dmg.sh` packages the .app
  into a compressed DMG with an /Applications symlink; a Homebrew
  cask template at `Packaging/splynek.rb`; a public-facing
  `LANDING.md` pitch; a consolidated `CHANGELOG.md` covering
  every release back to v0.1.

Also fixed during this pass: `./Scripts/build.sh` was silently
shipping stale binaries when the test target failed to compile under
`-c release` (the `@testable import SplynekCore` requires debug mode).
The script now builds only `--product Splynek` for the bundle and
defers tests to `swift run splynek-test`.

### 9 new tests (54 total, all green)

`splynek-test` now exercises the OpenAPI spec shape (paths,
schemas, token parameter on all mutating endpoints) and the
FleetDescriptor round-trip. Running the suite:

```
$ swift run splynek-test
…
  OpenAPI spec
    ✓ Declares OpenAPI 3.1
    ✓ Lists every routed path
    ✓ Documents the token parameter
    ✓ Declares every schema referenced in paths
    ✓ Mutating endpoints require the Token parameter
  Fleet descriptor
    ✓ Descriptor lives under Application Support / Splynek
    ✓ Descriptor round-trips via Codable
✓ 54 tests passed
```

### Smoke-test transcript

```
$ cat ~/Library/Application\ Support/Splynek/fleet.json
{ "deviceName": "MacBook Pro de Paulo", "port": 52904,
  "token": "6b9eda…", "schemeVersion": 1, ... }

$ swift run splynek-cli version
splynek-cli 0.27.0
  app: MacBook Pro de Paulo on :52904

$ curl /splynek/v1/api/jobs           → 200 []
$ curl /splynek/v1/openapi.yaml       → 200 openapi: 3.1.0
$ curl -XPOST /api/download?t=<tok>   → 202 Accepted
```

## What's new in v0.26 (the credibility sprint — 47 tests, all green)

v0.25 was the last splash. This pass is the one where the splashes
become defensible. Until v0.26 the README's performance claims and
"BEP 52 verified" bullets were things Splynek could do, but nothing
proved they still worked on the next commit. Now they do.

- **Package restructured** into a `SplynekCore` library + thin
  `Splynek` executable shim (`Sources/Splynek/main.swift` is three
  lines). Everything the UI, engine, torrent stack, fleet
  coordinator, web dashboard, and AI assistant need now lives in
  a library target that a test runner can `@testable import`.
- **Self-hosted test runner.** Command Line Tools ships neither
  XCTest nor a working Swift-Testing path when Xcode isn't
  installed, so the project builds its own: a 60-LOC assertion
  harness (`TestHarness.suite` / `test`, `expect` / `expectEqual`)
  plus an executable target `splynek-test`. `swift run splynek-test`
  builds + runs + prints `✓` per test and exits non-zero on failure.
  No framework dependency, no toolchain gymnastics.
- **47 tests, all green.** Covers:
    - **Merkle** (8) — domain-separated leaf + pair hash, root shapes,
      proofs verify + reject corruption, MerklePublisher end-to-end.
    - **Bencode** (8) — integer + bytes + list + dict round-trips,
      literal wire formats, sorted dict keys, trailing-garbage
      rejection, info-dict byte-range recovery (load-bearing for
      v1 info-hash computation).
    - **Magnet** (7) — v1 hex, v1 base32, v2 `urn:btmh:1220<hex>`,
      hybrid prefers v1 for handshake, rejection of non-magnet /
      missing xt / wrong multihash prefix.
    - **BEP 52 verify** (5) — full-sized piece against reference
      Merkle subtree root, short-final-piece zero-leaf padding,
      verifyPiece acceptance + corruption rejection + multi-piece
      layer indexing.
    - **Duplicate detection** (4) — empty history, missing file
      on disk, positive match, most-recent-wins.
    - **Sanitize** (7) — path-traversal (../), leading dots,
      backslash neutralization, null bytes, empty fallback, length
      truncation preserving extension, passthrough of safe names.
    - **Web dashboard** (6) — HTML contract assertions (UTF-8,
      viewport, polling URL, token-gated submit, dark-mode), plus
      the `LocalState` Codable round-trip.
    - **QR code** (2) — non-nil output for realistic LAN URLs,
      empty-input safety.
- **README + HANDOFF** — invariants #6 updated to reflect the
  test runner. Every future contributor / AI session sees
  `swift run splynek-test` as the standard verification step.

Running the suite:

```
$ swift run splynek-test
Splynek tests — 2026-04-17T17:05:31Z

  Merkle tree
    ✓ Leaf hash is domain-separated with 0x00 prefix
    ✓ …
  …
✓ 47 tests passed
```

Implementation notes:

- **Why not XCTest.** CLT doesn't ship a working XCTest runtime
  on this setup. Installing Xcode.app (12+ GiB) would technically
  fix it but violates the "Xcode-optional" invariant.
- **Why not Swift Testing.** The `Testing.framework` ships with
  CLT, but SPM's auto-discovery of the framework path only works
  when `xcode-select -p` points at Xcode.app. We got as far as a
  passing link by manually plumbing `-F` + two `-rpath` flags,
  but the test bundle then dlopened a `lib_TestingInterop.dylib`
  at a path that existed, still refused to load via xctest
  harness, and in general behaved like unsupported territory.
  Forty more minutes of framework archeology vs. sixty lines of
  a hand-rolled runner that always works: the runner won.
- **What the harness gives up.** No XCTest-style discovery; tests
  are wired explicitly in `main.swift`. No parallel execution (not
  needed at this size). No attachments / failure-on-first-error
  flags. Everything else (grouped output, useful failure
  messages, clean exit codes) is there.

## What's new in v0.25 (local-AI download assistant — "describe it in English")

No other download manager does this. Every 2026 pitch deck needs an
AI story — Splynek's is that the LLM running on your own machine
(Ollama, detected automatically on `localhost:11434`) understands
what you want and hands you the direct URL. Private, free, offline,
no €99.

Demo in ten seconds: type *"the latest Ubuntu 24.04 desktop ISO"* →
`llama3.2:3b` returns
`https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso` →
the URL drops into the form with a green rationale pill and the
model name in a monospace badge. Press Start.

Verified against a live Ollama during development (via the same
payload the app sends) — `llama3.2:3b` resolved the example prompt
to the correct direct download URL in ~1 s.

What landed:

- **[AIAssistant.swift](Sources/Splynek/AIAssistant.swift)** — actor-
  isolated client for Ollama's REST API. `detect()` polls `/api/tags`
  with a 3 s timeout, picks a model from a preference list
  (`llama3.2`, `llama3`, `gemma3`, `gemma`, `qwen`, `mistral`,
  `phi`), and reports `.ready(model:)` / `.unavailable(reason:)`
  back to the VM. `resolveURL(_:)` POSTs to `/api/generate` with
  `format: "json"` + `temperature: 0.1` + an explicit system prompt
  that instructs the model to emit
  `{"url": "...", "rationale": "..."}` or
  `{"error": "..."}` when unsure. Validates the URL is http(s) and
  has a host before surfacing. Rejection ≠ silent failure.
- **VM wiring** — new `aiAvailable`, `aiModel`, `aiThinking`,
  `aiRationale`, `aiErrorMessage`, `aiUnavailableReason` published
  props. `resolveViaAI(_:)` runs detection at launch and on a
  Refresh button. The resolved URL populates the URL field; the
  enrichment debounce + duplicate-detection paths fire exactly as
  they would for a paste — the LLM is just a keyboard, the engine
  sees a normal URL.
- **DownloadView AI row** — purple-tinted input appears *above*
  the enrichment pills, *below* the classic URL field. Only
  rendered when `vm.aiAvailable`. Shows a spinner while thinking,
  a green-check rationale pill on success (with the model name in
  a monospace capsule), an orange warning row on refusal. Submit
  on Return or the sparkle button.
- **AboutView AI card** — status (detected model / "not detected"
  + reason), Refresh button, and when Ollama is missing a
  *Install Ollama* button opens `ollama.com/download` in the
  default browser. Zero-friction onboarding.

Design notes:

- **Never auto-downloads.** LLMs hallucinate URLs. Splynek puts the
  resolved URL in the form and waits for the user's explicit Start.
  A wrong suggestion wastes a click, not a download.
- **Private by construction.** The LLM is on the user's machine.
  No cloud calls, no API keys, no telemetry. A user who doesn't
  have Ollama installed sees no AI surface at all — the row
  quietly doesn't render.
- **Model-agnostic.** Any Ollama model works. `llama3.2:3b` (2 GB,
  ~1 s per query on Apple Silicon) is ideal; gemma3 / mistral /
  phi all work too. Picking a model is first-hit over the family
  preference list.
- **System prompt is load-bearing.** Explicit `{"error": ...}`
  escape hatch means the model can decline rather than hallucinate
  — critical for trust. The `format: "json"` flag makes the
  response a guaranteed valid JSON object, no regex parsing.
- **Assistant is additive.** The classic URL field is unchanged.
  Drag-drop, scheme handler, menu-bar popover, web dashboard,
  Shortcuts, browser extensions — every existing ingress works
  exactly as before.

Why this makes the next-big-thing argument:

Splynek now has:
  - multi-interface aggregation (v0.1–v0.17)
  - native BitTorrent with v2 support (v0.19)
  - LAN content-addressed cache + cooperative chunk trading (v0.20)
  - browser extensions (v0.21)
  - background-first operation (v0.22)
  - pre-start intelligence (v0.23)
  - phone-remote web dashboard (v0.24)
  - **local-AI natural-language URL resolution (v0.25)**

There's no macOS download manager with this surface area — and
critically, v0.25 is the one that makes a *video* pitch land with
a non-technical audience in ten seconds. The other passes were
infrastructure; this is the headline.

## What's new in v0.24 (the splash — Splynek on your phone, no App Store required)

The investigation-bet-that-doesn't-need-€99. Splynek already has an
HTTP server running (the fleet coordinator). Turn it into a web
dashboard any browser on the same LAN can reach. No app-store
listing, no notarization, no signing ceremony, no entitlements.

**One-sentence pitch:** scan a QR code with your iPhone, and your
phone becomes a remote control for this Mac's downloads — paste a URL
from Safari's share sheet, watch throughput tick up in real time, do
it from bed, another room, or the couch.

What landed:

- **Three new endpoints on the fleet HTTP server:**
    - `GET /splynek/v1/ui` — single-file responsive HTML dashboard.
      Mobile-first, dark-mode-aware, 300-line zero-dep vanilla JS.
    - `GET /splynek/v1/ui/state` — JSON snapshot of active downloads
      + recent completions + peer count. Polled every 1.5 s by the
      dashboard JS.
    - `POST /splynek/v1/ui/submit?t=<token>` — accepts
      `{"url":"…","action":"download"|"queue"}` and hands the URL to
      the VM via the same ingest contract the scheme handler, menu-
      bar popover, and drop target use.
    - `GET /` — 302 to `/splynek/v1/ui?t=<token>` so typing
      `mac.local:<port>` into a phone's address bar just works.
- **Shared-secret token** (16 random bytes, hex-encoded) persisted
  to `UserDefaults["fleetWebToken"]`. Read endpoints are open (they
  expose the same data the fleet protocol already shares on LAN);
  only `submit` requires the token. The QR code embeds it as a query
  param, so "scan → authorised" is a one-gesture flow.
- **QR code via CoreImage.** New
  [QRCode.swift](Sources/Splynek/QRCode.swift) renders the dashboard
  URL (with token) as a crisp `NSImage` for the AboutView card.
- **AboutView card** — *Web dashboard*: shows the LAN URL, a 170×170
  QR, *Copy URL* + *Open* buttons, and a one-line security note
  clarifying what's read-only versus gated.
- **Mobile web dashboard** renders:
    - Device name + port header
    - URL input field with *Download* / *Queue* buttons and a toast
      toast for success / failure ("Queued" / "Token rejected")
    - Live progress bars per active download with bytes / % / name
    - Recent completions list with human-readable "5m ago" timing
    - Respects iOS safe-area insets, `prefers-color-scheme`, and the
      44pt accessibility tap-target minimum
- **LAN IP discovery** picks the first RFC 1918 address (10.*,
  172.16–31.*, 192.168.*) over any public/VPN address so the QR
  carries the address that actually works on the user's network.
- **Wired ingest surface.** `FleetCoordinator.onWebIngest` is set by
  the VM at startup; it routes `action="download"` to `start()` and
  `action="queue"` to `addCurrentToQueue()`, handling both `http*`
  URLs and `magnet:` strings. The web dashboard is the fifth ingress
  after drag-drop, scheme URL, Shortcuts / App Intents, and the
  menu-bar popover — all land in the same place.

Smoke test (ad-hoc, from `curl`):

```
GET  /splynek/v1/ui        → 200 text/html
GET  /splynek/v1/ui/state  → 200 application/json
GET  /                      → 302 → /splynek/v1/ui?t=<token>
POST /splynek/v1/ui/submit                → 401 (no token)
POST /splynek/v1/ui/submit?t=wrong         → 401
POST /splynek/v1/ui/submit?t=<correct>     → 202 Accepted
```

Implementation notes:

- The HTML is embedded as a Swift raw string in
  [WebDashboard.swift](Sources/Splynek/WebDashboard.swift) rather
  than shipped as a bundled resource. Pure SPM stays pure — no
  `copy-resource` step needed in `build.sh`, and the dashboard
  version is always in lock-step with the app binary.
- The fleet HTTP parser was extended to handle `POST` bodies
  (reading `Content-Length`, draining past the header-terminator)
  without breaking the existing `GET /status`, `/fetch`, and
  `/content/<hex>` routes from v0.19–v0.20.
- Token is 16 bytes of `SecRandomCopyBytes` → 32 hex chars. Not
  cryptographic auth in the TLS sense, but matches the LAN posture
  established by Bonjour discovery: "anyone with physical access
  to the Mac to see the QR can send URLs."

Why this is the splash:

Every other Mac download manager is a Mac app. Splynek on your
phone, on your iPad, on the living-room TV's browser, on another
Mac — through a single QR scan, no install on the client side — is
new. The existing multi-interface + fleet + browser-extension +
background-first stack was already the most coherent download
infrastructure for macOS; this makes it legible in 15 seconds to
someone who's never heard of it.

## What's new in v0.23 (Splynek-is-smart — paste, and it already knows)

v0.20–v0.22 built the infrastructure: shared LAN cache, browser
distribution, background presence. v0.23 adds the thing that makes
users *notice* that infrastructure — the app starts telling you
about your download before you even click Start.

Two behaviours wire the experience:

- **Pre-start duplicate detection.** When a URL hits the form, the VM
  searches its history for a prior completion of the same URL whose
  output file still exists on disk. If it finds one, `start()`
  doesn't probe the origin or spawn a job — it surfaces a yellow
  "You already have this file" banner above the Source card with
  filename, size, age ("5m ago"), and three buttons: **Reveal**
  (opens Finder at the prior file), **Re-download** (bypasses the
  duplicate and runs the normal spawn), **Dismiss** (hides the
  banner). Users routinely re-download files they already have —
  this is the lowest-effort UX win in the entire investigation
  sequence. See [Enrichment.swift](Sources/Splynek/Enrichment.swift).
- **Auto-enrichment sibling probes.** 600 ms after the URL field
  settles (`.onChange` + debounce), seven HEAD requests fan out in
  parallel against conventional sibling paths: `.sha256`, `.asc`,
  `.sig`, `.torrent`, `.metalink`, `.meta4`, `.splynek-manifest`.
  Anything that returns a 2xx becomes a pill in the new
  `enrichmentRow` with a *"Splynek found:"* prefix. Two of the
  enrichments *auto-apply* in the background:
    - `.metalink` → parsed, URLs become mirrors, embedded SHA-256
      becomes the integrity field.
    - `.splynek-manifest` → decoded and assigned to
      `merkleManifest`; per-chunk integrity now runs without the
      user having to click *Load Manifest…*.
- **`.torrent` / signature pills are informational for now.** Opening
  a torrent sibling as an alternate transport would mean running
  HTTP + BT in parallel — a real feature but a different-shape bet
  that deserves its own pass. The pill tells users the torrent
  exists; one-click adoption will follow.

Implementation notes:

- `EnrichmentReport` is Sendable and value-typed so the VM can
  publish it across the main-actor boundary without Codable
  gymnastics. `EnrichmentTint` is an enum (not a `Color`) so the
  model stays UI-free; `DownloadView.tintColor(for:)` resolves it
  at render time.
- The duplicate check runs from **three** sites, ordered from
  cheapest to most expensive:
    1. `autoDetectSha256(for:)` — on URL change, to drive the banner
       visibility before the user clicks Start.
    2. `start()` — the actual pre-flight guard; if a duplicate
       match slipped past the banner (URL typed *and* Start clicked
       fast enough to beat the debounce), we still catch it.
    3. `start() → spawnJob() → fleet.contentMirrors(for:)` — if the
       user explicitly proceeds past the local duplicate, we still
       check the LAN for a peer that has the same SHA-256. Falls
       through to a normal fleet-mirror lane if found.
- `autoDetectSha256` was the old pre-v0.23 sibling probe entry
  point. It's been extended rather than renamed to preserve the
  existing call sites in drag-drop + magnet flows.
- Merkle manifest auto-apply is guarded on
  `self.merkleManifest == nil` so a user who manually loaded a
  manifest isn't silently clobbered by a network sibling.

## What's new in v0.22 (background-first — Splynek as infrastructure, not a tool)

Investigation bet #3. Tools you open and close feel disposable; tools
that are always running feel indispensable. v0.22 flips Splynek from
"an app you launch when you need it" to "the thing that quietly
handles every download on this Mac."

- **Menu-bar-only mode (dock icon hidden).** New Toggle in
  *About → Background mode*. Flipping it calls
  `NSApp.setActivationPolicy(.accessory)` at runtime, hides every
  visible window, and persists the choice to `UserDefaults`
  (`menuBarOnly`). The Swift-level equivalent of `LSUIElement=YES`,
  but reversible — the user can turn the dock icon back on from
  the same toggle, or temporarily surface it by pressing ⌘⇧D /
  clicking *Show Splynek* in the menu bar.
- **Launch at login via `SMAppService.mainApp`.** macOS 13+ login-
  item registration. Successful / `requiresApproval` / error states
  are mirrored back into the UI so an ad-hoc-signed build failing
  to register says *why*. All handling lives in
  [BackgroundMode.swift](Sources/Splynek/BackgroundMode.swift) —
  about 120 LOC.
- **Menu-bar quick-drop popover.** Left-click the menu bar icon and
  a 340×170pt `NSPopover` opens with a URL text field and
  *Start* / *Queue* buttons. Paste-and-Enter hands the URL to the
  VM's regular ingest path (magnet ↔ parseMagnet, http ↔ start)
  without bringing the main window forward. This is the defining
  interaction of background mode — downloads start from a paste +
  Enter, never requiring you to surface the app.
- **Drag-and-drop onto the menu bar icon.** The status button gets
  a transparent `MenuBarDragView` overlay that registers for `.URL`
  / `.fileURL` / `.string` drags. Drag any link out of Safari or
  Mail onto the Splynek icon; on drop the ingest closure fires and
  the button title flashes `✓ queued` for 1.2 s as confirmation —
  no popover, no window. The magnet / http-URL / file-URL routing
  is identical to the main window's drop path.
- **Right-click = context menu.** *Show Splynek*, *Cancel All
  Downloads*, *Quit*. Left-click = popover. The old "menu on any
  click" behaviour is gone because it interfered with the popover.
- **"Show Splynek" re-surfaces the dock icon if we're hidden.**
  Going from accessory → regular on wake-up means the
  `activate(ignoringOtherApps:)` call actually brings the window
  to the front on multi-display setups where focus was ambiguous.

Implementation notes:

- The popover content is a SwiftUI `MenuBarDropView`; the drag
  overlay is a pure AppKit `NSView` subclass. SwiftUI's drop
  modifiers don't reliably work inside NSStatusItem territory, so
  we keep that surface AppKit-native.
- `BackgroundModeController` is owned by `AppState`, injected into
  the SwiftUI env as `@EnvironmentObject`, and consumed by
  `AboutView`. Two toggles, plus a refresh button and a human-
  readable status line for the login-item state.
- `onIngest` on `MenuBarController` takes a `String`, not a
  structured URL, because drags can deliver plain-text magnets
  alongside URLs and we want one code path. The VM-side handler
  in `SplynekAppDelegate` distinguishes them — `magnet:` prefix
  goes to `parseMagnet()`, `http*:` goes to `start()`.
- We don't ship `LSUIElement=YES` in Info.plist. That would force
  background mode from boot, stranding anyone who toggles the
  preference off and relaunches. Runtime activation policy is the
  right answer here.

## What's new in v0.21 (browser-scale distribution)

The investigation bet #2: browser integration. v0.20 made Splynek
indispensable *if you find it* — v0.21 is how people find it. Every
URL a user is about to download lives in a browser, and until now
Splynek had no hook there.

- **Chrome extension** (Manifest V3) in
  [Extensions/Chrome/](Extensions/Chrome/). Context-menu handlers for
  links, images, videos, and pages — *Download with Splynek* /
  *Add to Splynek queue*. Toolbar-action popup with the current tab's
  URL and two buttons. Keyboard shortcut `⌘⇧Y` to download the
  active tab. Works in Chrome, Brave, Edge, Arc — every Chromium
  browser. No store listing yet; load unpacked from
  `chrome://extensions` with Developer Mode on. `~250 LOC` of JS
  across `background.js` + `popup.js`, plus a ~100-line manifest +
  popup HTML/CSS. Icons generated at install time via a pure-stdlib
  Python PNG encoder — zero build-time deps.
- **Safari bookmarklets** in
  [Extensions/Safari/bookmarklets.html](Extensions/Safari/bookmarklets.html).
  Three draggable buttons — download current page, queue current
  page, download link under cursor. Safari Web Extensions require
  an Xcode project (can't produce `.appex` from SPM); bookmarklets
  cover 90% of the use cases with zero-install and live happily
  next to the Chrome extension.
- **About pane wires it up.** Two new buttons in *About →
  Browser helpers*:
    - *Install Chrome extension…* reveals the bundled
      `Extensions/Chrome` folder in Finder so the user can drag it
      onto `chrome://extensions` without ever right-clicking Show
      Package Contents.
    - *Safari bookmarklets…* opens the bundled `bookmarklets.html`
      in the default browser; drag buttons onto the Bookmarks Bar
      from there.
- **Build script copies `Extensions/` into the .app bundle's
  `Contents/Resources/`** so the AboutView buttons always resolve
  regardless of where the user installed Splynek. Sanity-checked
  with `ls -R build/Splynek.app/Contents/Resources/Extensions/`.

Integration contract stays clean: the extensions build
`splynek://download?url=…&start=1` (or `…queue?url=…`) URLs and
hand them to macOS. Splynek treats those identically to
drag-and-drop, App Intents, and Shortcuts — same ingress, same
integrity checks, same interface selection. Verified with:

```sh
open 'splynek://queue?url=https%3A%2F%2Fexample.com%2Ffile.bin'
```

— the app comes to the foreground with the URL populated in the
form. No extension-specific code paths exist inside Splynek, which
keeps the trust surface minimal.

## What's new in v0.20 (the LAN content cache — "download once, spread to every Mac")

v0.19 stood up fleet discovery. v0.20 makes it indispensable: any Splynek
on the LAN can now lend bytes to any other Splynek, by content hash,
in real time, even for in-flight downloads. The commercial story
simplifies to one sentence: **install Splynek on every Mac in your
office and the same file gets downloaded from the internet exactly
once.**

Three load-bearing changes:

- **Content-addressed LAN cache.** Every completed download now computes
  its SHA-256 unconditionally (previously only when the user supplied an
  expected hash) and the digest goes into both `HistoryEntry` and the
  fleet's `/status` advertisement. New endpoint
  `GET /splynek/v1/content/<hex>` serves the matching file to any peer
  asking by hash. When a Splynek on Mac B starts a download that
  specifies an expected SHA-256, the VM first asks the fleet
  `contentMirrors(for:)` — any Mac on the LAN that has a matching file
  (regardless of the original URL) becomes an instant gigabit mirror.
  A download from Ubuntu's mirror and a download from a university CDN
  produce the same bytes, the same hash, and the same cache entry.
- **Cooperative partial-chunk trading.** Fleet mirrors now include
  peers who are *actively downloading* the same URL, not just ones
  who've finished. Mac A's engine hands Mac B the chunks it's already
  flushed; Mac B's engine hands Mac A the chunks it's got. Net result:
  both Macs download roughly half the bytes from the internet and
  trade the rest over gigabit.
- **Engine survives 416 gracefully.** `RangeError.rangeNotAvailable`
  is now a distinct, per-mirror error path. When a fleet peer returns
  416 ("I don't have this chunk yet"), the sub-lane requeues the
  chunk for another lane, bumps a new `chunksSkipped` counter, and
  keeps the connection alive for the next chunk the peer *does*
  have — no lane-health penalty, no error-streak backoff. Without
  this, partial-mirror cooperation would make lanes look unhealthy
  and trigger auto-failover.

Secondary polish:

- `JobCard` shows a `FLEET ×N` pill when a download has any fleet
  mirrors — the cooperation is visible, not invisible infrastructure.
- FleetView's "This Mac" card gains a `Hashed` metric counting
  distinct SHA-256s this Mac can serve via the content endpoint.
- `publishFleetState()` filters out history entries whose output
  files have been moved or deleted — saves peers an embarrassing 500
  when they try to fetch something we no longer have.

Implementation notes:

- Content-addressing is strictly additive. A malicious peer serving
  wrong bytes still gets caught: the caller either has a SHA-256 to
  match against (in which case the post-download integrity check
  fails) or doesn't, in which case the origin's bytes arrive too and
  we fall back to the normal verification the user already asked
  for. Fleet never becomes the sole source of truth.
- The `Hashed` metric only counts completions that produced a
  SHA-256 field. Legacy history from v0.15–v0.19 may be absent —
  those entries serve fine by URL but can't be content-addressed
  until they're re-downloaded or manually re-hashed (future polish).
- 416 handling intentionally bypasses the `errorStreak` exponential
  backoff. A fleet peer that's 90% of the way through a download
  will 416 the remaining 10% on every request for minutes until
  it catches up; that's cooperation, not failure.

## What's new in v0.19 (BitTorrent v2 + per-device fleet)

The two multi-day items at the bottom of v0.18's "declined this pass"
list, landed together. BEP 52 verification joins SHA-1 on the torrent
side; Bonjour-advertised fleet orchestration lets every Splynek on a
LAN cooperate on downloads.

- **BitTorrent v2 (BEP 52).** `.torrent` parser now understands pure
  v2, pure v1, and hybrid layouts. `TorrentInfo` gains `metaVersion`,
  `infoHashV2` (full SHA-256), `infoHashV2Short` (first 20 bytes for
  the 20-byte handshake field), and per-file `piecesRoot` sourced
  from the v2 file tree. Each piece accepted by the engine is now
  run through `TorrentV2Verify` when a piece layer is available —
  computing a SHA-256 Merkle subtree root over the piece's 16 KiB
  blocks and comparing against the 32-byte slot in the per-file
  piece layer. For hybrid torrents both v1 SHA-1 and v2 Merkle must
  agree; one-sided failure rejects the piece.
- **v2 magnets.** `urn:btmh:1220<64-hex>` is now a recognized
  `xt=` scheme. Pure-v2 magnets hand their truncated SHA-256 to
  peer handshakes + trackers; hybrid magnets can declare both
  `urn:btih:` and `urn:btmh:` and we pick the v1 hash for the
  handshake (since hybrid peers accept v1) while retaining the v2
  info hash for future `hash_request` extension work.
- **BEP 52 reserved-bit advertisement.** `reservedBytes[7] |= 0x08`
  follows libtorrent's convention. v1-only peers ignore it; hybrid
  peers recognise us as v2-capable. The wire protocol itself is
  unchanged for this pass — no `hash_request` / `hashes` /
  `hash_reject` messages yet (they're the natural follow-on when a
  pure-v2 magnet needs to verify pieces without shipped piece
  layers).
- **TorrentView** gains a new `BT v1` / `BT v2` / `Hybrid v1+v2`
  pill alongside the tracker counts so the format is obvious at a
  glance.

### Per-device fleet orchestration

- **New `FleetCoordinator`** advertises this Mac on Bonjour
  (`_splynek-fleet._tcp`) with a stable per-device UUID stored in
  `UserDefaults[fleetDeviceUUID]`. Every other Splynek on the same
  LAN discovers it, resolves the service endpoint via
  `NWConnection.currentPath`, and caches the ip:port. Refreshes
  fire automatically on discovery + every 2 s via the existing VM
  timer, and manually from a toolbar button.
- **HTTP protocol on the fleet port:**
  - `GET /splynek/v1/status` — JSON of this Mac's active and
    recently-completed downloads (URL, filename, output path,
    total bytes, per-chunk completion bitmap).
  - `GET /splynek/v1/fetch?url=<enc>` — Range-capable server that
    streams bytes from the matching job's output file. Ranges whose
    underlying 4 MiB chunks aren't yet flushed return 416 so the
    downstream lane falls over to another mirror. Completed
    downloads are served in full.
- **DownloadEngine mirror integration.** Before starting a new
  job, the VM asks `fleet.mirrors(for: url)` for any fleet-peer
  URLs claiming completion of the same source URL and folds them
  into the engine's `urls:` list as additional HTTP mirrors. The
  existing round-robin sub-lane assignment distributes them across
  interfaces with no engine-side changes — fleet peers show up as
  regular lanes with their own throughput + RTT.
- **Fleet sidebar section + view.** Lists this Mac (name, UUID,
  bound port, active / shareable counts) and every discovered peer
  (resolving / resolved state, their live downloads, their
  shareable finished files). The novel "what this Mac is sharing"
  card makes the cooperative story legible.

Implementation notes:

- Fleet is strictly additive. A malicious LAN peer can serve garbage,
  but every byte the engine accepts still has to pass whatever
  integrity check the job was started with (whole-file SHA-256 or
  per-chunk Merkle). An adversary produces retries, not wrong
  output. This matches the existing `LANPeer` posture.
- v2 Merkle padding uses BEP 52's zero-leaf balancer
  (`SHA256(16-KiB-of-zeros)`), not BitTorrent v1's
  duplicate-last-leaf. `TorrentV2Verify` caches the zero-subtree
  hashes up to height 33 so padding a short final piece doesn't
  re-hash millions of zero bytes.
- `TorrentEngine.handshakeInfoHash` picks the right 20-byte hash
  for the swarm — v1 SHA-1 for v1/hybrid, first 20 bytes of SHA-256
  for pure v2. Trackers + DHT + peer handshakes all use it.
- `FleetCoordinator` never reaches into VM state directly. The VM
  snapshots its `activeJobs` + recent history into a Sendable
  `LocalState` struct; the HTTP server reads that snapshot under
  an NSLock so cross-thread races can't corrupt the JSON.
- Peer ID prefix bumped from `-SP0002-` to `-SP0019-` for wire-level
  visibility into client version.

## What's new in v0.18 (the benchmark panel)

- **Benchmark sidebar section.** New `Benchmark` entry in the sidebar
  (lightning-bolt icon). Enter any Range-capable URL (Hetzner's
  `100MB.bin` is the default), click **Run Benchmark**, and Splynek
  probes the URL through each interface individually, then through all
  of them aggregated, then ranks the results side by side with a
  gradient bar chart.
- **Calibrated single-path vs multi-path comparison.** The multi-path
  row gets a yellow gradient bar that dwarfs the single-path blue
  bars — the commercial claim ("N× faster than single-path") becomes
  a screenshot-ready visual, not just a number buried in a job card.
- **"Copy results" button** drops a plain-text fixed-width summary on
  the clipboard, ready to paste into Twitter / Slack / a bug report.
- Probes run sequentially (so single-path numbers aren't contaminated
  by concurrent lanes), download into `/tmp/splynek-bench-<uuid>.bin`,
  and the temp files are deleted after each probe.

Implementation notes:

- `BenchmarkRunner` is `@MainActor` + `ObservableObject`; `Probe` is a
  `Hashable` `Identifiable` struct so `ForEach` reacts cleanly (naming
  it `Result` would have collided with Swift's built-in generic type
  and confused overload resolution — renamed to avoid that).
- Row layout is extracted into a dedicated `ProbeRow` view so the
  SwiftUI type-checker doesn't have to solve a big inline closure.
- Reuses `DownloadEngine` with a single-interface lane list for the
  per-interface runs, and with the full selection for the aggregate —
  no parallel benchmark-only transport path, which means improvements
  to the real engine (keep-alive, DoH, token buckets) immediately
  reflect in the benchmark numbers.

## What's new in v0.17 ("flaky internet" rescue + the screenshot moment)

Direction-A commercial pass. Seven features that make Splynek's
multi-interface moat *visible* to users, not just operational.

- **Lane health score + auto-failover.** Each `LaneStats` carries a
  0–100 `healthScore` that decays on errors and RTT spikes
  (`>3× median`). When a lane drops below 25 with sustained errors
  and zero successful chunks, the engine stops dispatching to it and
  the card gets a `FAILED OVER` pill. The flaky-Wi-Fi promise made
  concrete.
- **Per-download performance report.** On every completion, a yellow
  "bolt" banner in the job card shows `N× faster than single-path`
  and `saved MM:SS`. Under the hood: final throughput vs best-single-
  lane-throughput, per-interface byte breakdown with percentages. The
  screenshot users will post to Twitter.
- **Lifetime time-saved counter.** `HistoryEntry` gains
  `secondsSaved`, stamped from the DownloadReport. The History
  lifetime card shows "Time saved" as a green metric next to
  download count and total bytes. The emotional counter.
- **Interface preference learning.** The interface row surfaces a
  yellow-star pill next to the historical-best interface for the
  current host. Learned silently from `DownloadHistory.laneProfile`.
- **Connection-path transparency.** Each lane now emits an
  `onConnected` callback from `LaneConnection` with the *actual* peer
  IP it landed on (post-DoH, post-Happy-Eyeballs). Lane cards show a
  new `Peer` column so users can see exactly which CDN edge they're
  talking to per interface.
- **Publish `.splynek-manifest`.** `Tools → Publish Splynek
  Manifest…` (⌘⇧P) takes any local file, chunks it at the engine's
  4 MiB boundary, SHA-256-leaf-hashes each chunk, and writes a JSON
  manifest next to the file. The ecosystem play: serve content with
  its manifest, any Splynek install verifies per-chunk inline.
- **Audit cleanup** (carried from the v0.16 audit pass, before this
  release): `TrackerClient.announce()` dead-code deletion,
  vestigial `LaneStats.bandwidthCap` removed, brittle force-unwraps
  in `TorrentEngine` replaced with `guard let`.

## Declined this pass — honest infrastructure limits

These are on the roadmap but can't ship with the current build
target (SPM-only, single executable):

- **Apple Watch complication** — needs a Watch target in an Xcode
  project. SPM can't produce a `.appex`.
- **Share-sheet extension** — needs an `.appex` bundle. Same
  reason. The `splynek://` URL scheme covers the same flow via
  AppIntents + Shortcuts until we migrate to an Xcode project.
- **BitTorrent v2 with interface binding** — BEP 52 is a multi-day
  protocol rewrite (SHA-256 Merkle piece hashes, hybrid torrents,
  new peer messages).
- **Per-device fleet orchestration across Macs** — new network
  protocol + Bonjour coordination + careful sync. Multi-session
  project.
- **Benchmark panel with calibrated single vs multi-path runs** —
  useful, fits in SPM, but pushed to v0.18 for scope.

## What's new in v0.16

Turn the v0.15 read-only per-host tally into a real budget system with
editable caps + enforcement.

- **Per-host daily caps.** Each host row in the History view's
  *Today by host* card gets an inline GB-per-day cap editor. Setting a
  cap to 0 clears it; a non-zero cap with today's usage past it lights
  an `OVER` pill and paints the row red.
- **Pre-start enforcement.** `start()` now checks
  `HostUsage.isOverCap(for:)` before spawning a job. If the host is
  already past its cap for today, a `"Daily cap reached"` alert asks
  the user to cancel or **Download anyway** — the latter clears
  today's cap for that host (so the alert doesn't re-trigger) and
  proceeds normally.
- **Midnight roll preserves caps.** `HostUsage.load()` now drops
  ephemeral no-cap-no-traffic entries on day rollover but keeps every
  entry with a configured cap, so user-set limits persist indefinitely
  while the ambient list stays uncluttered.
- **Live UI.** The VM's existing 2 Hz timer now refreshes
  `topHosts` alongside the cellular tally, so the History card edits
  pick up both in-flight traffic (byte counters tick up) and other-
  source edits (caps you set elsewhere show up in the field).

Implementation notes:

- `HostUsageEntry.dailyCap` is persisted with the same JSON schema; a
  v0.15 file loads cleanly because `dailyCap` defaults to 0 when
  absent.
- "Download anyway" zeroes the cap rather than stashing a
  "allowed-today" flag. The simpler semantic: one kind of persisted
  state (cap) whose value the user adjusts, rather than two kinds
  (cap + override) that need reconciliation.

## What's new in v0.15

- **Self-download for updates.** When the About banner shows a newer
  version, clicking **Download with Splynek** populates the form with
  the advertised URL + optional SHA-256 from the feed, then calls the
  normal `start()` path. The update is fetched as a regular
  multi-interface download job: appears in `activeJobs`, uses the
  selected interfaces and bandwidth caps, lands in the user's
  Downloads folder, gets the `com.apple.quarantine` xattr, and is
  Gatekeeper-evaluated. The user then installs manually. Eating our
  own dog food for the one download the app itself cares about.
  Feed schema gains an optional `"sha256"` field; absent = no
  integrity check (the download still succeeds).
- **Per-host daily byte tally.** New [HostUsage.swift](Sources/Splynek/HostUsage.swift)
  tracks bytes received per `URL.host`, reset at local midnight,
  persisted to
  `~/Library/Application Support/Splynek/host-usage.json`. Every lane
  credits its host on each receive. The History view gains a
  *Today by host* card showing the top 5 hosts and how much each has
  served. Read-only for v0.15 — no per-host caps yet, just visibility.

## What's new in v0.14

Four of the five items from the v0.13 "natural next bites" list —
AppleScript is still deferred on purpose (App Intents covers the same
automation surface at a higher level; a `.sdef` would be pure scaffolding
for shrinking marginal value).

- **Quick Look in the History pane.** Each history row has an eye
  button and a context menu (right-click) with Quick Look, Reveal in
  Finder, Open, and Copy URL. Driven by SwiftUI's native
  `.quickLookPreview(_:)` modifier bound to a `@State` URL.
- **In-app update check** via a self-served JSON feed. Configure
  `updateFeedURL` in UserDefaults and Splynek polls it shortly after
  launch. The feed schema is
  `{ "version": "0.15.0", "notes": "…", "url": "https://…" }`. If the
  advertised semver is strictly-higher than `CFBundleShortVersionString`,
  an accent-tinted banner appears in the About view with a Download
  button. Silent when no feed is set, so unpolluted behaviour by
  default. See [UpdateChecker.swift](Sources/Splynek/UpdateChecker.swift).
- **Tit-for-tat BT seed choking.** Each `SeedPeer` now tracks
  `bytesReceivedFromPeer` (accrued on every non-keepalive message).
  The 10 s choking rotation ranks interested peers by contribution
  first, then falls back to LRU on ties / zero-contribution peers,
  and still leaves one optimistic slot for a random interested peer
  so new contributors can earn their way in.
- **Cellular daily budget.** Every byte received on an `NWInterface`
  of type `.cellular` is accumulated in
  `~/Library/Application Support/Splynek/cellular-budget.json`,
  automatically rolled at local midnight. When any cellular interface
  is selected, the Downloads options card shows a live "used today"
  counter + an editable GB-per-day cap; exceeding the cap lights an
  `OVER` pill. See [CellularBudget.swift](Sources/Splynek/CellularBudget.swift).

## What's still declined (now including AppleScript)

- **AppleScript `.sdef` dictionary** — deferred. App Intents
  (`AppIntentsProvider.swift`) already exposes Download URL / Queue URL
  / Open Magnet / Get Progress intents through Shortcuts and Siri, so
  an AppleScript dictionary would be a second, parallel automation
  surface with meaningfully lower UX than the modern one. Worth
  revisiting if a user workflow specifically needs `osascript`.
- Everything from earlier releases: uTP, MSE, HTTP/3, Reed-Solomon,
  notarization / Mac App Store / browser-extension binaries.

## What's new in v0.13

- **`GetDownloadProgressIntent`.** A fourth Shortcuts/Siri intent that
  returns a one-line summary of current state (`3 active (42%, 12 MB/s);
  1 paused; 4 queued; seeding to 2 peers`). Marked
  `openAppWhenRun = false` so automation can peek without yanking the
  window forward. Reads `NSApp.delegate` in-process; returns
  `"Splynek is not running."` if the app is cold.
- **Spotlight indexing.** Every finished download lands in Spotlight via
  `CoreSpotlight` under the `app.splynek.history` domain. Each
  `CSSearchableItem` carries filename, originating host, byte count,
  and a `contentURL` pointing at the on-disk file — so matching a
  Spotlight hit reveals the file in Finder. Reindexed on launch and
  after every completion; history clears wipe the index too.
- **Proper BT seed choking** replaces the v0.5 "unchoke everyone"
  policy:
  - Up to **4 unchoked peers** at any time (BEP 3 default).
  - A **rotation timer** fires every 10 s; LRU sort on
    `lastUnchokedAt` picks the 3 regular slots, and 1 remaining slot
    goes to a **random interested peer** (optimistic unchoke).
  - Peers that drop `not interested` get choked immediately on the
    next tick.
  - Only edges send `choke`/`unchoke` messages — no noisy repeats.
  - The old "auto-unchoke on `interested`" path is gone; everyone
    starts choked and earns a slot via rotation.
- **Torrent session restore.** The session file now carries a
  `TorrentSnapshot` with the last parsed magnet text and/or the path
  of the last loaded `.torrent`. On relaunch, if a magnet was live,
  it re-parses; if a file path was live and still exists, it re-loads.
  Piece progress lives on disk in the output files themselves, so the
  user just clicks Start to pick up where they left off.

Implementation notes:

- `SessionSnapshot` is `version: 2`. v1 files (jobs only) still parse
  correctly because `torrent` is optional.
- Seed choking state (`choked`, `lastUnchokedAt`) lives on `SeedPeer`,
  mutated from the choking-rotation Task. Message emission is routed
  through the peer's existing `send(_:)` primitive, which is the same
  path keepalive uses.
- The in-process Shortcuts intent bypass is correct today
  (`AppIntents` on macOS 13+ runs in-host); if Apple moves intents
  to a helper XPC, `GetDownloadProgressIntent` would need a fallback
  that queries via the `splynek://` scheme.

## What's new in v0.12 (automation, telemetry, citizenship)

- **Shortcuts.app App Intents.** Three intents are surfaced via
  `AppShortcutsProvider`:
  - **Download URL** — start a new multi-interface download (with an
    optional SHA-256 and an `Add to Queue` fallback toggle)
  - **Add URL to Queue** — append to the persistent queue without
    starting immediately
  - **Open Magnet Link in Splynek** — hand a magnet URI to the
    BitTorrent side for BEP 9 metadata + download
  Each intent composes a `splynek://` URL and hands it to
  `NSWorkspace.open`, so the ingest path is identical to drag-and-drop
  and to command-line `open splynek://…`. Works even when Splynek
  isn't running — macOS launches it to deliver the URL. Discovery in
  Shortcuts.app itself may lag until the app is notarized, but the
  intents are registered and invokable.
- **Per-lane RTT telemetry.** `LaneConnection` now measures
  time-to-first-byte on every chunk (`sentAt` → first body byte) and
  fires an `onRTT` callback. `LaneStats` keeps a rolling window of 20
  samples and publishes the median. `LaneCard` shows it as a third
  detail column (`RTT: 42ms`). Useful for spotting a noisy interface
  that's dragging aggregate throughput down.
- **Seeding keepalives.** `SeedingService` now spawns a
  `keepaliveTask` that emits a 4-byte zero keepalive to every
  connected peer every 90 s. Keeps long-idle connections alive past
  the receiver's 120 s read-timeout — which is also our own
  anti-snubbing defence (SeedPeer's `readBytes(4, timeout: 120)` drops
  a peer that sends nothing for two minutes).

Implementation notes:

- The new [AppIntentsProvider.swift](Sources/Splynek/AppIntentsProvider.swift)
  file is gated on `@available(macOS 13.0, *)` even though the target
  minimum is already 13; Swift's availability-model wants it explicit
  for `AppShortcutsProvider`.
- RTT is measured *from the point our request send completes* to the
  first body byte read back. That's request-line time + server
  first-byte-generation time + return trip — higher than pure TCP
  RTT, but much more useful because it reflects actual serving
  behaviour.
- The keepalive loop and the anti-snub read-timeout together give us
  symmetric 90 s send / 120 s receive liveness without any bespoke
  heartbeat protocol.

## What's new in v0.11 (resilience & scripting)

- **Session restore.** Active or paused jobs are persisted to
  `~/Library/Application Support/Splynek/session.json` on
  `applicationWillTerminate`, and rehydrated on relaunch into `.paused`
  state. Each entry records URL, output path, SHA-256, connections,
  DoH, headers, Merkle manifest, and interface names; interfaces are
  matched against the current list on restore (missing ones drop off).
  The per-chunk sidecar on disk still carries actual progress — the
  session snapshot is only the configuration.
- **Queue export / import.** *Queue* toolbar has **Export…** and
  **Import…** buttons that write/read the queue as pretty-printed JSON.
  Imports always land as `.pending` with fresh UUIDs so round-tripping
  is idempotent.
- **⌘L to focus the URL field.** Standard Mac "focus the address bar"
  shortcut. Posts a `splynekFocusURL` notification that the URL
  `TextField` picks up via `@FocusState`. Also adds a subtle
  accent-coloured border when focused, and a clearing
  `xmark.circle.fill` button.
- **Menu-bar inline progress bar.** While any download is running, a
  small template `NSImage` progress bar renders alongside the
  throughput text (22×10 pt, rounded-rect track + label-coloured fill,
  template-rendered so it adopts the menu bar's tint in light/dark
  mode).

Implementation notes:

- `DownloadJob.snapshot` and `DownloadJob.restored(from:…)` are the
  round-trip API. The engine's own sidecar detection handles the
  partial-bytes hand-off; the restore is essentially configuration-
  only.
- The restore fires ~500 ms after launch so interface discovery has
  had time to populate.
- Queue import filters the decoded list through fresh UUIDs + reset
  status so a completed entry imported on another machine becomes a
  pending one.

## What's new in v0.10

Four focused refinements that each close a specific gap identified
earlier.

- **Shared per-interface bandwidth buckets.** The v0.9 concurrent
  caveat is fixed: the ViewModel now holds `[name: TokenBucket]` and
  injects the shared bucket into every DownloadEngine via a new
  `sharedBuckets:` init parameter. Caps are edited on the **InterfaceRow**
  (no longer on each LaneCard), so the MB/s slider is a single
  per-interface setting that throttles the interface in aggregate —
  independent of how many concurrent jobs use it.
- **`splynek://` URL scheme.** Info.plist declares
  `CFBundleURLTypes` with the `splynek` scheme; the app delegate's
  `application(_:open:)` routes three actions:
  - `splynek://download?url=<encoded>&sha256=<hex>&start=1` → populate
    form, optionally auto-start
  - `splynek://queue?url=<encoded>` → add to persistent queue
  - `splynek://torrent?magnet=<encoded>` → parse magnet
  Groundwork for a future Safari / Chrome extension, or for
  `open splynek://…` from Terminal. Info.plist also registers Splynek
  as a viewer for `.torrent` and `.metalink` / `.meta4` so double-click
  routes back through the drop handler.
- **History search + filter.** A search box above the history list
  filters by filename, URL, or host. A "N of M" count appears in the
  card title while filtering, and each row gains a reveal-in-Finder
  button.
- **Partial BT seeding (seed while leeching).** A new
  `seedWhileLeeching` toggle on the Torrent view starts
  `SeedingService` at the beginning of the run with an empty bitfield.
  As each piece verifies, `markPieceComplete(idx)` updates the
  service's dynamic bitfield *and broadcasts a `have` message to every
  connected peer*, so our swarm citizenship improves continuously
  rather than only after our own download finishes. When the download
  completes, we re-announce as a full seed and keep the same listener
  alive instead of restarting.

Implementation notes:

- `SeedingService.sendBitfield` now takes the current `BitSet` instead
  of hardcoding all-ones. The existing `initiallyComplete` flag
  controls whether the service starts as a full seed or builds the
  bitfield piece-by-piece.
- `PeerCoordinator` is an actor; the seeder reference is injected at
  construction time and kept immutable, so cross-actor mutation is
  safe without locks.
- URL-scheme handling is `@MainActor` on the delegate side so it can
  mutate `@Published` VM state directly.

## What's new in v0.9

Concurrent downloads + macOS-native conveniences (pause/resume, dock menu,
global hot key).

- **Concurrent downloads.** The ViewModel's single-download assumption is
  gone: `activeJobs: [DownloadJob]` runs up to `maxConcurrentDownloads`
  (default 3, user-configurable, persisted). Each job has its own
  `DownloadEngine`, its own `DownloadProgress`, its own lane stats, and
  appears as its own card in the Downloads list. The Start button on the
  toolbar appends a new job; Cancel All (⌘.) stops every in-flight job.
- **Pause / Resume as first-class verbs.** Each job card has pause,
  resume, cancel, and remove buttons depending on lifecycle state
  (`pending / running / paused / completed / failed / cancelled`).
  Pause cancels the engine but leaves the per-chunk sidecar in place, so
  Resume starts a fresh engine that picks up exactly where it left off.
- **Global hot key** (⌘⇧D) registered via the legacy Carbon API
  (`RegisterEventHotKey` with `cmdKey | shiftKey`). Fires whenever
  Splynek is running, no accessibility permissions required. Brings the
  main window forward. See [GlobalHotkey.swift](Sources/Splynek/GlobalHotkey.swift).
- **Dock menu.** Right-click (or long-press) on the Dock icon shows a
  live list of active downloads with their per-job percent, plus
  *Show Splynek*, *Cancel All*, *Resume All*. Implemented via
  `applicationDockMenu(_:)`.
- **Smarter dock badge.** The badge now reflects aggregate state:
  - 1 running → the single job's percent (`42%`)
  - N running → the count (`3`)
  - nothing running → cleared
  Driven by a VM timer, not the engine, so it's honest across concurrent
  jobs.
- **Aggregate menu-bar status.** The menu-bar item sums throughput
  across every running job and counts both HTTP downloads and the
  torrent session.

Architectural notes:

- `Sources/Splynek/DownloadJob.swift` owns one download's engine +
  lifecycle; the ViewModel holds `[DownloadJob]`.
- `DownloadEngine` no longer touches `DockBadge` directly — the VM owns
  the badge.
- Per-interface bandwidth caps are still *per-engine*, so with N
  concurrent downloads on the same interface the effective combined cap
  is N×. A shared-bucket refactor is documented as future work.

## What's new in v0.8 (real download-manager UX)

- **Persistent download queue.** Queue URLs from the toolbar ("Add to
  Queue", ⌘⇧Q); next pending entry starts automatically when the current
  download finishes. State is saved to
  `~/Library/Application Support/Splynek/queue.json` with `pending /
  running / completed / failed / cancelled` status per entry. New Queue
  section in the sidebar shows summary metrics + a retry/remove menu per
  row.
- **HTTP Basic auth.** Pasting `https://user:pass@host/file` works —
  `LaneConnection` (the per-lane keep-alive HTTP client) and `Probe`
  (the `URLSession` probe) both extract URL userinfo and emit
  `Authorization: Basic <b64>`.
- **Custom request headers.** New *Advanced* toolbar toggle on the
  Downloads screen reveals a headers editor. Headers are threaded through
  `DownloadEngine` → `LaneConnection` and applied to the probe too.
  Useful for API tokens, Referer spoofing, custom User-Agent.
- **Detached signature detection.** Alongside the `.sha256` auto-detect,
  `autoDetectSha256` now HEADs `.asc` and `.sig` siblings in parallel.
  If one exists, the Advanced card shows a "Detached signature
  available" line — Splynek doesn't call out to `gpg` itself, but
  surfaces the resource so you can verify manually.
- **Recent Files menu.** Loading a `.torrent` or `.metalink` (via
  drop, Open panel, or the system File → Open Recent menu) calls
  `NSDocumentController.noteNewRecentDocumentURL`. Files opened via
  Finder double-click or the dock are routed back through the same
  ingest path via `application(_:openFiles:)`.
- **Progress in the window title.** When a download is active, the
  `.navigationTitle` on the Downloads pane reads
  *"Downloading — 42%"* instead of the static *"Downloads"*.

## What's new in v0.7 (design pass)

Proper macOS Human Interface Guidelines applied throughout — the UI is now
structured as a real Mac app, not a stack of SwiftUI controls.

- **Sidebar + detail navigation.** `NavigationSplitView` with a sidebar
  (Downloads / Torrents / History / About). Sidebar rows surface live
  status pills (`LIVE` while running, `SEED` while seeding, history
  count).
- **Unified titlebar.** `.windowToolbarStyle(.unified(showsTitle:))` with
  toolbar actions (Start / Cancel / Copy-curl) where HIG-native Mac apps
  put them, not inline in the URL row.
- **Card-based canvas.** Content is arranged in `TitledCard` containers
  on the window's `controlBackgroundColor` surface — subtle borders,
  consistent 12pt corner radius, 16pt internal padding, 8pt grid.
- **Typographic hierarchy.** Monospaced reserved for IP addresses, byte
  counts, and hashes; headings in `.headline`; primary metrics in
  `.rounded` 22pt with `contentTransition(.numericText())` so they
  animate smoothly; caption labels uppercase-tracked as section
  chrome.
- **SF Symbols everywhere.** `wifi` / `cable.connector` /
  `antenna.radiowaves.left.and.right` per interface kind, status pills
  use semantic colors that adapt to light and dark appearance.
- **Gradient progress bar** replaces the system `ProgressView` —
  accent-gradient fill, spring animation on fraction change.
- **Area-fill throughput chart** — per-lane lines on top of an
  aggregate-sum gradient area, `monotone` interpolation, axes styled.
- **Per-lane cards in a grid** — `LazyVGrid` with adaptive columns,
  each card showing throughput as the focal number, inline bandwidth
  cap editor, error/active-chunk pills.
- **Real empty states** with SF Symbol icons and body copy instead of
  bare "Nothing yet" text.
- **About view** with a hero-sized accented symbol and a
  features-tile grid.
- **Polished history list** with lifetime-summary metrics (total count,
  total bytes, average throughput) and per-entry throughput badge.
- **Subtle animations** on state transitions (download starts / ends,
  seeding turns on) using `.easeInOut(0.2)` on structural changes.

View tree:

```
Sources/Splynek/Views/
  RootView.swift              # NavigationSplitView
  Sidebar.swift               # Sidebar sections + live status pills
  DownloadView.swift          # HTTP download screen
  TorrentView.swift           # Torrent + magnet + seeding
  HistoryView.swift           # Recent downloads + lifetime stats
  AboutView.swift             # Hero + feature tiles
  Components.swift            # TitledCard, StatusPill, MetricView, …
  InterfaceComponents.swift   # InterfaceRow, LaneCard
  ThroughputChartView.swift   # Styled area + line Swift Charts view
```

## What's new in v0.6 (macOS citizenship)

- **Preferences persistence.** Output directory, connections-per-interface,
  DoH toggle, seed-after-completion all survive relaunch via `UserDefaults`
  (keyed on the `didSet` observer pattern, no Combine round-trip needed).
- **Drag-and-drop.** Drop a URL from Safari, a magnet string, a
  `.torrent` file, or a `.metalink` / `.meta4` file onto the main window.
  The ViewModel's `handleDrop` dispatches on file extension / scheme.
- **Notification Center.** Post-completion toast via
  `UNUserNotificationCenter` — both HTTP and BitTorrent engines call
  `Notifier.post(...)` when their progress flips to `finished`.
  Permission is requested lazily on first use.
- **Dock badge.** The history-sampler timer mirrors
  `progress.fraction` to `NSApp.dockTile.badgeLabel` as a percentage;
  cleared on completion and on cancel.
- **Menu bar status item.** `NSStatusBar.system.statusItem` shows
  `↓<throughput>  ×<active>  ↑<seeding-peers>` at a glance, updating
  once per second. Menu has "Show Splynek" and "Quit". Installed via a
  `NSApplicationDelegateAdaptor` so it persists for the app lifetime.
- **Auto-detect `.sha256` sibling.** When you paste or drop a URL,
  `autoDetectSha256` hits `<url>.sha256` with a 5-second timeout, parses
  the conventional `sha256sum`-style output, and prefills the integrity
  field if one is found. Silent on failure.

## What's new in v0.5

- **BitTorrent seeding.** Toggle "Seed when complete" before starting a
  torrent and Splynek stays connected after the download finishes:
  - `NWListener` on TCP binds a random port (optionally pinned to the
    chosen interface via `requiredInterface`)
  - Accepts inbound BEP 3 handshakes, validates our info-hash, sends our
    complete bitfield (all-ones, with trailing-bit masking for odd piece
    counts), advertises BEP 6/10 reserved bits
  - Unchokes every interested peer up to a cap (pure-seed policy, no
    tit-for-tat rotation)
  - Serves `request → piece` by seeking into the multi-file on-disk layout
    via `TorrentWriter.readAt`
  - Re-announces to every HTTP and UDP tracker with `event=completed`,
    `left=0`, and our real listen port
  - Calls DHT `announce_peer` on nodes that handed us tokens so peers
    find us via DHT too
  - Re-announces every 15 minutes while seeding; stops on Cancel
  - UI shows listen port, connected peer count, bytes uploaded, uptime

## What's new in v0.4

- **PEX (BEP 11).** Splynek advertises `ut_pex` in its extended handshake
  and feeds peers discovered from PEX messages back into the swarm
  scheduler. In a busy swarm this typically doubles or triples the peer
  pool beyond tracker+DHT.
- **DHT `announce_peer`.** After `get_peers` returns values, we save the
  token the responding node hands us and call `announce_peer` later — so
  other Splyneks looking for the same content can find us via DHT, not
  just trackers.
- **DHT routing-table persistence.** Good nodes are saved to
  `~/Library/Application Support/Splynek/dht-routing.json` after each
  run; the next launch seeds the query queue from there so bootstrap is
  instant instead of starting cold from the public bootstrap nodes.
- **Incoming DHT queries.** [DHTServer.swift](Sources/Splynek/Torrent/DHTServer.swift)
  responds to `ping`, `find_node`, `get_peers`, and `announce_peer` —
  Splynek is now a proper DHT citizen instead of a pure leech. Token
  validation for `announce_peer` is stateless (HMAC-SHA256 of client IP +
  per-process secret).
- **Endgame mode.** When fewer than 4 pieces remain, the `PiecePicker`
  hands the same piece to multiple peers simultaneously; first correct
  SHA-1 wins. Surfaces as an orange "ENDGAME" badge in the torrent
  progress view.

## What's new in v0.3

- **DHT (BEP 5)**, minimal but working: bootstrap against
  router.bittorrent.com / router.utorrent.com / dht.transmissionbt.com /
  dht.libtorrent.org, `get_peers` for the info hash, walk the reply tree
  by XOR distance. Magnet links that used to return zero peers now find
  peers via DHT.
- **UDP trackers (BEP 15).** Many real trackers are UDP-only; we now
  announce to those too.
- **Extension protocol (BEP 10) + metadata exchange (BEP 9).** Magnet
  links work end-to-end: Splynek pulls the info dict from a peer over the
  extension protocol, verifies SHA-1 against the info hash, then proceeds
  normally.
- **Fast extension (BEP 6).** `have_all` / `have_none` /
  `allowed_fast` / `reject_request` / `suggest_piece` — significantly
  more peers accept us as a candidate.
- **Multi-peer downloading** with **rarest-first** piece selection.
  Replaces the v0.2 sequential one-peer-at-a-time loop with up to 8
  concurrent peer sessions negotiated through a shared `PiecePicker`.
- **Multi-file torrents.** `TorrentWriter` splices each piece across the
  files it straddles.
- **Tracker-over-NWConnection.** HTTP/HTTPS trackers are now announced
  via `NWConnection` with `requiredInterface` pinned. This closes the
  previous gap where tracker DNS could egress a different NIC than the
  peer sockets.
- **SHA-256 Merkle-tree integrity for HTTP.** Load a sidecar JSON
  manifest (`leafHexes`, `rootHex`, `chunkSize`, `totalBytes`) and
  Splynek verifies each 4 MiB chunk's leaf hash inline — on mismatch the
  chunk is re-queued instead of failing the whole download. Root is
  re-verified against the manifest at completion.
- **Bonjour LAN Splynek-to-Splynek.** `LANPeerAdvertiser` serves
  range-GETs to other Splyneks on the local network who are looking for
  the same content hash; `LANPeerBrowser` discovers them via the
  `_splynek._tcp` service. Discovered peers become additional mirrors in
  the engine's URL list. See **LAN peer caveats** below.

## What's new in v0.2

- **Metalink support.** Load a `.metalink` / `.meta4` file; Splynek fans out
  across (mirror × interface), preserving keep-alive per sub-worker. The
  sha-256 from the metalink auto-fills the integrity field.
- **Per-interface DoH.** Toggle "Per-interface DoH" and every lane resolves
  its hostname via Cloudflare 1.1.1.1 over HTTPS on *that* interface,
  closing the "data goes out Ethernet but DNS leaks via Wi-Fi" gap. TLS
  SNI is preserved so cert validation still targets the original hostname.
- **Native BitTorrent v1 (experimental).** Load a `.torrent`, pick an
  interface, and Splynek announces to HTTP trackers, connects to peers
  over TCP with `requiredInterface` set (so peer traffic egresses the
  chosen NIC — yes, same `IP_BOUND_IF` story as HTTP downloads), does the
  BEP 3 handshake, pipelines block requests, verifies each piece's SHA-1,
  and writes the file. Zero third-party deps. Single-file torrents only.
  See **Torrent scope** below for the honest feature matrix.

## Features

- **Multi-interface aggregation.** Each selected interface gets a persistent
  `NWConnection` with `requiredInterface` set — the kernel enforces egress
  via `IP_BOUND_IF` / `IPV6_BOUND_IF`.
- **HTTP/1.1 keep-alive per lane.** A single TLS handshake amortised across
  every chunk a lane fetches, not one handshake per chunk.
- **Intra-lane parallelism.** Configurable N (1–8) concurrent connections
  per interface, useful when origins rate-limit per TCP connection.
- **Work-stealing scheduler.** An actor-based `ChunkQueue` hands 4 MiB
  chunks to whichever lane asks next. No hand-tuned scheduler.
- **Exponential backoff.** Per-lane retry streak doubles the sleep (capped
  at ~8 s) and resets on success.
- **Per-interface bandwidth caps.** Token-bucket rate limiter per lane;
  editable from the UI in MB/s.
- **Resume via sidecar.** A `<filename>.splynek` JSON sidecar records
  completed chunk IDs plus `ETag` / `Last-Modified`. Restart Splynek after
  a crash or reboot and it resumes mid-download, verifying the cache
  validators before doing so.
- **Filename safety.** `Content-Disposition` filenames are sanitised
  (path separators, nulls, control chars, leading dots, length) so a
  malicious server can't direct writes outside the chosen directory.
- **Filename collision.** If the output name exists, appends
  ` (1)`, ` (2)`, etc.
- **Large-download confirmation.** Downloads ≥ 10 GiB prompt before
  starting so a lying server can't sneak a 1 TiB sparse-file preallocation
  past you.
- **SHA-256 integrity.** Paste an expected hex digest; the download fails
  on mismatch.
- **Gatekeeper verdict.** When the finished file is `.app` / `.dmg` /
  `.pkg`, Splynek runs `spctl -a` and surfaces the verdict in-app *before*
  you double-click.
- **Quarantine xattr.** Downloaded files get `com.apple.quarantine` set
  exactly like Safari / Chrome so Gatekeeper actually runs on first-open.
- **URL scheme validation.** Only `http://` / `https://` with a real host
  are accepted.
- **Connect timeout.** 15 s cap on `NWConnection.ready`; prevents hung
  lanes from blocking forever on a half-open server.
- **NWPath-aware defaults.** Expensive interfaces (cellular) are
  unchecked by default; tagged `$$` in the UI.
- **IPv4 + IPv6.** Discovered per interface; UI shows `v4` / `v6` badges.
  `NWConnection` handles family selection on the pinned interface.
- **Throughput history chart.** 1 Hz sampled rolling window plotted per
  lane via SwiftUI Charts.
- **Persistent download history.** Last 500 completions saved to
  `~/Library/Application Support/Splynek/history.json`.
- **Lane replay.** The UI surfaces historical per-interface throughput
  for the same host next to the interface picker, so you can see which
  lane is usually fastest for that origin.
- **Export as curl.** One-click copy of an equivalent bash script (one
  `curl --interface` invocation per selected lane, with SHA-256 assert).
- **Sandbox-ready.** Entitlements file at
  [Resources/Splynek.entitlements](Resources/Splynek.entitlements). Not
  used by default (requires a real signing identity); pass
  `ENTITLEMENTS=Resources/Splynek.entitlements` to [Scripts/build.sh](Scripts/build.sh).
- **Notarization scripted.** The build script prints the full
  `notarytool submit` + `stapler staple` sequence when you use ad-hoc
  signing; pass `SIGN_IDENTITY="Developer ID Application: …"` to sign for
  distribution.

## Signing and distribution

```sh
# Local / ad-hoc (default)
./Scripts/build.sh

# Distribution build, with sandbox entitlements
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
  ENTITLEMENTS=Resources/Splynek.entitlements \
  ./Scripts/build.sh

# Notarize (see script output for the full recipe)
ditto -c -k --keepParent build/Splynek.app build/Splynek.zip
xcrun notarytool submit build/Splynek.zip --apple-id … --team-id … --wait
xcrun stapler staple build/Splynek.app
```

## Project layout

```
Splynek/
  Package.swift
  Sources/Splynek/
    SplynekApp.swift          # @main SwiftUI App
    ContentView.swift         # all SwiftUI views
    ViewModel.swift           # state + alerts + orchestration glue
    DownloadEngine.swift      # HTTP engine, LaneStats, DownloadProgress, ChunkQueue
    LaneConnection.swift      # keep-alive HTTP/1.1 over NWConnection (optional DoH)
    Probe.swift               # URLSession HEAD / ranged-GET
    InterfaceDiscovery.swift  # getifaddrs × NWPathMonitor
    Models.swift              # shared types (DiscoveredInterface, Chunk, ...)
    Sanitize.swift            # filename sanitisation
    Quarantine.swift          # com.apple.quarantine xattr
    GatekeeperVerify.swift    # spctl wrapper
    DownloadHistory.swift     # ~/Library/Application Support persistence
    CurlExport.swift          # `curl` command generator
    Metalink.swift            # RFC 5854 XML parser
    DoHResolver.swift         # JSON DoH over per-interface NWConnection
    MerkleTree.swift          # Per-chunk SHA-256 tree integrity
    LANPeer.swift             # Bonjour advertise + browse, HTTP range server
    Torrent/
      Bencode.swift           # BEP 3 encoder + decoder (unit-tested)
      TorrentFile.swift       # .torrent parser, multi-file layout
      MagnetLink.swift        # BEP 9 magnet URI parser
      TrackerClient.swift     # HTTP/S tracker via URLSession
      HTTPTrackerOverNW.swift # HTTP tracker on NWConnection, per-interface
      UDPTracker.swift        # BEP 15 UDP tracker protocol
      TorrentWriter.swift     # Multi-file piece splicing
      PeerWire.swift          # TCP peer protocol, BEP 6/10/9/11 (PEX)
      DHT.swift               # BEP 5 client: get_peers, announce_peer, persistence
      DHTServer.swift         # BEP 5 server: responds to ping/find_node/get_peers
      TorrentEngine.swift     # Multi-peer, rarest-first, endgame, SHA-1 verify
  Resources/
    Info.plist
    Splynek.entitlements      # optional sandbox profile
  Scripts/
    build.sh                  # swift build → .app → codesign
  build/
    Splynek.app
```

## LAN peer caveats

Bonjour-advertised peering has one real security gap: there's no
authentication, so a malicious host on your LAN could advertise `hash=X`
but actually serve bogus bytes. Splynek mitigates this two ways:

1. **Merkle manifest.** If the download has a Merkle manifest loaded,
   per-chunk hashes catch any byte-level poisoning immediately; bad
   chunks are re-fetched from another source.
2. **Final SHA-256.** The end-of-download SHA-256 check catches any
   undetected byte-level tampering.

Without either check (no manifest, no SHA-256), a LAN peer could serve
you a wrong file of the right size. Treat LAN peering like any
unauthenticated cache — fine as a throughput multiplier, not a
substitute for cryptographic verification.

## Torrent scope

The native BitTorrent client is intentionally minimal — it's a working
proof that the multi-interface infrastructure extends to peer-wire
sockets, not a libtorrent replacement. Here's what it actually does.

**Implemented:**
- `.torrent` metainfo parsing (bencode + info-hash from raw info bytes)
- **Multi-file torrents** — pieces splice across file boundaries correctly
- Magnet link parsing (xt, dn, tr, ws — hex and base32 info hash)
- **HTTP / HTTPS tracker** announce via `NWConnection`, pinned to the
  chosen interface (tracker DNS now obeys the interface too)
- **UDP tracker (BEP 15)** — connect + announce on the chosen interface
- Compact peer list (BEP 23), IPv4 and IPv6 (`peers6`)
- TCP peer wire (BEP 3): handshake, bitfield, have, interested/unchoke,
  pipelined block requests, piece reassembly, per-piece SHA-1 verify
- **Fast extension (BEP 6)**: have_all/none, allowed_fast, reject_request,
  suggest_piece
- **Extension protocol (BEP 10) + metadata exchange (BEP 9)**: magnet
  links fetch the info dict from peers before download
- **DHT (BEP 5), client-only**: bootstrap + get_peers, XOR-distance walk
- **Multi-peer parallelism** with **rarest-first** piece selection
  (up to 8 concurrent peer sessions)
- Peer socket pinned to a selected interface via `requiredInterface`
- Gatekeeper evaluation + quarantine xattr on completion (same as HTTP)

**Not implemented:**
- uTP (BEP 29) — LEDBAT congestion control is real work
- Encryption (MSE) — known-plaintext attacks on old-style RC4 negotiation;
  most modern swarms accept plain
- Seeding refinements: rate limiting, choking rotation, optimistic
  unchoke, super-seeding (BEP 16), partial-seed while still leeching

Suitable for: most real swarms, including magnet-only torrents with a
healthy DHT footprint (Linux ISOs, Archive.org, public datasets).
Seeding is pure-seed only (you finish, then you give back).

Not suitable for: BT encryption-only swarms, swarms where most peers
require uTP.

## Not implemented (by design, for now)

These either require external infrastructure, are multi-session rewrites,
or are meaningful product decisions I didn't want to make unilaterally.

- **Notarization.** Needs an Apple Developer account. Script prints the
  full recipe.
- **Mac App Store submission.** Same, plus additional entitlement /
  review work.
- **uTP (BEP 29).** A proper micro-transport needs LEDBAT congestion
  control; that's a separate multi-day project, not a one-session
  feature. Many swarms work fine without it.
- **MSE encryption.** The old RC4-based negotiation has known-plaintext
  weaknesses; low ROI given that most modern swarms accept plain TCP.
- **BitTorrent seeding / upload.** We're download-only by design; adding
  upload would need a proper choking algorithm, tit-for-tat, and an
  accept loop.
- **PEX / DHT announce / routing-table persistence.** Incremental
  improvements to the DHT story; worth doing eventually, not blocking.
- **HTTP/3 / QUIC.** `NWProtocolQUIC`'s public API surface is limited;
  a correct HTTP/3 client on top of it is a separate project.
- **Reed-Solomon erasure coding.** A real feature but one that touches
  every piece of the engine; a ~20% byte overhead bet that deserves its
  own design pass.
- **LAN Splynek-to-Splynek P2P.** Bonjour discovery + local peer protocol
  + auth is its own subsystem.
- **Interface-aware DNS via DoH.** Needs a per-lane DoH resolver; worth
  doing to close the "system DNS leaks through a different interface"
  gap but it's a significant addition.
- **Metalink / multi-mirror.** Currently one URL; Metalink would turn
  the engine into a (mirror × interface) scheduler.
- **Erasure coding across interfaces.** Reed–Solomon over chunks for
  flaky-link resilience. Implementable, just wasn't worth it this pass.
- **Tree-hash integrity (BLAKE3 or SHA-256 Merkle).** End-to-end SHA-256
  is supported; per-chunk tree hashing would let us resume a corrupt
  chunk precisely instead of bailing the whole download.
- **Safari / Chrome extension.** "Send to Splynek" context-menu hook is
  a separate extension project.
- **Full App Sandbox enforcement.** Entitlements file is shipped; actual
  testing / hardening requires Developer ID + a signed build.
