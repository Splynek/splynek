import Foundation
@testable import SplynekCore

/// `UsageCSV` writes CSV that has to survive Excel / Numbers / Google
/// Sheets without manual massaging, so the RFC 4180 escaping has to
/// be right. These tests pin:
///   - the header row appears first, with the documented column set;
///   - today's state is ordered before frozen-day history;
///   - within a day, hosts are sorted by bytes desc so the "who used
///     the most" question is answered at the top;
///   - fields with commas / quotes / CRLF round-trip through the
///     quoting rules correctly.
enum UsageCSVTests {

    private static func makeDate(_ s: String) -> Date {
        let f = ISO8601DateFormatter()
        return f.date(from: s) ?? Date(timeIntervalSince1970: 0)
    }

    static func run() {
        TestHarness.suite("Usage CSV — host usage") {

            TestHarness.test("Empty state produces a header-only CSV") {
                let today = HostUsageState(dateString: "2026-04-18", entries: [])
                let csv = UsageCSV.hostUsageCSV(today: today, history: [])
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true)
                try expectEqual(lines.count, 1)
                try expect(String(lines[0]).contains("date,host,bytes,daily_cap_bytes,over_cap,updated_at"))
            }

            TestHarness.test("Today's rows precede history rows") {
                let today = HostUsageState(
                    dateString: "2026-04-18",
                    entries: [
                        HostUsageEntry(host: "today.example",
                                       bytesToday: 1_000,
                                       updatedAt: makeDate("2026-04-18T10:00:00Z"),
                                       dailyCap: 0)
                    ]
                )
                let history = [
                    HostUsageDaily(
                        dateString: "2026-04-17",
                        entries: [HostUsageEntry(
                            host: "yesterday.example",
                            bytesToday: 500,
                            updatedAt: makeDate("2026-04-17T12:00:00Z"),
                            dailyCap: 0
                        )]
                    )
                ]
                let csv = UsageCSV.hostUsageCSV(today: today, history: history)
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true)
                try expectEqual(lines.count, 3)  // header + today + yesterday
                try expect(String(lines[1]).contains("today.example"))
                try expect(String(lines[2]).contains("yesterday.example"))
            }

            TestHarness.test("Hosts within a day are sorted by bytes descending") {
                let today = HostUsageState(
                    dateString: "2026-04-18",
                    entries: [
                        HostUsageEntry(host: "small.example",
                                       bytesToday: 100,
                                       updatedAt: Date(),
                                       dailyCap: 0),
                        HostUsageEntry(host: "big.example",
                                       bytesToday: 10_000,
                                       updatedAt: Date(),
                                       dailyCap: 0)
                    ]
                )
                let csv = UsageCSV.hostUsageCSV(today: today, history: [])
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true)
                try expect(String(lines[1]).contains("big.example"),
                           "expected biggest host first, got: \(lines[1])")
                try expect(String(lines[2]).contains("small.example"))
            }

            TestHarness.test("over_cap flag reflects the entry's state") {
                let today = HostUsageState(
                    dateString: "2026-04-18",
                    entries: [
                        HostUsageEntry(host: "a.example",
                                       bytesToday: 5_000,
                                       updatedAt: Date(),
                                       dailyCap: 1_000),  // 5000 > 1000 → over
                        HostUsageEntry(host: "b.example",
                                       bytesToday: 100,
                                       updatedAt: Date(),
                                       dailyCap: 1_000)   // 100 < 1000 → under
                    ]
                )
                let csv = UsageCSV.hostUsageCSV(today: today, history: [])
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true).map(String.init)
                let rowA = lines.first { $0.contains("a.example") } ?? ""
                let rowB = lines.first { $0.contains("b.example") } ?? ""
                try expect(rowA.contains(",true,"),
                           "a.example should be over cap — row: \(rowA)")
                try expect(rowB.contains(",false,"),
                           "b.example should be under cap — row: \(rowB)")
            }
        }

        TestHarness.suite("Usage CSV — cellular budget") {

            TestHarness.test("Empty state still emits today as a row") {
                let today = CellularBudgetState(
                    bytesToday: 0, dateString: "2026-04-18", dailyCap: 0
                )
                let csv = UsageCSV.cellularBudgetCSV(today: today, history: [])
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true)
                try expectEqual(lines.count, 2)   // header + today
                try expect(String(lines[0]).contains("date,bytes,daily_cap_bytes,over_cap"))
                try expect(String(lines[1]).hasPrefix("2026-04-18,0,0,"))
            }

            TestHarness.test("History rows follow today in reverse-chronological order") {
                let today = CellularBudgetState(
                    bytesToday: 500, dateString: "2026-04-18", dailyCap: 1_000_000
                )
                let history = [
                    CellularBudgetDaily(dateString: "2026-04-17", bytesTotal: 2_000, dailyCap: 0),
                    CellularBudgetDaily(dateString: "2026-04-16", bytesTotal: 1_000, dailyCap: 0)
                ]
                let csv = UsageCSV.cellularBudgetCSV(today: today, history: history)
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true).map(String.init)
                try expectEqual(lines.count, 4)  // header + today + 2 history
                try expect(lines[1].hasPrefix("2026-04-18,"))
                try expect(lines[2].hasPrefix("2026-04-17,"))
                try expect(lines[3].hasPrefix("2026-04-16,"))
            }

            TestHarness.test("over_cap flag for cellular matches the cap vs. bytes rule") {
                let today = CellularBudgetState(
                    bytesToday: 1_500, dateString: "2026-04-18", dailyCap: 1_000
                )
                let csv = UsageCSV.cellularBudgetCSV(today: today, history: [])
                let lines = csv.split(separator: "\r\n", omittingEmptySubsequences: true).map(String.init)
                try expect(lines[1].hasSuffix(",true"),
                           "expected over_cap=true — row: \(lines[1])")
            }
        }

        TestHarness.suite("Usage CSV — RFC 4180 escaping") {

            TestHarness.test("Plain field passes through unmodified") {
                try expectEqual(UsageCSV.escape("example.com"), "example.com")
            }

            TestHarness.test("Comma in field forces quoting") {
                try expectEqual(UsageCSV.escape("a,b"), "\"a,b\"")
            }

            TestHarness.test("Embedded double-quotes are doubled") {
                // Tricky escape — fails in half of homegrown CSV writers.
                // Input: a"b     Output: "a""b"
                try expectEqual(UsageCSV.escape("a\"b"), "\"a\"\"b\"")
            }

            TestHarness.test("Newline in field forces quoting") {
                try expectEqual(UsageCSV.escape("a\nb"), "\"a\nb\"")
            }

            TestHarness.test("Empty string stays empty, not quoted") {
                try expectEqual(UsageCSV.escape(""), "")
            }

            TestHarness.test("Host with a literal comma round-trips through the full formatter") {
                let today = HostUsageState(
                    dateString: "2026-04-18",
                    entries: [HostUsageEntry(
                        host: "weird,host.example",
                        bytesToday: 42,
                        updatedAt: Date(),
                        dailyCap: 0
                    )]
                )
                let csv = UsageCSV.hostUsageCSV(today: today, history: [])
                try expect(csv.contains("\"weird,host.example\""),
                           "host with comma should be quoted in output")
            }
        }
    }
}
