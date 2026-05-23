# IA-V2-MIGRATION-STATUS.md

**Canonical state of the lifecycle-based information-architecture
migration described in `IA-PROPOSAL.md`.**

Next session: read this file to know exactly where the 9-phase
migration is.  Don't scan IA-PROPOSAL.md to find status — that doc
is the design; this doc is the state.

---

## Status at a glance (2026-05-23)

```
Phase 0  Approval + user test     SKIPPED  (Path B — engineering without prior validation)
Phase 1  LifecycleTab enum        DONE     8c10cb9   2026-05-23
Phase 2  4-tab Sidebar + chip bar DONE     d94ab61   2026-05-23
Phase 3  Installed inventory      DONE     2aed5c2   2026-05-23
Phase 4  Stack-level Sovereignty  DONE     a348d85   2026-05-23
Phase 5  Concierge as sheet       DONE     c162c09   2026-05-23
Phase 6  Settings as gear-sheet   DONE     e921e1d   2026-05-23
Phase 7  First-run welcome card   DONE     b08340e   2026-05-23
Phase 8  L10n round 6             PENDING
Phase 9  Tests + smoke + docs     PENDING
```

**7 of 9 phases shipped (≈6 of 7 planned days).**  All
implementation visible in the running `/Applications/Splynek.app`
locally + on local `main` (5 commits ahead of `origin/main`).

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

## What's NOT done yet

### Phase 8 — L10n round 6 (~0.5 d)

New strings introduced in Phases 1-4:
- 4 tab labels: Discover · Download · My Apps · Coordinate
- 4 tab promises (welcome card bullets)
- ~15 strings in InstalledInventoryView (headers, pills, empty
  state, captions)
- ~12 strings in TrustWatcherInboxView (pro gate copy, severity
  labels via `.label`, button labels)
- 4 Sovereignty level labels (Excellent / Good / Mixed / Needs
  attention)
- Phase-5: "Ask Splynek", "Ask Splynek — your local concierge"
  (tooltip), "Close"
- Phase-6: "Settings", "Legal", "About" pane labels in the new
  segmented Picker (already in catalog as section titles —
  double-check no duplication)
- Phase-7: "Welcome to ", "Splynek" (already), the lifecycle
  subhead ("Splynek fixes the broken download lifecycle …"),
  "Tap Discover to start →", "Skip the welcome".  Note: the four
  bullet rows come from `LifecycleTab.title` + `.promise` which
  are already in the catalog (Phase 1's tab metadata).

~40 new English strings need de/es/fr/it/pt-PT.  Use
`Scripts/regenerate-localizations.py`'s existing batch pattern.

### Phase 9 — Tests + smoke + docs (~1 d)

- Add `InstalledInventoryViewSnapshotTests` (a UI smoke that
  verifies the hero + summary card render without crashing on
  three states: empty stack, all-clear stack, populated stack)
- Update `Scripts/release-smoke.sh` to assert the 4-tab sidebar
  is visible (a window-content check via osascript)
- Update `HANDOFF.md` + `SESSION-LOG.md` to reflect the
  migration completion + remove the IA-PROPOSAL "DECISION
  REQUIRED" status
- Mark `SIMPLE-MODE-FIRSTRUN.md` as fully archived — Phase 7
  shipped the new first-run, so this doc is purely historical
  now

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
