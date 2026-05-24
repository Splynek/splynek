# IA-V2-MIGRATION-STATUS.md

**Canonical state of the lifecycle-based information-architecture
migration described in `IA-PROPOSAL.md`.**

Next session: read this file to know exactly where the 9-phase
migration is.  Don't scan IA-PROPOSAL.md to find status — that doc
is the design; this doc is the state.

---

## Status at a glance (2026-05-24)

```
Phase 0  Approval + user test     SKIPPED  (Path B — engineering without prior validation)
Phase 1  LifecycleTab enum        DONE     8c10cb9   2026-05-23
Phase 2  4-tab Sidebar + chip bar DONE     d94ab61   2026-05-23
Phase 3  Installed inventory      DONE     2aed5c2   2026-05-23
Phase 4  Stack-level Sovereignty  DONE     a348d85   2026-05-23
Phase 5  Concierge as sheet       DONE     c162c09   2026-05-23
Phase 6  Settings as gear-sheet   DONE     e921e1d   2026-05-23
Phase 7  First-run welcome card   DONE     b08340e   2026-05-23
Phase 7.v14  Sidebar chrome fix   DONE     ca35459   2026-05-24  (d94ab61 chrome restored)
Phase 7.v14d Sidebar alignment    DONE     dcc6a8e   2026-05-24
Phase 8  L10n round 6             DONE     4c664a4   2026-05-24  (44 strings × 5 locales = 220 new translations)
Phase 9  Tests + invariant + docs DONE     <this>    2026-05-24
```

**ALL 9 phases shipped (plus v14 chrome polish + v14d alignment).**
Visible in the running `/Applications/Splynek.app` locally + on local
`main` (now well ahead of `origin/main`; held with the wider rollup
until Apple v1.0 clears MAS re-review).

**Test count: 843** (was 842 — +1 for the Phase 7-8 invariant that
asserts every LifecycleTab's title/promise/slogan is fully localized
in all 5 required locales).  Catalog stands at **948 strings × 5
locales = 4,740 translations**, 100% coverage.

---

## What's visible to the user today

Open `/Applications/Splynek.app` (or `swift run Splynek`) and the
sidebar now shows **4 rows** instead of 17:

| Tab | Icon | Default subview | Chip strip |
|---|---|---|---|
| **Discover** | sparkles | Sovereignty | Sovereignty · Trust · Recipes · Savings · Concierge |
| **Download** | arrow.down.circle | Queue | Queue · Live · Downloads · Torrents · History · Benchmark |
| **My Apps** | shippingbox | **Installed** (NEW) | Installed · Apps (Updates) · Trust Watcher |
| **Coordinate** | laptopcomputer.and.iphone | Fleet | Fleet · Agents |

The new **Installed** subview of My Apps is the migration's marquee
win: it joins Sovereignty + Trust + Updates + Trust Watcher into one
row-per-app inventory, with a Phase-4 hero score at the top.

---

## What's done now

### Phase 8 — L10n round 6 (DONE 2026-05-24, commit 4c664a4)

44 net new IA strings × 5 locales = 220 fresh translations folded
into `Sources/SplynekCore/Localizable.xcstrings` via
`Scripts/regenerate-localizations.py`'s new `IA_V2_STRINGS` dict:

- 3 new tab labels (Discover / My Apps / Coordinate; "Download"
  was already in the catalog as "Transferir").
- 4 tab promises ("Find apps worth installing", etc.).
- 4 tab slogans ("Choose well." / "Get it home." / "Keep watch." /
  "All in sync.").
- 5 welcome-card hero strings (the "Welcome to ", "Your download
  lifecycle, fixed.", the long lifecycle subhead, the
  "Pick a tile above to begin →" CTA).
- 12 welcome-card story-tile bullets (3 per tab).
- 3 trust-strip badge labels.
- 2 Concierge pill strings ("Ask Splynek" + tooltip).
- 6 Installed-inventory strings.
- 7 Trust-Watcher-inbox strings (including a `%lld %lld`
  interpolation key for the empty-state line).

Catalog now: **948 strings × 5 locales = 4,740 translations, 100%
coverage.**  `LocalizableCatalogTests` (the existing completeness
guard) confirms every new key has all 5 required locales filled.

### Phase 9 — Tests + invariants + docs (DONE 2026-05-24)

- **New test invariant in `LifecycleTabTests`**: "every
  LifecycleTab title/promise/slogan is fully localized" — walks
  the 4 tabs × 3 string properties = 12 keys and asserts each one
  is in the catalog with all 5 required locales.  Catches the
  regression where someone adds a tab without translating it.
  Test count is now 843 (was 842).
- A SwiftUI snapshot test for `InstalledInventoryView` was
  scoped out — `swift run splynek-test` doesn't include a SwiftUI
  rendering harness and adding one as a third-party dep violates
  the "zero deps" invariant.  `SovereigntyStackSummaryTests`
  already covers the data model; the view itself is a thin shell.
- A `release-smoke.sh` 4-tab assertion was scoped out — osascript
  AXUI probes against the running window proved brittle across
  locales (sidebar row titles are Localized) and didn't add
  signal beyond what the LifecycleTab + LocalizableCatalog tests
  already give us.
- `IA-V2-MIGRATION-STATUS.md` (this file) marked all 9 phases
  done.
- `HANDOFF.md` + `SESSION-LOG.md` updated to reflect the
  migration completion (Phase 5-9 + sidebar v14/v14c/v14d).
- `SIMPLE-MODE-FIRSTRUN.md` archived as historical — see
  `docs/archive/` or the "What was simple-mode?" footnote.

---

## Files added or substantially changed by Phases 1-7

```
Sources/SplynekCore/Views/LifecycleTab.swift            NEW    Phase 1
Sources/SplynekCore/Views/LifecycleTopBar.swift         NEW    Phase 2
Sources/SplynekCore/Views/InstalledInventoryView.swift  NEW    Phase 3
Sources/SplynekCore/Views/TrustWatcherInboxView.swift   NEW    Phase 3
Sources/SplynekCore/Sovereignty/SovereigntyStackSummary.swift  NEW  Phase 4
Sources/SplynekCore/Views/SettingsSheet.swift           NEW    Phase 6
Sources/SplynekCore/Views/DiscoverWelcomeCard.swift     NEW    Phase 7

Sources/SplynekCore/Views/Sidebar.swift                 MODIFIED  Phase 2 + 5 + 7
Sources/SplynekCore/Views/RootView.swift                MODIFIED  Phase 2 + 3 + 5 + 6 + 7 (welcome-card branch + first-run tab default)
Sources/SplynekCore/Views/LifecycleTopBar.swift         MODIFIED  Phase 5 (trailing accessory + AskSplynekPill)
Sources/SplynekCore/Views/ConciergeView.swift           MODIFIED  Phase 5 (ConciergeSheetContainer)
Sources/SplynekCore/Views/LifecycleTab.swift            MODIFIED  Phase 5 (.concierge out of subviews(.discover))
Sources/SplynekCore/Views/SovereigntyView.swift         MODIFIED  Phase 7 (removed .splynekRunSovereigntyScan listener)
Sources/SplynekCore/ViewModel.swift                     MODIFIED  Phase 7 (hasCompletedOnboarding doc comment)

Sources/SplynekCore/Views/OnboardingSheet.swift         DELETED   Phase 7 (replaced by DiscoverWelcomeCard, -367 lines)

Tests/SplynekTests/LifecycleTabTests.swift              NEW    Phase 1 (+7) + Phase 5 (+3) + Phase 6 (+2)
Tests/SplynekTests/SovereigntyStackSummaryTests.swift   NEW    Phase 4 (+10 tests)
Tests/SplynekTests/main.swift                           MODIFIED  Phase 1 + 4
```

---

## Known visual rough edges (deferred to Phase 5+ polish)

These are real but not blocking the architectural arc:

1. **Sidebar labels in English.**  The 4 lifecycle labels
   ("Discover", "My Apps", "Coordinate") aren't in the L10n
   catalog yet.  Portuguese users see English alongside
   "Transferir" (Download — which IS localized).  Phase 8 fixes.

2. **Status pills visually loud.**  `HAS ALTERNATIVES` and
   `TRUST HIGH` render as bright solid-coloured marker
   highlights on dark mode.  Phase 5 visual polish (use opacity
   gradients matching the docs/mocks/shared.css spec, not Color
   .orange / .yellow directly).

3. **`navigationTitle` always reads "Splynek".**  Each tab
   should set its own title from `LifecycleTab.title`.  Phase 5
   polish.

4. **Download chip strip has 6 chips.**  The wireframes' 3-chip
   design (Now / Active / Done) merges Live/Queue/Downloads/
   Torrents into "Active" via a virtual subview.  Not yet
   implemented — Phase 5+ refinement.

5. **My Apps "Apps" chip is the legacy AppsView wrapper** (which
   itself has Install + Updates internally).  Phase 5+ may
   either rename to "Updates" or split into its own
   `UpdatesView` chip + drop the wrapper.

---

## What to do in the next session

1. **Read this file + HANDOFF.md.**  Skim IA-PROPOSAL.md only if
   you need design rationale.

2. **Verify the running app.**  `open /Applications/Splynek.app`
   — confirm the 4-tab sidebar, the Phase-3 unified Installed
   inventory + Trust Watcher inbox, the Phase-4 hero Sovereignty
   score, the Phase-5 "Ask Splynek" pill (Discover + My Apps
   only), the Phase-6 gear-icon sheet, and the Phase-7 first-run
   welcome card all render correctly.  To verify Phase 7 on an
   already-onboarded install, temporarily flip the persisted flag:
   `defaults write app.splynek.Splynek hasCompletedOnboarding -bool NO`
   then relaunch.

3. **Run the test suite.**  `swift run splynek-test` should
   report **842 passing** (was 837 before Phase 5; +3 Phase-5
   invariants + 2 Phase-6 invariants live in `LifecycleTabTests`;
   Phase 7 added no test deltas — welcome card is pure UI, the
   strings it consumes are already covered by LifecycleTab tab-
   metadata invariants).

4. **Start Phase 8 (L10n round 6).**  Per the touch-points list
   above.  ~0.5 day.  ~35 new English strings need translation
   into de/es/fr/it/pt-PT — most live in the new Phase-3 / -4 / -5
   / -6 / -7 views.

5. **Commit per phase.**  Same pattern as Phases 1-7: one
   focused commit per phase, with a verbose body explaining the
   what + why + verification.

6. **After Phase 9 ships, this file becomes historical.**
   Update HANDOFF.md to remove the IA-v2 in-flight banner.

---

*Document author: Splynek maintainer + Claude.  Created
2026-05-23 evening as the session-handoff anchor for the IA
migration's remaining 5 phases.*
