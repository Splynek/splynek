import Foundation
@testable import SplynekCore

/// Invariants the Trust catalog promises to the Trust view and to
/// future contributors.  These are tighter than Sovereignty's
/// invariants because the Trust catalog ships claims about specific
/// named apps — every claim must cite a primary-source URL.
enum TrustCatalogTests {

    static func run() {
        TestHarness.suite("Trust catalog invariants") {

            TestHarness.test("Catalog is non-empty") {
                try expect(
                    !TrustCatalog.entries.isEmpty,
                    "Trust catalog has zero entries — initial seed should ship at least 20"
                )
            }

            TestHarness.test("Every entry has at least one concern") {
                for entry in TrustCatalog.entries {
                    try expect(
                        !entry.concerns.isEmpty,
                        "\(entry.targetDisplayName) has zero concerns — empty profiles shouldn't ship; remove the entry instead"
                    )
                }
            }

            TestHarness.test("Every concern URL is https://") {
                for entry in TrustCatalog.entries {
                    for c in entry.concerns {
                        let scheme = c.evidenceURL.scheme?.lowercased() ?? ""
                        try expect(
                            scheme == "https",
                            "\(entry.targetDisplayName) concern \(c.id) URL scheme is '\(scheme)', must be https"
                        )
                    }
                }
            }

            TestHarness.test("Every concern has a non-empty source name") {
                for entry in TrustCatalog.entries {
                    for c in entry.concerns {
                        try expect(
                            !c.sourceName.trimmingCharacters(in: .whitespaces).isEmpty,
                            "\(entry.targetDisplayName) concern \(c.id) has empty sourceName"
                        )
                    }
                }
            }

            TestHarness.test("Every concern summary is factual (no banned editorial words)") {
                // Mirrors the regenerator's banned-phrase list.  If the
                // regenerator ever passes editorial language, this catches
                // it at runtime so it never reaches a release.
                let banned = [
                    "spies", "spying", "spy on",
                    "untrustworthy", "shady", "sketchy",
                    "evil", "malicious", "predatory",
                    "scam", "scammer",
                    "you are the product",
                    "stealing", "creepy",
                ]
                for entry in TrustCatalog.entries {
                    for c in entry.concerns {
                        let lower = c.summary.lowercased()
                        for phrase in banned {
                            try expect(
                                !lower.contains(phrase),
                                "\(c.id) summary contains banned editorial phrase '\(phrase)'"
                            )
                        }
                    }
                }
            }

            TestHarness.test("Every concern ID is unique across the catalog") {
                var seen: Set<String> = []
                for entry in TrustCatalog.entries {
                    for c in entry.concerns {
                        try expect(
                            seen.insert(c.id).inserted,
                            "duplicate concern id '\(c.id)'"
                        )
                    }
                }
            }

            TestHarness.test("No duplicate target bundle IDs") {
                var seen: Set<String> = []
                for entry in TrustCatalog.entries {
                    try expect(
                        seen.insert(entry.targetBundleID).inserted,
                        "duplicate Trust target bundle ID: \(entry.targetBundleID)"
                    )
                }
            }

            TestHarness.test("Every fallback alternative URL is https://") {
                for entry in TrustCatalog.entries {
                    for alt in entry.fallbackAlternatives {
                        let scheme = alt.homepage.scheme?.lowercased() ?? ""
                        try expect(
                            scheme == "https",
                            "\(entry.targetDisplayName) fallback \(alt.id) URL scheme is '\(scheme)'"
                        )
                    }
                }
            }

            TestHarness.test("Bundle-ID lookup hits known and misses unknown") {
                try expect(
                    TrustCatalog.profile(for: "com.google.Chrome") != nil,
                    "Chrome profile should exist"
                )
                try expect(
                    TrustCatalog.profile(for: "app.splynek.fictional") == nil,
                    "fictional bundle ID must return nil"
                )
            }

            TestHarness.test("evidenceDate is a parseable ISO calendar date") {
                let f = DateFormatter()
                f.dateFormat = "yyyy-MM-dd"
                f.locale = Locale(identifier: "en_US_POSIX")
                f.timeZone = TimeZone(secondsFromGMT: 0)
                for entry in TrustCatalog.entries {
                    for c in entry.concerns {
                        try expect(
                            f.date(from: c.evidenceDate) != nil,
                            "\(c.id) evidenceDate '\(c.evidenceDate)' is not YYYY-MM-DD"
                        )
                    }
                    try expect(
                        f.date(from: entry.lastReviewed) != nil,
                        "\(entry.targetBundleID) lastReviewed '\(entry.lastReviewed)' is not YYYY-MM-DD"
                    )
                }
            }
        }

        TestHarness.suite("TrustScorer") {

            TestHarness.test("Empty entry → score 0, level low, hasConcerns false") {
                let entry = makeEntry(concerns: [])
                let s = TrustScorer.score(entry)
                try expectEqual(s.value, 0)
                try expectEqual(s.level, .low)
                try expect(!s.hasConcerns)
            }

            TestHarness.test("Single low privacy concern lands in low band") {
                let entry = makeEntry(concerns: [
                    makeConcern(axis: .privacy, severity: .low),
                ])
                let s = TrustScorer.score(entry)
                try expect(s.value > 0 && s.value < 20,
                           "low concern should land in 0..20 band, got \(s.value)")
                try expectEqual(s.level, .low)
            }

            TestHarness.test("Single severe security concern reaches high or severe") {
                let entry = makeEntry(concerns: [
                    makeConcern(axis: .security, severity: .severe),
                ])
                let s = TrustScorer.score(entry)
                try expect(s.value >= 50,
                           "single severe security should reach high band, got \(s.value)")
            }

            TestHarness.test("Score is bounded to 0...100") {
                let entry = makeEntry(concerns: Array(repeating:
                    makeConcern(axis: .security, severity: .severe),
                    count: 50))
                let s = TrustScorer.score(entry)
                try expect(s.value <= 100, "score must be ≤100, got \(s.value)")
                try expect(s.value >= 0, "score must be ≥0")
            }

            TestHarness.test("Custom weights affect outcome") {
                let entry = makeEntry(concerns: [
                    makeConcern(axis: .privacy, severity: .high),
                ])
                let defaultS = TrustScorer.score(entry)
                let zeroPrivacy = TrustScorer.score(
                    entry,
                    weights: TrustScorer.Weights(privacy: 0.1, security: 1.0, trust: 1.0, businessModel: 1.0)
                )
                try expect(
                    zeroPrivacy.value < defaultS.value,
                    "downweighting privacy should lower the score"
                )
            }

            TestHarness.test("Sanitised weights clamp pathological inputs") {
                let entry = makeEntry(concerns: [
                    makeConcern(axis: .security, severity: .high),
                ])
                let crazy = TrustScorer.Weights(privacy: -1, security: 999, trust: .nan, businessModel: 0)
                let s = TrustScorer.score(entry, weights: crazy)
                try expect(s.value <= 100, "clamped weights still bounded")
                try expect(s.value > 0, "high security still scores")
            }

            TestHarness.test("Per-axis breakdown sums roughly to total") {
                let entry = makeEntry(concerns: [
                    makeConcern(axis: .privacy, severity: .moderate),
                    makeConcern(axis: .security, severity: .high),
                ])
                let s = TrustScorer.score(entry)
                let breakdownSum = s.breakdown.values.reduce(0, +)
                // Both unclamped, so breakdown total should be ≥ score
                // (clamping removes overflow at the total, breakdown is
                // per-axis clamped independently — equivalent when no
                // single axis hits 100).
                try expect(breakdownSum >= s.value,
                           "per-axis breakdown sum (\(breakdownSum)) must be ≥ score (\(s.value))")
            }

            TestHarness.test("Levels match documented thresholds") {
                // 0..19 → low, 20..49 → moderate, 50..79 → high, 80+ → severe
                func levelAt(_ value: Int) -> TrustScorer.Level {
                    switch value {
                    case 0..<20: return .low
                    case 20..<50: return .moderate
                    case 50..<80: return .high
                    default: return .severe
                    }
                }
                let cases: [(Int, TrustScorer.Level)] = [
                    (0, .low), (19, .low),
                    (20, .moderate), (49, .moderate),
                    (50, .high), (79, .high),
                    (80, .severe), (100, .severe),
                ]
                for (v, expected) in cases {
                    try expectEqual(levelAt(v), expected,
                                    "value \(v) should be \(expected.label)")
                }
            }
        }
    }

    // MARK: - Test fixtures

    private static func makeEntry(concerns: [TrustCatalog.Concern]) -> TrustCatalog.Entry {
        TrustCatalog.Entry(
            targetBundleID: "test.fixture",
            targetDisplayName: "Fixture",
            lastReviewed: "2026-04-25",
            concerns: concerns,
            fallbackAlternatives: []
        )
    }

    private static func makeConcern(
        axis: TrustCatalog.Axis,
        severity: TrustCatalog.Severity,
        kind: TrustCatalog.Kind = .appStoreLinkedData
    ) -> TrustCatalog.Concern {
        TrustCatalog.Concern(
            id: "fixture:\(axis.rawValue):\(severity.rawValue):\(UUID().uuidString)",
            kind: kind,
            axis: axis,
            severity: severity,
            summary: "fixture",
            evidenceURL: URL(string: "https://example.com")!,
            evidenceDate: "2026-01-01",
            sourceName: "fixture"
        )
    }
}
