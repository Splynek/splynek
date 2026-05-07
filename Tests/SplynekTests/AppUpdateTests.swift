import Foundation
@testable import SplynekCore

/// 2026-05-07 product expansion phase 3: tests for AppUpdateInfo,
/// UpdateSourceResolver, and SparkleAppcast — the pure layers that
/// back the Updates tab.  Network round-trips are tested with
/// real Sparkle feeds at runtime; these unit tests cover the
/// deterministic surfaces.
enum AppUpdateTests {

    static func run() {
        TestHarness.suite("AppUpdateInfo.isNewer — semver compare") {

            TestHarness.test("Plain numeric: 1.2.3 < 1.2.4 → true") {
                try expect(AppUpdateInfo.isNewer(installed: "1.2.3", available: "1.2.4"))
            }
            TestHarness.test("Plain numeric: 1.2.3 < 2.0.0 → true") {
                try expect(AppUpdateInfo.isNewer(installed: "1.2.3", available: "2.0.0"))
            }
            TestHarness.test("Equal: 1.2.3 == 1.2.3 → false") {
                try expect(!AppUpdateInfo.isNewer(installed: "1.2.3", available: "1.2.3"))
            }
            TestHarness.test("Older: 2.0.0 vs 1.9.9 → false (no downgrade)") {
                try expect(!AppUpdateInfo.isNewer(installed: "2.0.0", available: "1.9.9"))
            }
            TestHarness.test("Strips leading 'v': v1.2.3 < v1.2.4 → true") {
                try expect(AppUpdateInfo.isNewer(installed: "v1.2.3", available: "v1.2.4"))
            }
            TestHarness.test("Strips '-beta' suffix: 1.2.3-beta == 1.2.3 → false") {
                try expect(!AppUpdateInfo.isNewer(installed: "1.2.3-beta", available: "1.2.3"))
            }
            TestHarness.test("Different segment counts: 1.2 < 1.2.1 → true") {
                try expect(AppUpdateInfo.isNewer(installed: "1.2", available: "1.2.1"))
            }
            TestHarness.test("Date-shaped version: 2024.10.05 < 2024.10.06 → true") {
                try expect(AppUpdateInfo.isNewer(installed: "2024.10.05", available: "2024.10.06"))
            }
        }

        TestHarness.suite("AppUpdateInfo.hasUpdate") {

            TestHarness.test("nil availableVersion → no update") {
                let info = AppUpdateInfo(
                    bundleID: "x", displayName: "X",
                    installedVersion: "1.0", installedAt: URL(fileURLWithPath: "/Applications/X.app"),
                    updateSource: .unknown,
                    availableVersion: nil)
                try expect(!info.hasUpdate)
            }
            TestHarness.test("Newer availableVersion → has update") {
                let info = AppUpdateInfo(
                    bundleID: "x", displayName: "X",
                    installedVersion: "1.0", installedAt: URL(fileURLWithPath: "/Applications/X.app"),
                    updateSource: .sparkle(feedURL: URL(string: "https://x.com/feed.xml")!),
                    availableVersion: "1.1")
                try expect(info.hasUpdate)
            }
        }

        TestHarness.suite("AppUpdateInfo.availableSizeFormatted") {

            TestHarness.test("MiB formatting: 5_242_880 → '5 MiB'") {
                var info = AppUpdateInfo(
                    bundleID: "x", displayName: "X",
                    installedVersion: "1.0", installedAt: URL(fileURLWithPath: "/Applications/X.app"),
                    updateSource: .unknown)
                info.availableSizeBytes = 5_242_880
                try expect(info.availableSizeFormatted == "5 MiB")
            }
            TestHarness.test("GiB formatting: 2 GiB → '2.0 GiB'") {
                var info = AppUpdateInfo(
                    bundleID: "x", displayName: "X",
                    installedVersion: "1.0", installedAt: URL(fileURLWithPath: "/Applications/X.app"),
                    updateSource: .unknown)
                info.availableSizeBytes = 2 * 1024 * 1024 * 1024
                try expect(info.availableSizeFormatted == "2.0 GiB")
            }
            TestHarness.test("Zero bytes → nil") {
                var info = AppUpdateInfo(
                    bundleID: "x", displayName: "X",
                    installedVersion: "1.0", installedAt: URL(fileURLWithPath: "/Applications/X.app"),
                    updateSource: .unknown)
                info.availableSizeBytes = 0
                try expect(info.availableSizeFormatted == nil)
            }
        }

        TestHarness.suite("UpdateSource — display labels") {

            TestHarness.test("Each source has a non-empty label") {
                let cases: [UpdateSource] = [
                    .sparkle(feedURL: URL(string: "https://x.com/feed.xml")!),
                    .githubReleases(owner: "o", repo: "r"),
                    .macAppStore(adamID: "1"),
                    .homebrew(formulaName: "x"),
                    .publisherRSS(feedURL: URL(string: "https://x.com/r.xml")!),
                    .unknown,
                ]
                for c in cases {
                    try expect(!c.displayLabel.isEmpty)
                }
            }
        }

        TestHarness.suite("UpdateSourceResolver — Sparkle feed from Info.plist") {

            TestHarness.test("Reads SUFeedURL when present") {
                Task { @MainActor in
                    let plist: [String: Any] = ["SUFeedURL": "https://x.com/feed.xml"]
                    let src = UpdateSourceResolver.resolve(
                        bundleID: "com.x.x",
                        bundleURL: URL(fileURLWithPath: "/Applications/X.app"),
                        infoPlist: plist)
                    if case .sparkle(let url) = src {
                        try expect(url.host == "x.com")
                    } else {
                        try expect(false, "Expected .sparkle source")
                    }
                }
            }
            TestHarness.test("Rejects http:// SUFeedURL (https-only)") {
                Task { @MainActor in
                    let plist: [String: Any] = ["SUFeedURL": "http://insecure.com/feed.xml"]
                    let src = UpdateSourceResolver.resolve(
                        bundleID: "com.unknown.app",
                        bundleURL: URL(fileURLWithPath: "/Applications/X.app"),
                        infoPlist: plist)
                    if case .unknown = src {
                        try expect(true)
                    } else {
                        try expect(false, "Expected .unknown for http:// feed")
                    }
                }
            }
            TestHarness.test("Falls through to wellKnownSources when no Sparkle feed") {
                Task { @MainActor in
                    let src = UpdateSourceResolver.resolve(
                        bundleID: "com.exelban.Stats",
                        bundleURL: URL(fileURLWithPath: "/Applications/Stats.app"),
                        infoPlist: [:])
                    if case .githubReleases(let owner, let repo) = src {
                        try expect(owner == "exelban")
                        try expect(repo == "stats")
                    } else {
                        try expect(false, "Expected GitHub for Stats")
                    }
                }
            }
            TestHarness.test("Returns .unknown for unmapped apps") {
                Task { @MainActor in
                    let src = UpdateSourceResolver.resolve(
                        bundleID: "com.completely.unknown",
                        bundleURL: URL(fileURLWithPath: "/Applications/X.app"),
                        infoPlist: [:])
                    if case .unknown = src {
                        try expect(true)
                    } else {
                        try expect(false)
                    }
                }
            }
        }

        TestHarness.suite("SparkleAppcast.parseLatest") {

            TestHarness.test("Parses minimal Sparkle 2.x appcast") {
                let xml = """
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <title>X</title>
    <item>
      <title>Version 1.5.0</title>
      <sparkle:version>150</sparkle:version>
      <sparkle:shortVersionString>1.5.0</sparkle:shortVersionString>
      <description>Bug fixes and performance improvements</description>
      <enclosure url="https://x.com/X-1.5.0.dmg" length="12345678" sparkle:version="150" sparkle:shortVersionString="1.5.0" />
    </item>
  </channel>
</rss>
"""
                let item = SparkleAppcast.parseLatest(Data(xml.utf8))
                try expect(item != nil)
                try expect(item?.shortVersion == "1.5.0")
                try expect(item?.enclosureURL?.absoluteString == "https://x.com/X-1.5.0.dmg")
                try expect(item?.sizeBytes == 12345678)
                try expect(item?.releaseNotesText?.contains("Bug fixes") == true)
            }

            TestHarness.test("Empty body returns nil") {
                try expect(SparkleAppcast.parseLatest(Data()) == nil)
            }

            TestHarness.test("Returns first item only (reverse-chrono convention)") {
                let xml = """
<?xml version="1.0" encoding="utf-8"?>
<rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" version="2.0">
  <channel>
    <item>
      <sparkle:shortVersionString>2.0.0</sparkle:shortVersionString>
      <enclosure url="https://x.com/X-2.0.0.dmg" length="100" />
    </item>
    <item>
      <sparkle:shortVersionString>1.9.0</sparkle:shortVersionString>
      <enclosure url="https://x.com/X-1.9.0.dmg" length="50" />
    </item>
  </channel>
</rss>
"""
                let item = SparkleAppcast.parseLatest(Data(xml.utf8))
                try expect(item?.shortVersion == "2.0.0")
                try expect(item?.enclosureURL?.absoluteString == "https://x.com/X-2.0.0.dmg")
            }
        }
    }
}
