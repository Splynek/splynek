import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// PublisherPattern fetches well-known sibling files from publisher
// CDNs (e.g. Mozilla's per-release SHA256SUMS) and parses them to
// extract a SHA-256 digest matching the user's URL.  No code is
// executed against publisher-supplied content; the parser is a
// pure-Swift line-by-line regex over `<hex>  <filename>` form.
// The extracted digest flows into the same `Duplicate.warmCacheLookup`
// path the user-pasted SHA does — so warm-cache short-circuits work
// for download URLs even when the user didn't fill in the SHA-256
// form field manually.
// =====================================================================

/// v1.9.x: publisher-pattern enrichment — augments the existing
/// per-file `.sha256` sibling probe (`Enrichment.probe(_:)`) with
/// per-DIRECTORY digest manifests that publishers ship.  Many
/// publishers (Mozilla, Apache, several Linux distros) put a single
/// `SHA256SUMS` file at the release directory listing every binary's
/// digest; the per-file `.sha256` siblings are absent.
///
/// Why this exists: the v1.9.x "engine warm cache" goal is to
/// short-circuit the WAN download when the user already has the
/// bytes locally.  That trigger fires on digest match — but the
/// user usually doesn't paste a SHA-256 by hand.  PublisherPattern
/// extracts the publisher's-own-SHA from the URL's surrounding
/// directory automatically, so warm-cache works against URLs alone.
///
/// **Scope of this v1.9.x deliverable:** the framework + the Mozilla
/// pattern as a proof-of-concept (Firefox + Thunderbird release
/// directories).  Other patterns (Apache, Debian, Ubuntu, Arch) are
/// follow-up additions — each is a few lines of `Pattern` per
/// publisher.  See "Adding a new publisher" at the bottom of this
/// file.
enum PublisherPattern {

    /// One publisher's digest-extraction strategy.  Self-contained:
    /// `name` for diagnostics + UI, `matches` decides whether this
    /// pattern claims a URL, `extract` does the network probe + parse.
    struct Pattern: Sendable {
        let name: String
        let matches: @Sendable (URL) -> Bool
        let extract: @Sendable (URL, URLSession) async -> String?
    }

    /// All registered patterns.  Walked in order at lookup time;
    /// first hit wins.  Compile-time list — the architectural
    /// invariant from MAS-2.5.2-COMPLIANCE.md is that the publisher-
    /// pattern surface is fixed at build time.
    static let allPatterns: [Pattern] = [
        mozillaReleases,
    ]

    /// Walks `allPatterns` in order; returns the first publisher's
    /// extracted SHA-256, or nil if no pattern claims the URL or
    /// none could extract a digest.
    ///
    /// Times out at 5 seconds total (inherited from `URLSession.shared`).
    /// Designed to fire alongside `Enrichment.probe(_:)` so the user
    /// sees badges + warm-cache hits in the same UI tick.
    static func extractDigest(
        for url: URL,
        session: URLSession = .shared
    ) async -> (publisher: String, digest: String)? {
        for pattern in allPatterns {
            guard pattern.matches(url) else { continue }
            if let digest = await pattern.extract(url, session) {
                return (pattern.name, digest)
            }
        }
        return nil
    }

    // MARK: - Mozilla (Firefox + Thunderbird release CDN)
    //
    // Mozilla publishes per-release SHA256SUMS at:
    //   https://archive.mozilla.org/pub/firefox/releases/<ver>/SHA256SUMS
    //   https://archive.mozilla.org/pub/thunderbird/releases/<ver>/SHA256SUMS
    // and the download CDN URLs follow:
    //   https://download-installer.cdn.mozilla.net/pub/firefox/releases/<ver>/<plat>/<lang>/<filename>
    // For warm-cache lookup we extract the version from the URL,
    // hit the corresponding SHA256SUMS file, and parse out the line
    // that mentions our specific filename.

    static let mozillaReleases = Pattern(
        name: "Mozilla",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host.contains("mozilla.net")
                || host.contains("mozilla.org")
                || host.contains("mozilla.com")
        },
        extract: { url, session in
            // Extract `releases/<version>/...<filename>`.  Use a
            // path-component scan rather than regex so we tolerate
            // either CDN or archive URL shapes.
            let comps = url.pathComponents
            guard let releasesIdx = comps.firstIndex(of: "releases"),
                  releasesIdx + 1 < comps.count,
                  let filename = comps.last
            else { return nil }
            let version = comps[releasesIdx + 1]
            let project = comps.firstIndex(of: "firefox").map { _ in "firefox" }
                ?? comps.firstIndex(of: "thunderbird").map { _ in "thunderbird" }
            guard let proj = project else { return nil }
            // Hit the canonical SHA256SUMS URL on archive.mozilla.org.
            // The CDN host doesn't serve SHA256SUMS reliably; archive.
            // mozilla.org is the canonical record.
            guard let sumsURL = URL(
                string: "https://archive.mozilla.org/pub/\(proj)/releases/\(version)/SHA256SUMS"
            ) else { return nil }
            var req = URLRequest(url: sumsURL)
            req.timeoutInterval = 5
            guard let (data, resp) = try? await session.data(for: req),
                  let http = resp as? HTTPURLResponse,
                  http.statusCode < 400,
                  let body = String(data: data, encoding: .utf8)
            else { return nil }
            return parseSHA256SUMS(body, filename: filename)
        }
    )

    // MARK: - Parsing

    /// Parse a `SHA256SUMS`-style file.  Format (Mozilla, Apache,
    /// Linux distros all match this):
    ///
    ///   <64-hex-char-digest>  <filename>
    ///
    /// Two spaces between digest + filename.  Filename can contain
    /// spaces (rare).  Lines that don't match the format are skipped.
    /// Returns the digest for the line whose filename matches
    /// `filename` (case-sensitive — filenames are case-sensitive on
    /// most Unix CDNs).
    static func parseSHA256SUMS(_ body: String, filename: String) -> String? {
        for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            guard parts.count == 2 else { continue }
            let digest = String(parts[0])
            // The filename half may have a leading `*` for binary mode
            // (RFC 4648) or `./` prefix; normalise.
            var name = String(parts[1]).trimmingCharacters(in: .whitespaces)
            if name.hasPrefix("*") { name.removeFirst() }
            if name.hasPrefix("./") { name = String(name.dropFirst(2)) }
            if name == filename, isHex64(digest) {
                return digest.lowercased()
            }
        }
        return nil
    }

    /// Validate that a string looks like a SHA-256 hex digest.  Used
    /// to guard parseSHA256SUMS from accepting garbage as a digest.
    static func isHex64(_ s: String) -> Bool {
        guard s.count == 64 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}

// =====================================================================
// Adding a new publisher
// =====================================================================
//
// 1. Define a static `Pattern` with:
//      - `name`: short string for UI badge ("Apache", "Debian", etc.)
//      - `matches`: closure returning true for URLs you handle
//      - `extract`: closure that fetches the publisher's manifest
//        and returns the SHA-256 for the URL's specific filename.
//
// 2. Append the new pattern to `PublisherPattern.allPatterns`.
//
// 3. Add a test case to PublisherPatternTests.parseSHA256SUMS section
//    with a real SHA256SUMS fixture from the publisher.
//
// Common publisher patterns you'll want:
//   - Apache: <project>.apache.org/dist/<project>/<ver>/sha256.txt
//   - Debian: cdimage.debian.org/.../SHA256SUMS
//   - Ubuntu: releases.ubuntu.com/<ver>/SHA256SUMS
//   - Arch:   archlinux.org/iso/<ver>/sha256sums.txt
//   - Linux Mint: linuxmint.com/edition.php (HTML, harder)
//   - Fedora: fedoraproject.org/spins-checksum (annual rotation)
//   - Most GitHub release SHASUMs: <repo>/releases/download/<tag>/sha256sums.txt
