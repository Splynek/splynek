import Foundation
@testable import SplynekCore

/// Invariants the catalog promises to the Sovereignty view and to
/// external contributors.  If a PR adds an entry that breaks these,
/// the test fails loud — cheaper than a bad UX ship.
enum SovereigntyCatalogTests {

    static func run() {
        TestHarness.suite("Sovereignty catalog invariants") {

            TestHarness.test("Every target sits outside the European ecosystem") {
                for entry in SovereigntyCatalog.entries {
                    try expect(
                        !entry.targetOrigin.isRecommendable,
                        "\(entry.targetDisplayName) has targetOrigin=\(entry.targetOrigin.rawValue); European / OSS apps don't belong as sovereignty targets"
                    )
                }
            }

            TestHarness.test("Every alternative is European, OSS, or .other (never US/CN/RU)") {
                // .other is tolerated as a secondary pick (DaVinci —
                // Australia, TablePlus — Singapore, Arq — US-based but
                // bring-your-own-storage) provided the entry also has a
                // strict .europe / .oss / .europeAndOSS pick.  US / CN
                // / RU alternatives are NEVER valid — those are
                // precisely the origins we're helping users step away
                // from.
                for entry in SovereigntyCatalog.entries {
                    for alt in entry.alternatives {
                        try expect(
                            alt.origin != .unitedStates
                                && alt.origin != .china
                                && alt.origin != .russia,
                            "\(entry.targetDisplayName) → alt \(alt.name) has origin=\(alt.origin.rawValue); US / CN / RU apps can never be sovereignty alternatives"
                        )
                    }
                }
            }

            TestHarness.test("Every entry has at least one European-or-OSS alternative") {
                for entry in SovereigntyCatalog.entries {
                    let recommendable = entry.alternatives.filter { $0.origin.isRecommendable }
                    try expect(
                        !recommendable.isEmpty,
                        "\(entry.targetDisplayName) has only .other alternatives — add a European or OSS pick so the entry helps European users"
                    )
                }
            }

            TestHarness.test("Every entry has at least one alternative") {
                for entry in SovereigntyCatalog.entries {
                    try expect(
                        !entry.alternatives.isEmpty,
                        "\(entry.targetDisplayName) has no alternatives — don't list an app we can't help with"
                    )
                }
            }

            TestHarness.test("Alternative IDs are unique across the catalog") {
                var seen: Set<String> = []
                for entry in SovereigntyCatalog.entries {
                    for alt in entry.alternatives {
                        try expect(
                            seen.insert(alt.id).inserted,
                            "duplicate alternative id: \(alt.id)"
                        )
                    }
                }
            }

            TestHarness.test("Bundle-ID lookup finds a known target") {
                // Spot-check a few canonical entries.
                try expect(
                    SovereigntyCatalog.alternatives(for: "com.google.Chrome") != nil,
                    "Chrome should be in the catalog"
                )
                try expect(
                    SovereigntyCatalog.alternatives(for: "com.microsoft.OneDrive") != nil,
                    "OneDrive (v1.4) should be in the catalog"
                )
                try expect(
                    SovereigntyCatalog.alternatives(for: "app.splynek.nonexistent") == nil,
                    "bogus bundle IDs must return nil, not a stub entry"
                )
            }

            TestHarness.test("Catalog is meaningfully large") {
                // v1.4 audit: tightened from "≥ 500" to a tolerance
                // around the expected count.  The earlier loose floor
                // would have let a bad regenerator silently halve the
                // catalog (1167 → 600) without anyone noticing.  The
                // ±50 tolerance accommodates day-to-day PR additions
                // / removals while still catching catastrophic loss.
                let expected = 1155
                let actual = SovereigntyCatalog.entries.count
                try expect(
                    abs(actual - expected) <= 50,
                    "catalog has \(actual) entries; v1.4 expects ~\(expected) (±50). Update this test if growth is intentional."
                )
            }

            TestHarness.test("No (dup-chk) or placeholder markers in target names") {
                // v1.4 audit: bulk-seed scripts use "(dup-chk)" as a
                // workflow marker for entries whose bundle ID needs
                // verification.  These should never reach a release
                // catalog — surface as a hard failure.
                for entry in SovereigntyCatalog.entries {
                    let lower = entry.targetDisplayName.lowercased()
                    try expect(
                        !lower.contains("(dup-chk)")
                            && !lower.contains("(dup chk)")
                            && !lower.contains(" (dup)")
                            && !lower.contains("tbd")
                            && !lower.contains("placeholder"),
                        "\(entry.targetDisplayName) contains a placeholder marker — clean before merge"
                    )
                }
            }

            TestHarness.test("No duplicate bundle IDs across the catalog") {
                // v1.4 audit: byBundleID lookup is first-match-wins,
                // so a duplicate bundle ID would silently suppress one
                // of the entries' alternatives.  validate-catalog.swift
                // catches this offline; this test makes the runtime
                // catalog enforce it too.
                var seen: Set<String> = []
                for entry in SovereigntyCatalog.entries {
                    try expect(
                        seen.insert(entry.targetBundleID).inserted,
                        "duplicate bundle ID: \(entry.targetBundleID)"
                    )
                }
            }
        }
    }
}
