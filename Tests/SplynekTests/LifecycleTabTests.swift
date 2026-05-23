// Copyright © 2026 Splynek. MIT.
//
// LifecycleTabTests — invariants for the IA-v2 4-tab mapping.
//
// Three claims that protect against silent regressions during the
// IA migration:
//
//   1. Every legacy SidebarSection has a defined LifecycleTab
//      parent (or an explicit nil for the gear-icon sheet cases).
//      The compiler enforces this via exhaustive switch, but the
//      test runs through every case to surface a clear failure
//      message if someone adds a new SidebarSection without
//      thinking about its lifecycle home.
//
//   2. Every LifecycleTab's `defaultSubview` round-trips back to
//      that same tab.  Catches the off-by-one bug where someone
//      sets the default to a section parented in a different tab.
//
//   3. Every LifecycleTab has at least one SidebarSection mapped
//      to it.  Catches the regression where someone refactors a
//      view out of a tab and accidentally orphans the tab.

import Foundation
@testable import SplynekCore

enum LifecycleTabTests {

    static func run() {
        TestHarness.suite("LifecycleTab — IA v2 4-tab mapping") {

            TestHarness.test("Every SidebarSection has a defined LifecycleTab parent or explicit nil") {
                // The exhaustive switch in `LifecycleTabMapping.parent(of:)`
                // makes this a compile-time guarantee; the runtime walk is a
                // belt-and-braces check that adds a clear error message
                // when someone adds a new section without thinking.
                for section in SidebarSection.allCases {
                    let parent = LifecycleTabMapping.parent(of: section)
                    // Settings / Legal / About are explicitly nil (sheet,
                    // not tab).  All others must be tab-parented.
                    if [.settings, .legal, .about].contains(section) {
                        try expect(parent == nil,
                                   "Section \(section) should map to nil (sheet), got \(String(describing: parent))")
                    } else {
                        try expect(parent != nil,
                                   "Section \(section) has no LifecycleTab parent — assign one in LifecycleTabMapping.parent(of:)")
                    }
                }
            }

            TestHarness.test("Default subview of each tab maps back to that tab") {
                for tab in LifecycleTab.allCases {
                    let sub = LifecycleTabMapping.defaultSubview(for: tab)
                    let backToTab = LifecycleTabMapping.parent(of: sub)
                    try expect(backToTab == tab,
                               "Tab \(tab)'s default subview \(sub) maps back to \(String(describing: backToTab)), not \(tab)")
                }
            }

            TestHarness.test("Every LifecycleTab has at least one SidebarSection mapped to it") {
                let coveredTabs = Set(
                    SidebarSection.allCases
                        .compactMap { LifecycleTabMapping.parent(of: $0) }
                )
                let missing = Set(LifecycleTab.allCases).subtracting(coveredTabs)
                try expect(missing.isEmpty,
                           "Some lifecycle tab has zero SidebarSections mapped to it: \(missing)")
            }

            TestHarness.test("subviews(of:) returns only sections that parent to that tab") {
                for tab in LifecycleTab.allCases {
                    let listed = LifecycleTabMapping.subviews(of: tab)
                    for sub in listed {
                        try expect(LifecycleTabMapping.parent(of: sub) == tab,
                                   "Tab \(tab).subviews lists \(sub), which parents to \(String(describing: LifecycleTabMapping.parent(of: sub)))")
                    }
                }
            }

            TestHarness.test("subviews(of:) lists the defaultSubview") {
                for tab in LifecycleTab.allCases {
                    let listed = LifecycleTabMapping.subviews(of: tab)
                    let defaultSub = LifecycleTabMapping.defaultSubview(for: tab)
                    try expect(listed.contains(defaultSub),
                               "Tab \(tab).subviews \(listed) doesn't include the defaultSubview \(defaultSub)")
                }
            }

            TestHarness.test("Tab metadata (title, systemImage, promise) is non-empty for every tab") {
                for tab in LifecycleTab.allCases {
                    try expect(!tab.title.isEmpty, "\(tab) has empty title")
                    try expect(!tab.systemImage.isEmpty, "\(tab) has empty systemImage")
                    try expect(!tab.promise.isEmpty, "\(tab) has empty promise")
                }
            }

            TestHarness.test("Raw values are URL-safe (for splynek://<tab>/<subview> deep links)") {
                let urlSafe = CharacterSet(charactersIn:
                    "abcdefghijklmnopqrstuvwxyz0123456789-")
                for tab in LifecycleTab.allCases {
                    let raw = tab.rawValue
                    let chars = CharacterSet(charactersIn: raw)
                    try expect(chars.isSubset(of: urlSafe),
                               "Tab raw value '\(raw)' contains URL-unsafe characters")
                }
            }

            // ── Phase 5 invariants ───────────────────────────────────
            // Concierge moved from a chip-strip destination to a
            // modal sheet ("Ask Splynek" pill on Discover + My Apps).
            // Two halves of that invariant are tested here so a future
            // refactor that re-adds Concierge as a chip — or that
            // accidentally orphans the routing parent — fails fast.

            TestHarness.test("Phase 5 — .concierge still parents to .discover (semantic anchor)") {
                let parent = LifecycleTabMapping.parent(of: .concierge)
                try expect(parent == .discover,
                           "After Phase 5, .concierge must still parent to .discover so future deep links (splynek://concierge) route there even though it's a sheet, not a chip.  Got \(String(describing: parent)).")
            }

            TestHarness.test("Phase 5 — .concierge is NOT in subviews(of: .discover) (sheet, not chip)") {
                let discoverChips = LifecycleTabMapping.subviews(of: .discover)
                try expect(!discoverChips.contains(.concierge),
                           "Phase 5 of the IA reorg removed Concierge from the chip strip — it's now the 'Ask Splynek' sheet pill.  subviews(.discover) must not list .concierge, but currently does: \(discoverChips).")
            }

            TestHarness.test("Phase 5 — .concierge is NOT in subviews(of:) for ANY tab") {
                // Sheet destinations are never chip destinations; this
                // invariant generalises to any future move.  Catches a
                // regression where someone re-adds Concierge under a
                // different tab thinking the .discover removal was the
                // only blocker.
                for tab in LifecycleTab.allCases {
                    let listed = LifecycleTabMapping.subviews(of: tab)
                    try expect(!listed.contains(.concierge),
                               "Tab \(tab).subviews lists .concierge — Concierge is invoked as a sheet via .splynekShowConcierge, not as a chip.  See ConciergeSheetContainer.")
                }
            }

            // ── Phase 6 invariants ───────────────────────────────────
            // Settings / Legal / About are no longer detail-column
            // destinations.  They live in `SettingsSheet`, invoked
            // from the gear-icon footer + the three legacy menu-bar
            // notifications.  These tests keep the two enums in
            // lockstep so a new "nil-parented" SidebarSection can't
            // silently appear without a SettingsRoute case to host it.

            TestHarness.test("Phase 6 — every SettingsRoute has a matching nil-parent SidebarSection") {
                // Each sheet pane needs a SidebarSection peer with the
                // same name; the section is what menu-bar deep links
                // (legacy) still refer to via the SplynekVersion
                // shortcut path.  Catches a typo or rename.
                for route in SettingsRoute.allCases {
                    let matching = SidebarSection.allCases.first {
                        $0.rawValue == route.rawValue
                    }
                    try expect(matching != nil,
                               "SettingsRoute.\(route) has no matching SidebarSection.\(route.rawValue) — add it back or rename to keep deep-link routing coherent.")
                    if let section = matching {
                        try expect(LifecycleTabMapping.parent(of: section) == nil,
                                   "SettingsRoute.\(route) → SidebarSection.\(section) — section has a LifecycleTab parent, so it's a tab destination, not a sheet pane.  Sheet panes must have nil parent.")
                    }
                }
            }

            TestHarness.test("Phase 6 — every nil-parent SidebarSection has a SettingsRoute pane") {
                // The other direction — a new SidebarSection with nil
                // parent (= "sheet destination") that lacks a
                // SettingsRoute case is unreachable from the gear sheet.
                let sheetSections = SidebarSection.allCases.filter {
                    LifecycleTabMapping.parent(of: $0) == nil
                }
                for section in sheetSections {
                    let matching = SettingsRoute.allCases.first {
                        $0.rawValue == section.rawValue
                    }
                    try expect(matching != nil,
                               "SidebarSection.\(section) has nil LifecycleTab parent (= sheet destination) but no SettingsRoute pane to host it.  Add `case \(section.rawValue)` to SettingsRoute, or give the section a tab parent.")
                }
            }
        }
    }
}
