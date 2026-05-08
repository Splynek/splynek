// Copyright © 2026 Splynek. MIT.
//
// UpdateSweep — nonisolated, pure-Swift helper that runs the full
// scan + per-source resolve + (optional) URL pre-flight pipeline
// behind a single async entry point.
//
// Background: the resolver dispatch logic was previously private
// to `UpdatesView.checkAll`.  That made it impossible to warm
// `vm.availableUpdateCount` at launch (the user's request: “why
// not run it at the end of launch?”) without duplicating the
// resolver fan-out.  This module hosts the helpers; both
// `UpdatesView.checkAll` and `SplynekViewModel.warmUpdateCount`
// call into it.
//
// Pure-data: returns `[AppUpdateInfo]`.  No view, no VM dependency.
// Network calls happen via URLSession.shared (each resolver has its
// own 15 s timeout).

import Foundation

enum UpdateSweep {

    /// Result row from a single resolver — normalised across
    /// Sparkle / GitHub / publisher RSS so the caller doesn’t have
    /// to switch on the source.
    struct Resolved: Sendable {
        let version: String
        let downloadURL: URL?
        let sizeBytes: Int64?
        let sha256: String?
        let releaseNotes: String?
    }

    /// Run the full sweep against an enumerated installed-app list.
    /// Each app gets:
    ///   1. Source resolution (`UpdateSourceResolver.resolve`)
    ///   2. Source-specific fetch (Sparkle / GitHub / RSS)
    ///   3. URL pre-flight (`InstallPreflight.previewURL`) when an
    ///      `availableDownloadURL` was resolved.
    ///
    /// Returns the populated `AppUpdateInfo` list — empty when the
    /// installed list is empty.  Sources we don’t fetch for
    /// (Homebrew / MAS / unknown) come back with `availableVersion`
    /// nil, matching pre-extraction behaviour.
    static func run(installedApps: [SovereigntyScanner.InstalledApp]) async -> [AppUpdateInfo] {
        var rows: [AppUpdateInfo] = installedApps.map { app in
            let source = UpdateSourceResolver.resolve(
                bundleID: app.id, bundleURL: app.bundleURL
            )
            return AppUpdateInfo(
                bundleID: app.id,
                displayName: app.name,
                installedVersion: app.version ?? "—",
                installedAt: app.bundleURL,
                updateSource: source
            )
        }

        await withTaskGroup(of: (Int, Resolved?).self) { group in
            for (i, info) in rows.enumerated() {
                switch info.updateSource {
                case .sparkle(let feedURL):
                    group.addTask { (i, await resolveSparkle(feedURL: feedURL)) }
                case .githubReleases(let owner, let repo):
                    group.addTask { (i, await resolveGitHub(owner: owner, repo: repo)) }
                case .publisherRSS(let feedURL):
                    group.addTask { (i, await resolvePublisherRSS(feedURL: feedURL)) }
                case .homebrew, .macAppStore, .unknown:
                    continue
                }
            }
            for await (i, result) in group {
                guard let result else { continue }
                rows[i].availableVersion = result.version
                rows[i].availableSizeBytes = result.sizeBytes
                rows[i].availableDownloadURL = result.downloadURL
                rows[i].availableSHA256 = result.sha256
                rows[i].releaseNotes = result.releaseNotes
                rows[i].lastChecked = Date()
            }
        }

        // URL pre-flight per actionable update (HEAD probe).  When
        // `.fatal`, the row gets a manual-only affordance in the UI.
        await withTaskGroup(of: (Int, InstallPreflight.URLPreview).self) { group in
            for (i, info) in rows.enumerated() where info.hasUpdate {
                guard let dl = info.availableDownloadURL else { continue }
                let kind = kindFor(downloadURL: dl)
                group.addTask { (i, await InstallPreflight.previewURL(dl, expectedKind: kind)) }
            }
            for await (i, preview) in group {
                switch preview.verdict {
                case .ok:
                    rows[i].preflight = nil
                case .warning(let reason):
                    rows[i].preflight = .warning(reason)
                case .fatal(let reason):
                    rows[i].preflight = .fatal(reason)
                }
            }
        }
        return rows
    }

    /// How many of the resolved rows are actionable updates (have a
    /// strictly newer upstream version + are not user-ignored).
    static func actionableCount(_ rows: [AppUpdateInfo]) -> Int {
        rows.filter { $0.hasUpdate && $0.updatePolicy != .ignored }.count
    }

    // MARK: - Resolvers (unchanged behaviour, moved out of UpdatesView)

    static func resolveSparkle(feedURL: URL) async -> Resolved? {
        var req = URLRequest(url: feedURL)
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let item = SparkleAppcast.parseLatest(data),
              let version = item.shortVersion ?? item.version
        else { return nil }
        return Resolved(
            version: version,
            downloadURL: item.enclosureURL,
            sizeBytes: item.sizeBytes,
            sha256: item.sha256,
            releaseNotes: item.releaseNotesText
        )
    }

    static func resolveGitHub(owner: String, repo: String) async -> Resolved? {
        guard let url = GitHubReleasesResolver.latestReleaseURL(owner: owner, repo: repo) else {
            return nil
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15
        req.setValue("Splynek/\(SplynekVersion.current) (+https://splynek.app)",
                     forHTTPHeaderField: "User-Agent")
        req.setValue("application/vnd.github+json",
                     forHTTPHeaderField: "Accept")
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let release = GitHubReleasesResolver.parseLatest(data)
        else { return nil }
        var version = release.tagName
        if version.hasPrefix("v") || version.hasPrefix("V") {
            version.removeFirst()
        }
        let asset = GitHubReleasesResolver.pickAsset(release)
        return Resolved(
            version: version,
            downloadURL: asset?.browserDownloadURL,
            sizeBytes: asset?.size,
            sha256: nil,
            releaseNotes: release.body
        )
    }

    static func resolvePublisherRSS(feedURL: URL) async -> Resolved? {
        var req = URLRequest(url: feedURL)
        req.timeoutInterval = 15
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let item = PublisherRSSResolver.parseLatest(data),
              let version = item.version
        else { return nil }
        return Resolved(
            version: version,
            downloadURL: nil,
            sizeBytes: nil,
            sha256: nil,
            releaseNotes: item.title
        )
    }

    /// Map a download URL’s extension to an InstallSpec.Kind so the
    /// preflight knows what magic bytes to expect.
    static func kindFor(downloadURL: URL) -> InstallSpec.Kind {
        let ext = downloadURL.pathExtension.lowercased()
        switch ext {
        case "dmg":          return .dmg
        case "pkg":          return .pkg
        case "app":          return .appBundle
        case "zip", "tar", "gz", "tgz", "xz", "bz2":
            return .appArchive
        default:             return .appArchive
        }
    }
}
