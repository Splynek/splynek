import Foundation
@testable import SplynekCore

/// 2026-05-07 phase 3 follow-up: tests for the three update-source
/// resolvers landed alongside the SparkleAppcast parser.
enum UpdateResolverTests {

    static func run() {
        runGitHubReleases()
        runHomebrew()
        runPublisherRSS()
    }

    // MARK: - GitHubReleasesResolver

    static func runGitHubReleases() {
        TestHarness.suite("GitHubReleasesResolver — parseLatest") {

            TestHarness.test("Parses the canonical /releases/latest shape") {
                let json = """
                {
                  "tag_name": "v1.2.3",
                  "name": "Version 1.2.3",
                  "body": "Bug fixes and performance improvements",
                  "published_at": "2024-09-15T12:00:00Z",
                  "assets": [
                    {
                      "name": "App-1.2.3-arm64.dmg",
                      "size": 12345678,
                      "browser_download_url": "https://github.com/o/r/releases/download/v1.2.3/App-1.2.3-arm64.dmg"
                    }
                  ]
                }
                """
                let release = GitHubReleasesResolver.parseLatest(Data(json.utf8))
                try expect(release != nil)
                try expect(release?.tagName == "v1.2.3")
                try expect(release?.assets.count == 1)
                try expect(release?.assets.first?.size == 12345678)
            }

            TestHarness.test("Empty JSON returns nil") {
                try expect(GitHubReleasesResolver.parseLatest(Data()) == nil)
            }

            TestHarness.test("Rate-limit error response returns nil") {
                let rate = """
                {"message": "API rate limit exceeded", "documentation_url": "..."}
                """
                try expect(GitHubReleasesResolver.parseLatest(Data(rate.utf8)) == nil)
            }
        }

        TestHarness.suite("GitHubReleasesResolver — pickAsset (arch preference)") {

            TestHarness.test("arm64 asset wins over x86_64 asset") {
                let release = GitHubReleasesResolver.Release(
                    tagName: "v1.0", name: nil, body: nil, publishedAt: nil,
                    assets: [
                        .init(name: "App-1.0-x86_64.dmg", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/a")!),
                        .init(name: "App-1.0-arm64.dmg", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/b")!),
                    ]
                )
                let pick = GitHubReleasesResolver.pickAsset(release)
                try expect(pick?.name.contains("arm64") == true)
            }

            TestHarness.test("Universal asset wins when arm64 unavailable") {
                let release = GitHubReleasesResolver.Release(
                    tagName: "v1.0", name: nil, body: nil, publishedAt: nil,
                    assets: [
                        .init(name: "App-1.0-x86_64.dmg", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/a")!),
                        .init(name: "App-1.0-universal.dmg", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/b")!),
                    ]
                )
                let pick = GitHubReleasesResolver.pickAsset(release)
                try expect(pick?.name.contains("universal") == true)
            }

            TestHarness.test("Filters out Linux / Windows assets") {
                let release = GitHubReleasesResolver.Release(
                    tagName: "v1.0", name: nil, body: nil, publishedAt: nil,
                    assets: [
                        .init(name: "App-1.0.tar.gz", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/linux")!),
                        .init(name: "App-1.0.deb", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/deb")!),
                        .init(name: "App-1.0.exe", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/win")!),
                        .init(name: "App-1.0-mac.dmg", size: 100,
                              browserDownloadURL: URL(string: "https://x.com/mac")!),
                    ]
                )
                let pick = GitHubReleasesResolver.pickAsset(release)
                try expect(pick?.name.hasSuffix(".dmg") == true)
            }

            TestHarness.test("Returns nil for source-only releases") {
                let release = GitHubReleasesResolver.Release(
                    tagName: "v1.0", name: nil, body: nil, publishedAt: nil,
                    assets: []
                )
                try expect(GitHubReleasesResolver.pickAsset(release) == nil)
            }

            TestHarness.test("Falls back to largest mac asset when no arch hint matches") {
                let release = GitHubReleasesResolver.Release(
                    tagName: "v1.0", name: nil, body: nil, publishedAt: nil,
                    assets: [
                        .init(name: "App-1.0-debug-symbols.dmg", size: 50,
                              browserDownloadURL: URL(string: "https://x.com/dsym")!),
                        .init(name: "App-1.0.dmg", size: 12_000_000,
                              browserDownloadURL: URL(string: "https://x.com/big")!),
                    ]
                )
                let pick = GitHubReleasesResolver.pickAsset(release)
                try expect(pick?.size == 12_000_000)
            }
        }

        TestHarness.suite("GitHubReleasesResolver — latestReleaseURL") {

            TestHarness.test("Composes API URL from owner+repo") {
                let url = GitHubReleasesResolver.latestReleaseURL(
                    owner: "exelban", repo: "stats")
                try expect(url?.absoluteString
                           == "https://api.github.com/repos/exelban/stats/releases/latest")
            }
        }
    }

    // MARK: - HomebrewResolver

    static func runHomebrew() {
        TestHarness.suite("HomebrewResolver — parseOutdated") {

            TestHarness.test("Parses canonical brew outdated --cask --json") {
                let json = """
                {
                  "casks": [
                    {
                      "name": "iterm2",
                      "installed_versions": ["3.5.10"],
                      "current_version": "3.5.11",
                      "pinned": false,
                      "pinned_version": null
                    },
                    {
                      "name": "vscodium",
                      "installed_versions": ["1.94.0", "1.94.1"],
                      "current_version": "1.95.0",
                      "pinned": false,
                      "pinned_version": null
                    }
                  ]
                }
                """
                let report = HomebrewResolver.parseOutdated(Data(json.utf8))
                try expect(report?.casks.count == 2)
                try expect(report?.casks.first?.name == "iterm2")
            }

            TestHarness.test("Empty casks array round-trips fine") {
                let json = """
                {"casks": []}
                """
                let report = HomebrewResolver.parseOutdated(Data(json.utf8))
                try expect(report?.casks.isEmpty == true)
            }

            TestHarness.test("Malformed JSON returns nil") {
                try expect(HomebrewResolver.parseOutdated(Data("not json".utf8)) == nil)
            }
        }

        TestHarness.suite("HomebrewResolver — entry / hasUpdate") {

            TestHarness.test("entry(for:in:) finds matching cask") {
                let report = HomebrewResolver.OutdatedReport(casks: [
                    .init(name: "stats", installedVersions: ["2.10.0"], currentVersion: "2.11.0")
                ])
                try expect(HomebrewResolver.entry(for: "stats", in: report)?.currentVersion
                           == "2.11.0")
            }

            TestHarness.test("entry(for:in:) returns nil for missing cask") {
                let report = HomebrewResolver.OutdatedReport(casks: [])
                try expect(HomebrewResolver.entry(for: "nope", in: report) == nil)
            }

            TestHarness.test("hasUpdate true when current > installed") {
                let report = HomebrewResolver.OutdatedReport(casks: [
                    .init(name: "stats", installedVersions: ["2.10.0"], currentVersion: "2.11.0")
                ])
                try expect(HomebrewResolver.hasUpdate("stats", in: report))
            }

            TestHarness.test("hasUpdate false when versions match") {
                let report = HomebrewResolver.OutdatedReport(casks: [
                    .init(name: "stats", installedVersions: ["2.11.0"], currentVersion: "2.11.0")
                ])
                try expect(!HomebrewResolver.hasUpdate("stats", in: report))
            }
        }

        TestHarness.suite("HomebrewResolver — installCommand") {

            TestHarness.test("Composes brew upgrade command") {
                try expect(HomebrewResolver.installCommand(for: "iterm2")
                           == "brew upgrade --cask iterm2")
            }
        }
    }

    // MARK: - PublisherRSSResolver

    static func runPublisherRSS() {
        TestHarness.suite("PublisherRSSResolver — extractVersion regex") {

            TestHarness.test("Extracts plain semver from title") {
                try expect(PublisherRSSResolver.extractVersion(from: "Kdenlive 24.05.0 released")
                           == "24.05.0")
            }

            TestHarness.test("Strips leading 'v' prefix") {
                try expect(PublisherRSSResolver.extractVersion(from: "v1.2.3 - Release Notes")
                           == "1.2.3")
            }

            TestHarness.test("Tolerates trailing modifiers like 'LTS'") {
                try expect(PublisherRSSResolver.extractVersion(from: "Blender 4.2.1 LTS")
                           == "4.2.1")
            }

            TestHarness.test("Returns nil when no version present") {
                try expect(PublisherRSSResolver.extractVersion(from: "Welcome to our blog") == nil)
            }
        }

        TestHarness.suite("PublisherRSSResolver — parseLatest (RSS 2.0)") {

            TestHarness.test("Parses minimal RSS 2.0 feed") {
                let xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <rss version="2.0">
                  <channel>
                    <title>Kdenlive News</title>
                    <item>
                      <title>Kdenlive 24.05.0 released</title>
                      <link>https://kdenlive.org/24.05.0</link>
                      <pubDate>Mon, 13 May 2024 09:00:00 +0000</pubDate>
                    </item>
                  </channel>
                </rss>
                """
                let item = PublisherRSSResolver.parseLatest(Data(xml.utf8))
                try expect(item != nil)
                try expect(item?.version == "24.05.0")
                try expect(item?.link?.absoluteString == "https://kdenlive.org/24.05.0")
            }

            TestHarness.test("Returns first item only (reverse-chrono)") {
                let xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <rss version="2.0">
                  <channel>
                    <item><title>App 2.0.0</title><link>https://x.com/2</link></item>
                    <item><title>App 1.9.0</title><link>https://x.com/1</link></item>
                  </channel>
                </rss>
                """
                let item = PublisherRSSResolver.parseLatest(Data(xml.utf8))
                try expect(item?.version == "2.0.0")
            }
        }

        TestHarness.suite("PublisherRSSResolver — parseLatest (Atom 1.0)") {

            TestHarness.test("Parses Atom feed with link href attribute") {
                let xml = """
                <?xml version="1.0" encoding="utf-8"?>
                <feed xmlns="http://www.w3.org/2005/Atom">
                  <title>Blender Releases</title>
                  <entry>
                    <title>Blender 4.2.1 LTS</title>
                    <link href="https://blender.org/download/4.2.1/"/>
                    <published>2024-08-19T00:00:00Z</published>
                  </entry>
                </feed>
                """
                let item = PublisherRSSResolver.parseLatest(Data(xml.utf8))
                try expect(item?.version == "4.2.1")
                try expect(item?.link?.host == "blender.org")
            }

            TestHarness.test("Empty body returns nil") {
                try expect(PublisherRSSResolver.parseLatest(Data()) == nil)
            }
        }
    }
}
