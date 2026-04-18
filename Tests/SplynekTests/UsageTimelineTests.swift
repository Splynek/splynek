import Foundation
@testable import SplynekCore

/// `UsageTimeline` feeds the Charts-based `UsageTimelineView` with
/// pre-shaped points. The grouping logic (top-N across the window,
/// "Other" rollup, today-first ordering, over-cap series split for
/// cellular) has to stay stable — a regression here shows up as a
/// chart legend that shuffles hosts between renders, which users
/// notice immediately.
enum UsageTimelineTests {

    private static func hostEntry(
        _ host: String, _ bytes: Int64, cap: Int64 = 0
    ) -> HostUsageEntry {
        HostUsageEntry(
            host: host, bytesToday: bytes,
            updatedAt: Date(timeIntervalSince1970: 0),
            dailyCap: cap
        )
    }

    static func run() {
        TestHarness.suite("Usage timeline — host data") {

            TestHarness.test("Empty state emits no points") {
                let points = UsageTimeline.hostData(
                    today: HostUsageState(dateString: "2026-04-18", entries: []),
                    history: []
                )
                try expect(points.isEmpty)
            }

            TestHarness.test("Top-N hosts are picked by total bytes across the window") {
                // Today has big + small. History has a completely
                // different host with more bytes than small today.
                // topN=2 should keep big (today) + monster (history),
                // dropping small to Other.
                let today = HostUsageState(dateString: "2026-04-18", entries: [
                    hostEntry("big.example", 1_000_000),
                    hostEntry("small.example", 100)
                ])
                let history = [
                    HostUsageDaily(dateString: "2026-04-17", entries: [
                        hostEntry("monster.example", 5_000_000)
                    ])
                ]
                let points = UsageTimeline.hostData(
                    today: today, history: history, lastNDays: 14, topN: 2
                )
                let series = Set(points.map(\.series))
                try expect(series.contains("big.example"))
                try expect(series.contains("monster.example"))
                try expect(series.contains("Other"),
                           "small.example should be rolled into Other")
                try expect(!series.contains("small.example"),
                           "small.example should NOT appear as its own series")
            }

            TestHarness.test("Today's points come before history points") {
                let today = HostUsageState(dateString: "2026-04-18", entries: [
                    hostEntry("today.example", 100)
                ])
                let history = [
                    HostUsageDaily(dateString: "2026-04-17", entries: [
                        hostEntry("yesterday.example", 100)
                    ])
                ]
                let points = UsageTimeline.hostData(
                    today: today, history: history, topN: 10
                )
                try expect(points.first?.series == "today.example",
                           "today's series should be first, got: \(points.first?.series ?? "nil")")
                try expect(points.last?.series == "yesterday.example")
            }

            TestHarness.test("isToday flag is set only on today's points") {
                let today = HostUsageState(dateString: "2026-04-18", entries: [
                    hostEntry("a.example", 100)
                ])
                let history = [
                    HostUsageDaily(dateString: "2026-04-17", entries: [
                        hostEntry("a.example", 100)
                    ])
                ]
                let points = UsageTimeline.hostData(
                    today: today, history: history, topN: 10
                )
                let todayFlags = points.filter { $0.date == "2026-04-18" }.map(\.isToday)
                let histFlags = points.filter { $0.date == "2026-04-17" }.map(\.isToday)
                try expect(todayFlags.allSatisfy { $0 })
                try expect(histFlags.allSatisfy { !$0 })
            }

            TestHarness.test("Zero-byte Other is suppressed when every host makes top-N") {
                let today = HostUsageState(dateString: "2026-04-18", entries: [
                    hostEntry("a.example", 100),
                    hostEntry("b.example", 50)
                ])
                let points = UsageTimeline.hostData(
                    today: today, history: [], topN: 10
                )
                try expect(!points.contains { $0.series == "Other" },
                           "Other should not appear when every host is in top-N")
            }

            TestHarness.test("lastNDays caps the window") {
                let today = HostUsageState(dateString: "2026-04-18", entries: [
                    hostEntry("today.example", 100)
                ])
                let history = (1...10).map { n in
                    HostUsageDaily(
                        dateString: String(format: "2026-04-%02d", 17 - n),
                        entries: [hostEntry("h\(n).example", Int64(100 + n))]
                    )
                }
                let points = UsageTimeline.hostData(
                    today: today, history: history, lastNDays: 3, topN: 20
                )
                let dates = Set(points.map(\.date))
                // Today + first 2 history days.
                try expectEqual(dates.count, 3)
            }

            TestHarness.test("Top-N ties break by host name alphabetically") {
                // Deterministic top-N — if two hosts have identical
                // byte totals, the one that sorts first alphabetically
                // wins the slot, so the chart doesn't reshuffle
                // between renders.
                let today = HostUsageState(dateString: "2026-04-18", entries: [
                    hostEntry("zeta.example", 100),
                    hostEntry("alpha.example", 100),
                    hostEntry("other.example", 50)
                ])
                let points = UsageTimeline.hostData(
                    today: today, history: [], topN: 2
                )
                let series = Set(points.map(\.series))
                try expect(series.contains("alpha.example"))
                try expect(series.contains("zeta.example"))
                try expect(series.contains("Other"),
                           "other.example should be in Other")
            }
        }

        TestHarness.suite("Usage timeline — cellular data") {

            TestHarness.test("Always emits today even with zero bytes") {
                let today = CellularBudgetState(
                    bytesToday: 0, dateString: "2026-04-18", dailyCap: 0
                )
                let points = UsageTimeline.cellularData(today: today, history: [])
                try expectEqual(points.count, 1)
                try expect(points[0].isToday)
                try expectEqual(points[0].series, "Cellular")
            }

            TestHarness.test("Over-cap day is labelled differently") {
                let today = CellularBudgetState(
                    bytesToday: 2_000, dateString: "2026-04-18", dailyCap: 1_000
                )
                let history = [
                    CellularBudgetDaily(
                        dateString: "2026-04-17",
                        bytesTotal: 500, dailyCap: 1_000   // under cap
                    ),
                    CellularBudgetDaily(
                        dateString: "2026-04-16",
                        bytesTotal: 1_500, dailyCap: 1_000  // over cap
                    )
                ]
                let points = UsageTimeline.cellularData(today: today, history: history)
                try expectEqual(points.count, 3)
                try expectEqual(points[0].series, "Cellular (over cap)")
                try expectEqual(points[1].series, "Cellular")
                try expectEqual(points[2].series, "Cellular (over cap)")
            }

            TestHarness.test("lastNDays caps the window for cellular too") {
                let today = CellularBudgetState(
                    bytesToday: 100, dateString: "2026-04-18", dailyCap: 0
                )
                let history = (1...30).map { n in
                    CellularBudgetDaily(
                        dateString: String(format: "2026-03-%02d", (n % 28) + 1),
                        bytesTotal: Int64(n * 100), dailyCap: 0
                    )
                }
                let points = UsageTimeline.cellularData(
                    today: today, history: history, lastNDays: 7
                )
                try expectEqual(points.count, 7)
            }
        }
    }
}
