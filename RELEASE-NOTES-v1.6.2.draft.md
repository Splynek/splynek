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

*Generated 2026-04-30 from `git log v1.5.3~..HEAD` and the catalog
regenerator.  Refresh the metrics row before publishing if more rounds
land between now and ship.*
