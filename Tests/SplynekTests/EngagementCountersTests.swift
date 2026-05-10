import Foundation
@testable import SplynekCore

/// Tests for engagement counters + the Trust+ gate decision.
/// Sprint 3 (2026-05-10).  Pure-logic; no UI wiring exercised here.
enum EngagementCountersTests {

    static func run() {
        TestHarness.suite("Engagement counters + Trust+ gate") {

            TestHarness.test("Empty counters never trigger Trust+ offer") {
                let c = EngagementCounters.empty
                try expect(EngagementGate.shouldOfferTrustPlus(counters: c) == false,
                           "empty engagement should not gate Trust+ offer")
            }

            TestHarness.test("Below threshold: no offer") {
                var c = EngagementCounters.empty
                c.trustWatcherManualRuns = 5
                c.trustWatcherAcksHandled = 5
                // Total = 10; threshold is 20.
                try expect(EngagementGate.shouldOfferTrustPlus(counters: c) == false,
                           "10 < 20 should not gate")
            }

            TestHarness.test("At threshold: offer fires") {
                var c = EngagementCounters.empty
                c.trustWatcherManualRuns = 10
                c.trustWatcherAcksHandled = 5
                c.trustWatcherPagesOpened = 5
                // Total = 20; threshold is 20.
                try expect(EngagementGate.shouldOfferTrustPlus(counters: c),
                           "engagement 20 should gate")
            }

            TestHarness.test("Above threshold: offer fires") {
                var c = EngagementCounters.empty
                c.trustWatcherManualRuns = 30
                try expect(EngagementGate.shouldOfferTrustPlus(counters: c),
                           "high manual-run count alone should gate")
            }

            TestHarness.test("Migrate counters do NOT count toward Trust+ gate") {
                // Trust+ is specifically about Trust Watcher
                // catalog refresh value.  Migrate engagement is
                // user-valuable but a separate feature; it
                // shouldn't tilt the Trust+ decision.
                var c = EngagementCounters.empty
                c.migrateWizardOpens = 100
                c.migrateStepsCompleted = 100
                c.migrateAppsMarkedTotal = 100
                try expect(EngagementGate.shouldOfferTrustPlus(counters: c) == false,
                           "Migrate counters must not trigger Trust+ gate")
            }

            TestHarness.test("Disk store round-trip") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("engagement-test-\(UUID()).json")
                EngagementStore._testOverrideURL = tmp
                defer {
                    try? FileManager.default.removeItem(at: tmp)
                    EngagementStore._testOverrideURL = nil
                }
                let store = EngagementStore()
                store.mutate {
                    $0.trustWatcherViews = 7
                    $0.trustWatcherManualRuns = 3
                }
                let read = store.read()
                try expect(read.trustWatcherViews == 7,
                           "round-trip lost trustWatcherViews")
                try expect(read.trustWatcherManualRuns == 3,
                           "round-trip lost trustWatcherManualRuns")
                try expect(read.firstRecordedAt != nil,
                           "firstRecordedAt should auto-set on first mutate")
                try expect(read.lastUpdatedAt != nil,
                           "lastUpdatedAt should auto-set on every mutate")
            }

            TestHarness.test("firstRecordedAt is sticky") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("engagement-stick-\(UUID()).json")
                EngagementStore._testOverrideURL = tmp
                defer {
                    try? FileManager.default.removeItem(at: tmp)
                    EngagementStore._testOverrideURL = nil
                }
                let store = EngagementStore()
                store.mutate { $0.trustWatcherViews = 1 }
                let first = store.read().firstRecordedAt
                // Advance "real" time + mutate again; firstRecordedAt
                // should NOT change.
                Thread.sleep(forTimeInterval: 1.1)
                store.mutate { $0.trustWatcherViews = 2 }
                let after = store.read().firstRecordedAt
                try expect(first == after,
                           "firstRecordedAt drifted: \(first ?? "nil") → \(after ?? "nil")")
            }
        }
    }
}
