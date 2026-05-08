// Copyright © 2026 Splynek. MIT.
//
// GitHubReleasesResolver — fetches the latest release from GitHub's
// REST API and picks the right macOS asset.  Phase 3 follow-up
// (2026-05-07).
//
// API:  GET https://api.github.com/repos/{owner}/{repo}/releases/latest
// Auth: optional (anonymous works at 60 req/h per IP — fine for a
// per-app-on-launch update check).
//
// Asset matching:
//
//   1. Filter to macOS-relevant suffixes — .dmg, .pkg, .zip.  Skip
//      *.tar.gz / .deb / .exe / .AppImage even if the publisher
//      uploaded them (different platforms).
//   2. Prefer arm64 / aarch64 / "universal" / "macos" / "darwin" in
//      the filename when multiple architectures are published.
//   3. Pick the largest matching asset on the assumption that the
//      "main" download is bigger than auxiliary artifacts (sigstore
//      bundles, dSYM, source).
//
// Pure: Codable structs + a `pickAsset(_:)` decision function.
// Network is one URLSession.data call from the UpdatesView caller.
// Tests inject synthetic JSON matching real GitHub API responses.

import Foundation

public enum GitHubReleasesResolver {

    /// Mirrors the subset of the GitHub `/releases/latest` JSON we
    /// use.  Decoded with permissive defaulting so unrecognized
    /// fields don't break parsing.
    public struct Release: Decodable, Equatable, Sendable {
        public let tagName: String
        public let name: String?
        public let body: String?
        public let publishedAt: Date?
        public let assets: [Asset]

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case name
            case body
            case publishedAt = "published_at"
            case assets
        }
    }

    public struct Asset: Decodable, Equatable, Sendable {
        public let name: String
        public let size: Int64
        public let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case size
            case browserDownloadURL = "browser_download_url"
        }
    }

    /// Acceptable extensions for a Mac binary download.  Order
    /// matters when multiple match — the first hit wins, so DMG
    /// (the canonical Mac installer) precedes PKG and ZIP.
    static let macSuffixes = [".dmg", ".pkg", ".zip"]

    /// Hints favoured during arch selection.  When multiple Mac
    /// assets are published, pick the first whose filename matches
    /// any of these in order.  arm64 / aarch64 lead because the
    /// post-2021 Mac fleet is overwhelmingly Apple Silicon, and an
    /// x86_64 binary would run via Rosetta 2 (slower + a translation
    /// hop).  `universal` follows because a fat binary is correct
    /// for both arches.  Generic `macos` / `darwin` only land last
    /// because publishers sometimes ship `Foo-x86_64.dmg` AND
    /// `Foo-macos.dmg` in the same release — we want the explicit
    /// arch label to win.
    static let archHints = [
        "arm64", "aarch64", "apple-silicon",
        "universal",
        "macos", "darwin", "osx"
    ]

    /// Hints that mark an asset as DEFINITELY wrong for an Apple
    /// Silicon Mac.  Filtered out before arch selection so an x86
    /// asset can't win even if no arm64 asset is present — a
    /// Rosetta-only fallback is worse than a clear "no asset".
    static let nonAppleSiliconHints = [
        "x86_64", "x86-64", "intel", "amd64"
    ]

    /// Decode JSON bytes from `/releases/latest` into a Release.
    /// Returns nil on parse failure (rate limit text, schema drift,
    /// network garbage).
    public static func parseLatest(_ data: Data) -> Release? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(Release.self, from: data)
    }

    /// Pick the Mac asset out of a Release.  Returns nil when no
    /// asset matches (Linux-only release, source-only, etc.).
    public static func pickAsset(_ release: Release) -> Asset? {
        pickAssets(release).first
    }

    /// 2026-05-08: ranked list of Mac assets (top choice first).
    /// Used by `UpdateSweep` so when the primary asset's URL fails
    /// the pre-flight HEAD probe (4xx, HTML, weird MIME), the
    /// download flow can retry with the next-best ranked asset
    /// before downgrading the row to manual.  `pickAsset(_:)`
    /// remains available for callers that only want the first.
    public static func pickAssets(_ release: Release) -> [Asset] {
        // Step 1: filter to mac-shaped extensions.
        let macAssets = release.assets.filter { asset in
            let lower = asset.name.lowercased()
            return macSuffixes.contains { lower.hasSuffix($0) }
        }
        guard !macAssets.isEmpty else { return [] }

        // Step 2: drop assets explicitly tagged as Intel/x86 — we
        // refuse Rosetta fallbacks rather than install a slow binary
        // when a publisher just hasn't shipped arm64 yet.  The user
        // can still grab the Intel asset manually via the GitHub
        // release page.
        let archEligible = macAssets.filter { asset in
            let lower = asset.name.lowercased()
            return !nonAppleSiliconHints.contains(where: { lower.contains($0) })
        }
        let pool = archEligible.isEmpty ? macAssets : archEligible

        // Step 3: rank by arch preference.  Each hint produces a
        // batch in source order; later batches catch leftovers.
        // Within a batch, ties are broken by descending size so the
        // installer (typically larger) wins over sidecar artefacts
        // (dSYM, sigstore bundles, source.zip).
        var ranked: [Asset] = []
        var seen = Set<String>()
        for hint in archHints {
            let batch = pool
                .filter { $0.name.lowercased().contains(hint) }
                .sorted { $0.size > $1.size }
            for asset in batch where !seen.contains(asset.name) {
                ranked.append(asset)
                seen.insert(asset.name)
            }
        }
        // Fallback batch: anything left in the pool not yet ranked,
        // by descending size.
        let leftovers = pool
            .filter { !seen.contains($0.name) }
            .sorted { $0.size > $1.size }
        ranked.append(contentsOf: leftovers)
        return ranked
    }

    /// Construct the API URL for a given owner/repo.  Public so
    /// callers (UpdatesView, future cron) can reuse without
    /// hard-coding the path.
    public static func latestReleaseURL(owner: String, repo: String) -> URL? {
        URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")
    }
}
