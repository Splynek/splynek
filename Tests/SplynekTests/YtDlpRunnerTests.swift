import Foundation
@testable import SplynekCore

/// Strategy Bet S3 — YtDlpRunner parser tests.  We don't actually
/// invoke yt-dlp from CI (slow, network-dependent, requires the binary
/// installed).  These tests cover the pure parsers — progress / bytes /
/// title — that are the surface yt-dlp's `--newline` output flows
/// through.
enum YtDlpRunnerTests {

    static func run() {
        TestHarness.suite("YtDlpRunner.parseProgressLine") {

            TestHarness.test("Standard progress line") {
                let line = "[download]  47.3% of   12.34MiB at  2.34MiB/s ETA 00:05"
                let pct = YtDlpRunner.parseProgressLine(line)
                try expect(pct != nil, "Should parse")
                if let p = pct {
                    try expect(abs(p - 0.473) < 0.001, "Got \(p)")
                }
            }

            TestHarness.test("Integer percent") {
                let line = "[download] 100% of 50MiB at 5MiB/s ETA 00:00"
                try expectEqual(YtDlpRunner.parseProgressLine(line), 1.0)
            }

            TestHarness.test("Zero percent at start") {
                let line = "[download]   0.0% of 50MiB at 0KiB/s ETA Unknown"
                let pct = YtDlpRunner.parseProgressLine(line)
                try expect(pct != nil)
                if let p = pct {
                    try expect(p == 0)
                }
            }

            TestHarness.test("Non-progress lines return nil") {
                try expect(YtDlpRunner.parseProgressLine("[youtube] dQw4: Some Title") == nil)
                try expect(YtDlpRunner.parseProgressLine("[info] Writing video metadata") == nil)
                try expect(YtDlpRunner.parseProgressLine("") == nil)
                try expect(YtDlpRunner.parseProgressLine("[download] Destination: file.mp4") == nil)
            }

            TestHarness.test("Out-of-range percent rejected") {
                // Defensive: yt-dlp doesn't emit >100% but we shouldn't
                // trust + propagate a value that breaks UI assumptions.
                let line = "[download] 150.5% of 12MiB at 1MiB/s ETA 00:00"
                try expect(YtDlpRunner.parseProgressLine(line) == nil)
            }
        }

        TestHarness.suite("YtDlpRunner.parseDownloadedBytes") {

            TestHarness.test("MiB unit") {
                let line = "[download]  47.3% of   12.34MiB at  2.34MiB/s ETA 00:05"
                let b = YtDlpRunner.parseDownloadedBytes(line)
                try expect(b != nil, "Should parse")
                if let b {
                    let expected = Int64(12.34 * 1024 * 1024)
                    let delta = abs(b - expected)
                    try expect(delta < 1024, "Got \(b), expected ~\(expected)")
                }
            }

            TestHarness.test("KiB unit") {
                let line = "[download]  10% of 500.5KiB at 100KiB/s ETA 00:01"
                let b = YtDlpRunner.parseDownloadedBytes(line)
                try expect(b == Int64(500.5 * 1024))
            }

            TestHarness.test("GiB unit") {
                let line = "[download] 50% of 5.5GiB at 10MiB/s ETA 09:00"
                let b = YtDlpRunner.parseDownloadedBytes(line)
                try expect(b == Int64(5.5 * 1024 * 1024 * 1024))
            }

            TestHarness.test("No unit / no match returns nil") {
                try expect(YtDlpRunner.parseDownloadedBytes("[info] Just a status line") == nil)
                try expect(YtDlpRunner.parseDownloadedBytes("[download] starting…") == nil)
            }
        }

        TestHarness.suite("YtDlpRunner.parseTitle") {

            TestHarness.test("Standard extractor + id + title") {
                let line = "[youtube] dQw4w9WgXcQ: Rick Astley - Never Gonna Give You Up"
                let t = YtDlpRunner.parseTitle(line)
                try expect(t == "Rick Astley - Never Gonna Give You Up", "Got: \(t ?? "nil")")
            }

            TestHarness.test("Twitch extractor") {
                let line = "[twitch:vod] 12345: An Awesome Stream Title"
                try expect(YtDlpRunner.parseTitle(line) == "An Awesome Stream Title")
            }

            TestHarness.test("Progress lines are not titles") {
                let line = "[download]  47.3% of 12.34MiB at 2.34MiB/s ETA 00:05"
                try expect(YtDlpRunner.parseTitle(line) == nil)
            }

            TestHarness.test("Lines without colon return nil") {
                try expect(YtDlpRunner.parseTitle("[info] Writing metadata") == nil)
                try expect(YtDlpRunner.parseTitle("[download] starting...") == nil)
            }

            TestHarness.test("Lines without bracket prefix return nil") {
                try expect(YtDlpRunner.parseTitle("Random line: Title here") == nil)
            }
        }

        TestHarness.suite("YtDlpRunner.DispatchError — equality + descriptions") {

            TestHarness.test("Each case has distinct description text") {
                let descs = [
                    YtDlpRunner.DispatchError.notInstalled.description,
                    YtDlpRunner.DispatchError.sandboxed.description,
                    YtDlpRunner.DispatchError.invocationFailed("test").description,
                    YtDlpRunner.DispatchError.nonZeroExit(1, stderrTail: "x").description,
                    YtDlpRunner.DispatchError.outputMissing.description,
                ]
                try expect(Set(descs).count == 5, "All cases should have unique descriptions")
            }
        }
    }
}
