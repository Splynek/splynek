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
        /// 2026-05-08: alternate download URLs ranked by preference.
        /// Populated for GitHub Releases (multiple matching assets);
        /// empty for Sparkle / RSS (single enclosure per item).
        var alternateURLs: [URL] = []
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
                if !result.alternateURLs.isEmpty {
                    rows[i].availableAlternateURLs = result.alternateURLs
                }
            }
        }

        // 2026-05-08: hard-reject unsupported archive formats BEFORE
        // a network round-trip.  Splynek's installer pipeline only
        // handles .dmg / .pkg / .zip / .app; if a Sparkle appcast or
        // GitHub Releases entry advertises a `.tar.gz` / `.tgz` /
        // `.xz` / `.bz2` enclosure (e.g. GOOSE VPN), the user would
        // hit a downstream "imagem não reconhecida" or "couldn't
        // unzip" error.  Mark fatal upfront with a clear message so
        // the row downgrades to "Open page" without the user wasting
        // a download.
        let unsupportedExtensions: Set<String> = ["tar", "tgz", "xz", "bz2"]
        for (i, info) in rows.enumerated() where info.hasUpdate {
            guard let dl = info.availableDownloadURL else { continue }
            let lastComp = dl.lastPathComponent.lowercased()
            let ext = dl.pathExtension.lowercased()
            let isTarGz = lastComp.hasSuffix(".tar.gz")
            if isTarGz || unsupportedExtensions.contains(ext) || ext == "gz" {
                rows[i].preflight = .fatal(
                    "Splynek doesn't support this archive format yet. Update manually from the publisher's site."
                )
            }
        }

        // URL pre-flight per actionable update (HEAD probe).  When
        // `.fatal`, the row gets a manual-only affordance in the UI.
        // Skipped for rows already marked fatal above (e.g. tar.gz).
        //
        // 2026-05-08 retry-on-fatal: when the primary download URL
        // preflights fatal AND the row carries `availableAlternateURLs`
        // (GitHub Releases with multiple matching assets), step
        // through the alternates in order and pick the first whose
        // preflight is `.ok` or `.warning`.  Preserves the legacy
        // single-shot behaviour for Sparkle / RSS / Homebrew where
        // there is only one enclosure per update.
        struct PreflightResult: Sendable {
            let chosenURL: URL
            let verdict: InstallPreflight.Verdict
        }
        await withTaskGroup(of: (Int, PreflightResult?).self) { group in
            for (i, info) in rows.enumerated() where info.hasUpdate {
                guard let primary = info.availableDownloadURL else { continue }
                if case .fatal = info.preflight { continue }
                let alternates = info.availableAlternateURLs ?? []
                let candidates = [primary] + alternates
                group.addTask {
                    for url in candidates {
                        let kind = kindFor(downloadURL: url)
                        let preview = await InstallPreflight.previewURL(url, expectedKind: kind)
                        switch preview.verdict {
                        case .ok, .warning:
                            return (i, PreflightResult(chosenURL: url, verdict: preview.verdict))
                        case .fatal:
                            continue
                        }
                    }
                    // Every candidate fatal — return the LAST verdict
                    // so the user sees a real explanation.  Synthesise
                    // a fallback message when there were no candidates.
                    let lastURL = candidates.last ?? primary
                    let kind = kindFor(downloadURL: lastURL)
                    let preview = await InstallPreflight.previewURL(lastURL, expectedKind: kind)
                    return (i, PreflightResult(chosenURL: lastURL, verdict: preview.verdict))
                }
            }
            for await (i, result) in group {
                guard let result else { continue }
                if case .fatal = rows[i].preflight { continue }
                // Promote the chosen URL to the primary slot if the
                // retry picked an alternate — it's the URL that will
                // actually drive the install when the user clicks
                // Update.
                if rows[i].availableDownloadURL != result.chosenURL {
                    rows[i].availableDownloadURL = result.chosenURL
                }
                switch result.verdict {
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
        let assets = GitHubReleasesResolver.pickAssets(release)
        let primary = assets.first
        // Skip the primary in the alternates list — the caller falls
        // back through these in order when preflight rejects the
        // primary.  Cap at 4 alternates: more than that is mostly
        // dSYMs / signature bundles / source.zip noise that won't
        // install regardless.
        let alternates = Array(assets.dropFirst().prefix(4)).map { $0.browserDownloadURL }
        return Resolved(
            version: version,
            downloadURL: primary?.browserDownloadURL,
            sizeBytes: primary?.size,
            sha256: nil,
            releaseNotes: release.body,
            alternateURLs: alternates
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
