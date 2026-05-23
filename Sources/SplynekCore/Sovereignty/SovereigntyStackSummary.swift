// Copyright © 2026 Splynek. MIT.
//
// SovereigntyStackSummary — IA v2 Phase 4 (2026-05-23).
//
// Pure aggregation that turns the per-app Sovereignty signal
// (each installed app may or may not have a catalog entry pointing
// at EU/OSS alternatives) into a STACK-LEVEL score the user can
// glance at: "Your stack is 85/100 sovereign; the biggest drag is
// Notion — try Anytype."
//
// Before IA v2, the only Sovereignty score the UI showed was
// catalog-level ("we cover 1,247 paid apps").  That's a
// product-fact, not a user-fact.  This summary makes the same
// catalog answer the user's actual question: *MY stack — how
// sovereign is it?*
//
// **Pure compute, zero side-effects.**  Inputs are immutable
// value types so the summary can be unit-tested without spinning
// up the scanner or the catalog cache.  Tests live in
// `SovereigntyStackSummaryTests.swift`.

import Foundation

/// One installed app, in the minimal shape this summary needs.
/// Adapter for `SovereigntyScanner.InstalledApp` — the view layer
/// supplies these by mapping its scanner state, which keeps the
/// summary's API stable if the scanner's internals change.
public struct SovereigntyStackSummary {

    public struct App: Hashable, Sendable {
        public let bundleID: String
        public let displayName: String
        public init(bundleID: String, displayName: String) {
            self.bundleID = bundleID
            self.displayName = displayName
        }
    }

    // MARK: - Inputs

    public let totalApps: Int
    public let flaggedApps: [App]   // apps with a catalog entry
    public let biggestDrag: BiggestDrag?

    /// The single app we recommend replacing first.  Picked as the
    /// flagged app whose catalog entry has the most alternatives
    /// (signal that we've curated it well).  Ties broken
    /// alphabetically for determinism.
    public struct BiggestDrag: Hashable, Sendable {
        public let app: App
        /// How many alternatives our catalog suggests for this
        /// app.  Used in the UI's caption "Try one of N
        /// alternatives →".
        public let alternativeCount: Int
        public init(app: App, alternativeCount: Int) {
            self.app = app
            self.alternativeCount = alternativeCount
        }
    }

    // MARK: - Derived

    /// 0-100.  Inverse of `flaggedFraction × 100`.  Higher = more
    /// sovereign (fewer apps the catalog has flagged with EU/OSS
    /// alternatives).
    ///
    /// **Read with care.**  This is a *proxy*, not a precise number:
    /// it conflates "app is in our flagged catalog" with "app is
    /// US-controlled".  An installed app that's not in the catalog
    /// could be EU-based, OSS, or just unknown to us.  The UI must
    /// always pair the score with the explanatory caption ("we flag
    /// N of your M apps as having EU/OSS alternatives").
    public var score: Int {
        guard totalApps > 0 else { return 100 }
        let flagged = flaggedApps.count
        let fraction = Double(flagged) / Double(totalApps)
        return max(0, min(100, Int((100.0 * (1.0 - fraction)).rounded())))
    }

    /// Categorical level — what UI colour the gauge gets.  Matches
    /// the wireframe's traffic-light scheme.
    public enum Level: String, Sendable {
        case excellent  // 90-100
        case good       // 70-89
        case mixed      // 50-69
        case poor       // 0-49
    }

    public var level: Level {
        switch score {
        case 90...:   return .excellent
        case 70..<90: return .good
        case 50..<70: return .mixed
        default:      return .poor
        }
    }

    /// Pre-rendered subline copy.  Localisable string lives here so
    /// tests can pin the exact text — the view layer just renders.
    public var caption: String {
        if totalApps == 0 {
            return "Scan your installed apps to compute a Sovereignty score."
        }
        if flaggedApps.isEmpty {
            return "Splynek's catalog has no flagged apps in your installed set."
        }
        if let drag = biggestDrag {
            return "Top drag: \(drag.app.displayName) · "
                + "Splynek has \(drag.alternativeCount) "
                + (drag.alternativeCount == 1 ? "alternative" : "alternatives")
                + " for it."
        }
        return "\(flaggedApps.count) of \(totalApps) apps have EU/OSS alternatives in Splynek's catalog."
    }

    // MARK: - Factory

    /// Build a summary from installed apps + the catalog.  Pure —
    /// the catalog is read but not mutated.  O(N) over installed
    /// apps with a single catalog lookup each.
    public static func compute(
        installed: [App],
        alternativesFor: (String) -> Int
    ) -> SovereigntyStackSummary {

        var flagged: [App] = []
        var altCounts: [String: Int] = [:]

        for app in installed {
            let count = alternativesFor(app.bundleID)
            if count > 0 {
                flagged.append(app)
                altCounts[app.bundleID] = count
            }
        }

        // Biggest drag: most alternatives first; alphabetical
        // tiebreaker for deterministic output (important for tests
        // and so the UI doesn't flicker between launches).
        let drag = flagged
            .sorted { lhs, rhs in
                let a = altCounts[lhs.bundleID] ?? 0
                let b = altCounts[rhs.bundleID] ?? 0
                if a != b { return a > b }
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName)
                    == .orderedAscending
            }
            .first
            .map { app in
                BiggestDrag(app: app,
                            alternativeCount: altCounts[app.bundleID] ?? 0)
            }

        return SovereigntyStackSummary(
            totalApps: installed.count,
            flaggedApps: flagged,
            biggestDrag: drag
        )
    }

    /// Convenience — uses the live `SovereigntyCatalog` to count
    /// alternatives.  Production code goes through this; tests use
    /// the closure-based `compute(installed:alternativesFor:)` so
    /// they don't depend on the catalog's contents.
    public static func live(installed: [App]) -> SovereigntyStackSummary {
        compute(installed: installed) { bundleID in
            SovereigntyCatalog.alternatives(for: bundleID)?.alternatives.count ?? 0
        }
    }
}
