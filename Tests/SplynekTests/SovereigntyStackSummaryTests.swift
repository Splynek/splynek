// Copyright © 2026 Splynek. MIT.
//
// Invariants for SovereigntyStackSummary's pure aggregation logic.
// All tests use the closure-injected `compute(installed:alternativesFor:)`
// path so they don't depend on the real catalog's contents — the
// numbers stay stable as the catalog grows.

@testable import SplynekCore

enum SovereigntyStackSummaryTests {

    private typealias S = SovereigntyStackSummary

    private static func app(_ bundleID: String, _ name: String? = nil) -> S.App {
        S.App(bundleID: bundleID, displayName: name ?? bundleID)
    }

    static func run() {
        TestHarness.suite("SovereigntyStackSummary") {

            TestHarness.test("Empty stack scores 100 and exposes no drag") {
                let s = S.compute(installed: []) { _ in 0 }
                try expect(s.score == 100)
                try expect(s.totalApps == 0)
                try expect(s.flaggedApps.isEmpty)
                try expect(s.biggestDrag == nil)
                try expect(s.level == .excellent)
            }

            TestHarness.test("Stack with zero flagged apps scores 100") {
                let s = S.compute(
                    installed: [app("io.anytype.anytype"), app("org.mozilla.firefox")]
                ) { _ in 0 }
                try expect(s.score == 100)
                try expect(s.totalApps == 2)
                try expect(s.flaggedApps.isEmpty)
                try expect(s.biggestDrag == nil)
            }

            TestHarness.test("Score is inverse fraction of flagged apps") {
                // 4 flagged of 10 → 1 - 0.4 = 0.6 → score 60
                let installed = (0..<10).map { app("app.\($0)") }
                let s = S.compute(installed: installed) { bid in
                    ["app.0", "app.1", "app.2", "app.3"].contains(bid) ? 1 : 0
                }
                try expect(s.totalApps == 10)
                try expect(s.flaggedApps.count == 4)
                try expect(s.score == 60,
                           "expected 60 for 4/10 flagged, got \(s.score)")
            }

            TestHarness.test("All-flagged stack scores 0") {
                let installed = [app("com.notion.Notion"), app("com.spotify.client")]
                let s = S.compute(installed: installed) { _ in 3 }
                try expect(s.score == 0)
                try expect(s.flaggedApps.count == 2)
                try expect(s.level == .poor)
            }

            TestHarness.test("Biggest drag is the flagged app with most alternatives") {
                let installed = [
                    app("com.adobe.Photoshop", "Adobe Photoshop"),
                    app("com.notion.Notion", "Notion"),
                    app("com.spotify.client", "Spotify"),
                ]
                let s = S.compute(installed: installed) { bid in
                    switch bid {
                    case "com.adobe.Photoshop": return 2
                    case "com.notion.Notion":   return 5  // ← most
                    case "com.spotify.client":  return 3
                    default:                    return 0
                    }
                }
                try expect(s.biggestDrag?.app.bundleID == "com.notion.Notion",
                           "biggest drag should be Notion, got \(String(describing: s.biggestDrag?.app.bundleID))")
                try expect(s.biggestDrag?.alternativeCount == 5)
            }

            TestHarness.test("Biggest-drag ties broken alphabetically by display name") {
                let installed = [
                    app("zzz.unknown.app", "ZZZ App"),
                    app("aaa.unknown.app", "AAA App"),
                    app("mmm.unknown.app", "MMM App"),
                ]
                // All tied at 2 alternatives each — alphabetical winner is "AAA App".
                let s = S.compute(installed: installed) { _ in 2 }
                try expect(s.biggestDrag?.app.displayName == "AAA App",
                           "alphabetical tiebreaker should pick AAA App, got \(String(describing: s.biggestDrag?.app.displayName))")
            }

            TestHarness.test("Levels map to score ranges") {
                let cases: [(Int, S.Level)] = [
                    (100, .excellent),
                    (95,  .excellent),
                    (90,  .excellent),
                    (89,  .good),
                    (80,  .good),
                    (70,  .good),
                    (69,  .mixed),
                    (60,  .mixed),
                    (50,  .mixed),
                    (49,  .poor),
                    (10,  .poor),
                    (0,   .poor),
                ]
                for (score, expected) in cases {
                    // Construct a stack with `score`% sovereign: 100 apps,
                    // flag (100 - score) of them.
                    let flaggedCount = 100 - score
                    let installed = (0..<100).map { app("a.\($0)") }
                    let flaggedIDs = Set((0..<flaggedCount).map { "a.\($0)" })
                    let s = S.compute(installed: installed) { bid in
                        flaggedIDs.contains(bid) ? 1 : 0
                    }
                    try expect(s.score == score,
                               "expected score \(score), got \(s.score)")
                    try expect(s.level == expected,
                               "score \(score) should be level \(expected), got \(s.level)")
                }
            }

            TestHarness.test("Caption explains the score") {
                let installed = [
                    app("com.notion.Notion", "Notion"),
                    app("com.spotify.client", "Spotify"),
                    app("org.mozilla.firefox", "Firefox"),
                ]
                let s = S.compute(installed: installed) { bid in
                    bid == "com.notion.Notion" ? 5 : 0
                }
                // Caption should mention the biggest drag.
                try expect(s.caption.contains("Notion"),
                           "caption should call out Notion: \(s.caption)")
                try expect(s.caption.contains("5") || s.caption.contains("alternative"),
                           "caption should mention alternatives count: \(s.caption)")
            }

            TestHarness.test("Empty-stack caption is the 'run a scan' prompt") {
                let s = S.compute(installed: []) { _ in 0 }
                try expect(s.caption.contains("Scan") || s.caption.contains("scan"),
                           "empty-stack caption: \(s.caption)")
            }

            TestHarness.test("All-clean caption acknowledges no flags") {
                let installed = [app("io.anytype.anytype"), app("org.mozilla.firefox")]
                let s = S.compute(installed: installed) { _ in 0 }
                try expect(s.caption.contains("no flagged"),
                           "all-clean caption: \(s.caption)")
            }
        }
    }
}
