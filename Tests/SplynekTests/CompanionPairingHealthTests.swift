import Foundation
import SplynekCompanionCore

/// S4 polish (2026-05-07): tests for `PairingHealthEvaluator` —
/// the pure decision function that classifies each paired Mac as
/// `online` / `recent` / `stale` based on Bonjour discovery + the
/// last-seen timestamp.  Drives the iOS Settings tab's per-Mac
/// status row.
enum CompanionPairingHealthTests {

    static func run() {
        TestHarness.suite("PairingHealth — online (in Bonjour set)") {

            TestHarness.test("Bonjour-visible Mac is online regardless of lastSeen") {
                let now = Date()
                let weekAgo = now.addingTimeInterval(-7 * 86_400)
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: weekAgo,
                    bonjourUUIDs: ["u1", "u2"],
                    now: now
                )
                try expect(h == .online)
            }

            TestHarness.test("Bonjour-visibility ignores other UUIDs") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u-target",
                    lastSeen: now,
                    bonjourUUIDs: ["u-other-1", "u-other-2"],
                    now: now
                )
                // Not in bonjour set + lastSeen is now (recent) → recent
                try expect(h == .recent)
            }
        }

        TestHarness.suite("PairingHealth — recent (not Bonjour, lastSeen ≤ 24h)") {

            TestHarness.test("Last-seen 1 hour ago → recent") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: now.addingTimeInterval(-3_600),
                    bonjourUUIDs: [],
                    now: now
                )
                try expect(h == .recent)
            }

            TestHarness.test("Exactly at threshold (24h) → recent (boundary inclusive)") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: now.addingTimeInterval(-86_400),
                    bonjourUUIDs: [],
                    now: now
                )
                try expect(h == .recent)
            }
        }

        TestHarness.suite("PairingHealth — stale (not Bonjour, lastSeen > 24h)") {

            TestHarness.test("Last-seen 25 hours ago → stale") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: now.addingTimeInterval(-25 * 3_600),
                    bonjourUUIDs: [],
                    now: now
                )
                try expect(h == .stale)
            }

            TestHarness.test("Last-seen weeks ago → stale") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: now.addingTimeInterval(-30 * 86_400),
                    bonjourUUIDs: [],
                    now: now
                )
                try expect(h == .stale)
            }
        }

        TestHarness.suite("PairingHealth — recentThreshold override") {

            TestHarness.test("60s threshold flips a 70-second-old pairing to stale") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: now.addingTimeInterval(-70),
                    bonjourUUIDs: [],
                    now: now,
                    recentThreshold: 60
                )
                try expect(h == .stale)
            }

            TestHarness.test("60s threshold leaves 30-second-old pairing recent") {
                let now = Date()
                let h = PairingHealthEvaluator.evaluate(
                    macUUID: "u1",
                    lastSeen: now.addingTimeInterval(-30),
                    bonjourUUIDs: [],
                    now: now,
                    recentThreshold: 60
                )
                try expect(h == .recent)
            }
        }

        TestHarness.suite("PairingHealth — display labels") {

            TestHarness.test("Each tier has a non-empty user-facing label") {
                try expect(!PairingHealth.online.displayLabel.isEmpty)
                try expect(!PairingHealth.recent.displayLabel.isEmpty)
                try expect(!PairingHealth.stale.displayLabel.isEmpty)
            }

            TestHarness.test("Labels are visually distinct") {
                let labels: Set<String> = [
                    PairingHealth.online.displayLabel,
                    PairingHealth.recent.displayLabel,
                    PairingHealth.stale.displayLabel,
                ]
                try expect(labels.count == 3)
            }
        }
    }
}
