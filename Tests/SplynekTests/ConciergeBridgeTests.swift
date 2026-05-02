import Foundation
@testable import SplynekCore

/// v1.7: dispatch correctness for LiveConciergeBridge.  Uses fixture
/// data wherever possible so tests are deterministic — production
/// reads from DownloadHistory + filesystem live, but the bridge
/// accepts injected fixtures specifically so tests don't have to.
enum ConciergeBridgeTests {

    static func run() {
        TestHarness.suite("LiveConciergeBridge — dispatch") {

            TestHarness.test("Unknown tool ID returns error card") {
                let bridge = LiveConciergeBridge()
                let inv = ConciergeInvocation(tool: "no_such_tool", args: .object([:]))
                let result = await bridge.dispatch(inv)
                if case .error(let msg) = result.card {
                    try expect(msg.contains("Unknown tool"), "Got message: \(msg)")
                } else {
                    try expect(false, "Expected .error, got \(result.card)")
                }
            }

            TestHarness.test("search_history with empty query returns error") {
                let bridge = LiveConciergeBridge(historyFixture: [])
                let inv = ConciergeInvocation(
                    tool: "search_history",
                    args: .object(["query": .string("")])
                )
                let result = await bridge.dispatch(inv)
                if case .error = result.card { /* expected */ }
                else { try expect(false, "Expected .error, got \(result.card)") }
            }

            TestHarness.test("search_history with no matches returns text card") {
                let bridge = LiveConciergeBridge(historyFixture: [])
                let inv = ConciergeInvocation(
                    tool: "search_history",
                    args: .object(["query": .string("nothing matches this")])
                )
                let result = await bridge.dispatch(inv)
                if case .text(let msg) = result.card {
                    try expect(msg.contains("No matches"), "Got: \(msg)")
                } else {
                    try expect(false, "Expected .text, got \(result.card)")
                }
            }

            TestHarness.test("search_history with matches returns historyMatches card") {
                let entries = [
                    fixtureEntry(filename: "ubuntu-24.04.iso", url: "https://releases.ubuntu.com/24.04/u.iso"),
                    fixtureEntry(filename: "macos-installer.dmg", url: "https://example.com/m.dmg"),
                ]
                let bridge = LiveConciergeBridge(historyFixture: entries)
                let inv = ConciergeInvocation(
                    tool: "search_history",
                    args: .object(["query": .string("ubuntu")])
                )
                let result = await bridge.dispatch(inv)
                if case .historyMatches(let matches) = result.card {
                    try expect(!matches.isEmpty, "Should have at least one match")
                    try expect(matches[0].entry.filename.contains("ubuntu"))
                } else {
                    try expect(false, "Expected .historyMatches, got \(result.card)")
                }
            }

            TestHarness.test("disk_usage without picked folder returns error") {
                let bridge = LiveConciergeBridge(pickedFolder: nil)
                let inv = ConciergeInvocation(tool: "disk_usage", args: .object([:]))
                let result = await bridge.dispatch(inv)
                if case .error(let msg) = result.card {
                    try expect(msg.contains("Pick a folder"), "Got: \(msg)")
                } else {
                    try expect(false, "Expected .error, got \(result.card)")
                }
            }

            TestHarness.test("disk_usage with picked folder returns diskReport") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("concierge-bridge-test-\(UUID())")
                try? FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                defer { try? FileManager.default.removeItem(at: tmp) }
                try Data(repeating: 0xAB, count: 5_000).write(to: tmp.appendingPathComponent("a.bin"))

                let bridge = LiveConciergeBridge(pickedFolder: tmp)
                let inv = ConciergeInvocation(tool: "disk_usage", args: .object([:]))
                let result = await bridge.dispatch(inv)
                if case .diskReport(let report) = result.card {
                    try expect(report.entries.count >= 1, "Should have at least 1 entry")
                } else {
                    try expect(false, "Expected .diskReport, got \(result.card)")
                }
            }

            TestHarness.test("summarize_pdf without picked file returns error") {
                let bridge = LiveConciergeBridge(pickedPDF: nil)
                let inv = ConciergeInvocation(tool: "summarize_pdf", args: .object([:]))
                let result = await bridge.dispatch(inv)
                if case .error(let msg) = result.card {
                    try expect(msg.contains("Pick"), "Got: \(msg)")
                } else {
                    try expect(false, "Expected .error, got \(result.card)")
                }
            }

            TestHarness.test("installed_apps fixture path returns appList") {
                let fixture = [
                    ("Firefox", "org.mozilla.firefox"),
                    ("VLC", "org.videolan.vlc"),
                ]
                let bridge = LiveConciergeBridge(installedAppsFixture: fixture)
                let inv = ConciergeInvocation(tool: "installed_apps", args: .object([:]))
                let result = await bridge.dispatch(inv)
                if case .appList(let pairs) = result.card {
                    try expect(pairs.count == 2, "Got \(pairs.count) entries")
                    try expect(pairs[0].displayName == "Firefox")
                    try expect(pairs[0].bundleID == "org.mozilla.firefox")
                } else {
                    try expect(false, "Expected .appList, got \(result.card)")
                }
            }

            TestHarness.test("download_by_goal returns Pro-defer hint") {
                // The bridge cannot resolve LLM-driven URL search on its
                // own — the Pro Concierge takes over.
                let bridge = LiveConciergeBridge()
                let inv = ConciergeInvocation(
                    tool: "download_by_goal",
                    args: .object(["goal": .string("the latest Ubuntu ISO")])
                )
                let result = await bridge.dispatch(inv)
                if case .text(let msg) = result.card {
                    try expect(msg.contains("Pro Concierge"), "Got: \(msg)")
                } else {
                    try expect(false, "Expected .text, got \(result.card)")
                }
            }

            TestHarness.test("recent_activity with empty history returns text") {
                let bridge = LiveConciergeBridge(historyFixture: [])
                let inv = ConciergeInvocation(tool: "recent_activity", args: .object([:]))
                let result = await bridge.dispatch(inv)
                if case .text(let msg) = result.card {
                    try expect(msg.contains("No downloads"), "Got: \(msg)")
                } else {
                    try expect(false, "Expected .text, got \(result.card)")
                }
            }

            TestHarness.test("Result envelope carries toolID + latency") {
                let bridge = LiveConciergeBridge(historyFixture: [])
                let inv = ConciergeInvocation(tool: "recent_activity", args: .object([:]))
                let result = await bridge.dispatch(inv)
                try expect(result.toolID == "recent_activity")
                try expect(result.latencyMs >= 0, "Latency should be non-negative")
            }
        }
    }

    // MARK: - Fixtures

    static func fixtureEntry(
        filename: String,
        url: String,
        finishedAt: Date = Date()
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID(),
            url: url,
            filename: filename,
            outputPath: "/tmp/\(filename)",
            totalBytes: 1_000_000,
            bytesPerInterface: ["en0": 1_000_000],
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            sha256: nil,
            secondsSaved: nil
        )
    }
}
