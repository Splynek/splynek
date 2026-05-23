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
        }
    }
}
