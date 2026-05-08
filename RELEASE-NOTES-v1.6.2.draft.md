# Splynek v1.6.2 — release notes (draft)

> **Status:** draft.  Do NOT publish until Apple v1.0 clears MAS re-review.
> Once cleared, the v1.6.2 work in `main` ships as a single rolled-up
> release: cut the DMG via the Developer-ID flow in `HANDOFF.md`,
> notarise, staple, push the `v1.6.2` tag, attach DMG, deploy
> `docs/index.v1.6.2.html.draft`, bump the Homebrew tap.

---

## TL;DR (≤ 50 words for the GitHub release body)

Five fully native locales: Portuguese (Portugal), Spanish, French, German, Italian.
Catalog grew **56 → 457 strings × 5 locales = 2,285 translations**.
Onboarding sheet on first launch.  MCP/Spotlight/App Intents (v1.6.0)
documentation polished.  Audit, regen, and CI guardrails wired so
future PRs can't ship un-localized strings.

## What changed since v1.5.3

### Localization — five native locales

- **456 user-visible strings** localized to pt-PT / es / fr / de / it
  (was 56 in v1.5.3).  Catalog generated from
  `Scripts/regenerate-localizations.py` (the source-of-truth);
  `Localizable.xcstrings` is committed but rebuilt from the Python
  whenever it's edited.
- Every locale **passes a CI invariant**: full coverage (no missing
  locales on any key), no empty translations, ≥ 95 % completeness per
  locale.  Test in `Tests/SplynekTests/LocalizableCatalogTests.swift`.
- Audit script `Scripts/find-missing-translations.py` reports **0
  un-localized strings** in `Sources/SplynekCore/Views/`.  Wired into
  `.github/workflows/lint.yml` so PRs can't regress.
- The build pipeline (`Scripts/compile-xcstrings.py`, invoked by
  `Scripts/build.sh`) compiles `.xcstrings` → `.lproj/*.strings` and
  mirrors them into the `.app` bundle's main resources, working around
  SwiftPM's missing first-class `.xcstrings` support.

### Programmable platform (v1.6.0 surface, polished in v1.6.2)

- **MCP server** — 8 tools, JSON-RPC 2.0 over POST.  Off by default;
  opt-in via Settings → Programmability.  Setup docs in
  `MCP_SETUP.md`.  All 8 tool descriptions are localized.
- **Spotlight catalog index** — Sovereignty + Trust entries are
  searchable system-wide via `CSSearchableIndex`.  Public catalog
  data only — no user-app metadata is indexed.
- **App Intents** — `LookupSovereigntyIntent`, `LookupTrustIntent`,
  `RunSovereigntyScanIntent`.  Read-only against the same compile-time
  catalog as the in-app tabs.

### UX

- **Onboarding sheet** on first launch — three-step explainer
  (Faster / Honest / Private + Sovereign), localized.  Skippable.
- **Frota / Fleet** column captions now route through
  `LocalizedStringKey`: NAME / DEVICE ID / PORT / ACTIVE / SHAREABLE /
  HASHED / ADVERTISED render natively in every shipped locale.
- **Trust + Sovereignty** body texts — including the "Apps we don't
  know yet" empty state, AI fallback explainer, and per-axis breakdown
  labels — fully localized.
- **AboutView** version stripe pulls from the new
  `SplynekVersion.swift` single-source-of-truth (kills the stale
  "0.6.0" / "0.0.0" fallbacks).
- **ContextCard** giant-rectangle bug fixed (Trust + Sovereignty
  empty-state cards no longer render as a 600-px-tall rectangle on
  wide windows).

### Audit + hardening

- `validate-mcp.sh` stdout/stderr separation fixed (jq parsing was
  breaking on call-display leakage).
- `os.Logger` framework added across DownloadEngine, FleetCoordinator,
  TorrentEngine — replaces the previous mix of `print` + `NSLog`.
- `LANPeer` GCD/Task tangle untangled; `FleetCoordinator` rate-limit
  GC moved off the hot path; `WatchedFolder` reentrancy guard;
  `TorrentEngine` force-unwrap rewritten.
- Accessibility pass on TrustView / SovereigntyView / SettingsView
  (every interactive element now has a non-empty
  `.accessibilityLabel`).
- New invariants: `ReleaseCoherenceTests.swift` (DMG + MAS + Alfred
  plists agree on version), `LocalizableCatalogTests.swift` (full
  catalog completeness), `MCPProtocolTests.swift` (JSON-RPC 2.0 wire
  conformance for all 8 tools).

### Tooling

- `swift run splynek-test --filter <substring>` — narrows a run to
  matching tests for fast iteration.
- `Scripts/find-missing-translations.py` is **type-blind** on
  interpolations: it accepts both `%@` and `%lld` catalog keys for
  any `\(...)` interpolation, so the catalog can be keyed accurately
  while the audit stays robust.
- `Scripts/regenerate-localizations.py` is now Python-3.14-clean (zero
  SyntaxWarnings).

### Catalogs

- Sovereignty catalog: 1,155 entries (unchanged this sprint — the
  weekly cron handles incremental drift).
- Trust catalog: **151 entries** (was 30 at v1.6.0; +121 across the
  v1.6.x sprint).  Validator runs at zero warnings.

## Numbers

| Metric | v1.5.3 | v1.6.2 | Δ |
|---|---:|---:|---:|
| Tests | 148 | 170 | +22 |
| Locales shipped | 1 (en) | 6 (en + pt-PT/es/fr/de/it) | ×6 |
| Catalog strings | 56 | 457 | ×8 |
| Total translations | 56 | 2,285 | ×40 |
| Trust catalog entries | 30 | 151 | ×5 |

## Upgrade notes

- **No breaking changes.**  Existing user data (history, queue,
  fleet.json, schedule.json) reads forward without migration.
- **First launch after upgrade** shows the onboarding sheet once.
  Skip → goes straight to Downloads.
- **MCP off by default** — Settings → Programmability → "Enable MCP
  server".  Setup details in `MCP_SETUP.md`.
- **Locale resolution** uses macOS's native `AppleLanguages`
  preference.  Force a specific locale at launch with `Splynek.app
  -AppleLanguages '(de)' -AppleLocale de_DE` (handy for QA).

## Known issues

- **Apple Mac App Store** — v1.5.3 / v1.6.x are not yet available on
  MAS.  v1.0 is in re-review since 2026-04-26.  Once it clears, v1.6.2
  uploads as the update.
- **Homebrew upstream cask** — auto-rejected at notability (PR
  #261294); resubmit after the upstream repo crosses 75 stars.  The
  Splynek tap is live at `Splynek/homebrew-splynek` and remains the
  recommended install path.

## Verification

The release artifact must be:

- Developer-ID signed (`Developer ID Application: Paulo Moura
  (58C6YC5GB5)`)
- Notarised (`xcrun notarytool submit --wait` returns `Accepted`)
- Stapled (`xcrun stapler staple build/Splynek.dmg`)
- SHA-256 published in this release body and on the Homebrew cask

Reference: `HANDOFF.md` — "Build (DMG Developer-ID, for notarisation)"
section.

---

## 2026-05-08 addendum — design revolution + audit hardening

The 137-commit rollup grew an explicit design arc on 2026-05-08.
This section appends the user-facing changes that landed that day
(SHA range `2efa8d0..ce63709`, plus the catalog top-up `25c8e7d` and
the GitHub asset retry `ce63709`).  Sources: `SESSION-LOG.md` —
"2026-05-08 — Design revolution + whole-app audit".

### Sidebar consolidation

- **Apps row** merges what used to be Install + Updates into a
  segmented surface; saves a row at every window height.  The
  badge prefers pending update count (`↑ N`) when there's work
  to do, otherwise shows installed count.
- **Agents** moved into Library next to Fleet (was alone in a
  one-item "Connect" section that read as orphaned).
- Brand footer (logo + version + Settings gear) retired — Settings
  is already in the macOS menu bar (⌘,) per v0.49 layout, and the
  About card is in the Apple menu.
- WindowGroup `defaultSize: 1180×820` so first-launch users land
  on a window tall enough for the whole sidebar without clipping.

### Per-tab revolutions

- **Frota.**  Hover-revealed action group (Reveal · Stop sharing ·
  Trash) replaces the mute eye-slash icon; right-click + ⌘⌫
  mirror.  Trash uses `NSWorkspace.recycle` + prunes the matching
  history entries.  Dedupe by SHA-256 → (filename, size) →
  outputPath cascade catches Finder-rename twins; row-level
  Stop-sharing fans out across all underlying URLs.  Card header
  shows total count + bytes shared.
- **Instalar.**  Two cards merged into one; per-row status pill
  (ACTIVE / UPDATE BLOCKED / MISSING) + `⋯` menu (Reveal · Toggle
  auto-update · Forget); engine errors humanised in plain language
  with `/var/folders` paths stripped.  Critical bug fix: the test
  fixtures `Bork` and `Good` had been writing to the real
  `~/Library/Application Support/Splynek/installed-apps.json` for
  every dev who ran the suite — now the test harness redirects
  via `_testOverrideURL`.
- **Atualizações.**  The Update button now does what it says —
  download + verify + install (`replaceExisting: true`) via the
  full `InstallerEngine.run` pipeline, with per-row Phase state
  machine + "Installed!" completion state.  ContextCard hero
  replaces the bespoke green block.  Sidebar shows the live
  pending-update count (`↑ N`) instead of `NEW`.  Auto-refreshes
  on tab open + at end of launch via `vm.warmUpdateCount`.
- **Transferências.**  `1.0× faster than single-path` tautology
  retired; when only one interface contributed bytes the banner
  now reads "Bond a second network for 2–3× faster downloads"
  with concrete examples (Ethernet, USB-C tether, iPhone hotspot,
  Tailscale).  Multi-path celebration banner unchanged for the
  real ≥2× case.
- **Soberania + Confiança.**  Splash screens retired (56pt icon +
  bullet hero + Scan-my-Mac CTA).  ContextCard always renders;
  scan auto-fires on `.onAppear`.  Net −172 lines.
- **Confiança risk score.**  Was a bare `75` over a `ALTA` word
  (ambiguous + gender-mismatched in pt-PT).  Now: `RISK` framing
  word, big `75/100` figure with explicit scale, and a single
  noun-phrase per locale (`Risco alto` / `Hohes Risiko` / etc.).
  New horizontal gauge with green→red gradient + position dot +
  inline anchor labels (`0 clean` / `high concern 100`) makes
  the direction self-evident.  Percentile context line ("Higher
  than X% of your installed apps") when ≥2 apps in pool.
- **Histórico.**  Count badge in card accessory; per-row Forget
  (hover trash) + right-click context menu with Forget / Move-to-
  Trash; `⋯` menu adds Clear-all-history with confirmation
  dialog.  `DownloadHistory.clearAll()` single-write helper.
- **Poupanças (revolution v2).**  Per-app tier picker — Claude
  (Pro / Max 5× / Max 20× / Team), ChatGPT (Plus / Pro / Team),
  Perplexity (Pro / Enterprise) — drives a recompute of the
  big-number hero in real time with `.contentTransition(.numericText())`.
  Big-number hero: dual stat blocks (Recovered / Could recover)
  with comparison framing ("≈ 5 years of Spotify Premium",
  "≈ 53 cappuccinos", "≈ X new MacBook Air every year").
  Vertical SwapCard reads top-to-bottom as substitution + thin
  hairline divider between paid block and alternative block.
  Confirmed-switch toggle states the exact dollar amount credited.

### Updates resilience

- **Magic-byte preflight** in `InstallerEngine.run` catches HTML
  404 pages posing as DMGs (GOOSE VPN case) before hdiutil runs
  — clean message instead of `imagem não reconhecida`.
- **HEAD probe + Range-GET fallback** in `UpdateSweep` validates
  status + Content-Type + length per actionable update; rows
  with a fatal verdict downgrade to "Open page" with explanation.
- **Hard-reject unsupported archives** (.tar / .gz / .tgz / .xz /
  .bz2) at preflight — Splynek's pipeline only handles
  .dmg / .pkg / .zip / .app and won't pretend otherwise.
- **GitHub asset retry**: `pickAssets(_:)` returns a ranked
  `[Asset]` list; when the primary URL preflights fatal,
  `UpdateSweep.run` walks the alternates in order and picks the
  first that passes.  Sparkle / RSS / Homebrew rows with single
  enclosures fall through to legacy single-shot behaviour.
- **Gatekeeper check no longer rejects DMG/PKG/ZIP at the
  container level** — `spctl -t execute` now only runs on
  `.app` direct bundles (DMGs route through hdiutil's own
  block-checksum verify + the `.app` inside gets standard
  quarantine + Gatekeeper at first launch).  Was false-rejecting
  publishers like Zed who only sign the `.app` inside.
- **GitHub asset picker prefers arm64 + drops Intel-only assets**
  unless no arm64 alternative exists.  Refuses Rosetta fallbacks.
- **Auto-rescan after successful install** fires
  `splynekUpdatesDidInstall` so the row drops out of the pending
  list immediately without a tab switch.  Plus
  `replaceExisting: true` in the update click means the old
  `<App>.app` actually goes to Trash instead of suffix-renaming
  to `<App> 2.app`.

### Localization

- **Catalog: 666 strings × 5 locales = 3,330 translations** (was
  628 × 5).  +38 strings covering the design revolution surface:
  - Trust gauge labels (RISK, ACTIVE / UPDATE BLOCKED / MISSING,
    Low/Moderate/High/Severe risk noun-phrases)
  - 14 concern short labels (Tracks across apps, Linked data,
    GDPR fine, FTC action, Regulator fine, Court ruling,
    Sanctioned, Known CVE, Security advisory, Confirmed breach,
    Ad-supported, Default-on telemetry, ToS data-sharing, etc.)
  - Savings hero (RECOVERED, COULD RECOVER, YOUR PLAN, can be
    replaced by, can become, /year, per year, "I've already
    switched", "Tick on a row to start counting", long copy)
  - Updates row states (Update, Update all, Updates available,
    Pending check, Open page, Retry, Installed, etc.) + 7
    pipeline-stage labels (Resolving… / Trust check… /
    Sovereignty check… / Downloading… / Verifying signature… /
    Installing… / Recording install…)
  - Install registry actions (Forget this app, Enable / Disable
    auto-update, Installed via Splynek)
  - History actions (Forget entry, Clear all history, Clear all
    download history?, plus the explanatory help text)
  - Fleet hover labels (Reveal in Finder, Stop sharing on the
    LAN, Move to Trash, plus help text)
  - Downloads (FREE pill, Bond a second network for 2–3× faster
    downloads)
  - Sovereignty + Trust (No installed apps detected. Use Rescan
    in the toolbar., Try again, Scanning installed apps…)
  - "Splynek doesn't support this archive format yet" tar.gz
    fatal preflight message

### Numbers

- Tests: 717 → **740** (+23 — 19 in `HardeningTests.swift` for
  preflight / tier annualisation / DownloadHistory remove+clear /
  isNewer edges; 4 in `UpdateResolverTests.swift` for the new
  ranked `pickAssets`)
- Fresh-DerivedData clean build: **0 warnings** (verified
  2026-05-08)
- xcodebuild schemes verified at every commit: Splynek (free) +
  Splynek-MAS (App Store) + SplynekCompanion (iOS) — all
  BUILD SUCCEEDED

### New architectural pieces

- `Sources/SplynekCore/Installer/InstallPreflight.swift` (216
  lines) — magic-byte detection + URL HEAD probe.  Two surfaces:
  `validateBeforeRun` (post-download) + `previewURL` (pre-click).
- `Sources/SplynekCore/AppUpdates/UpdateSweep.swift` (186 lines)
  — extracted resolver fan-out + URL preflight + retry-on-fatal
  loop.  Single code path shared by foreground UpdatesView checks
  and the background `vm.warmUpdateCount` warm-up.
- `Tests/SplynekTests/HardeningTests.swift` (253 lines) — pure-
  logic coverage for the design-revolution surface.

---

*Last updated 2026-05-08 with the 17-commit design-revolution arc.
Refresh metrics + commit ranges before publishing if additional
rounds land between now and ship.*
