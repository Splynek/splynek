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
        apacheReleases,
        debianReleases,
        ubuntuReleases,
        archReleases,
        githubReleases,
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

    // MARK: - Apache (downloads.apache.org / dist.apache.org)
    //
    // Apache projects publish per-file SHA-256 + per-directory
    // SHA256SUMS (rare).  The MORE common pattern is the per-file
    // sibling .sha256 (which the existing detectSha256Sibling
    // already catches).  Apache also publishes top-level KEYS files
    // for GPG signatures (out of scope for this pattern).
    //
    // Where the per-file sibling missed, we try
    // <project>.apache.org/dist/<project>/<ver>/<filename>.sha256
    // explicitly — same suffix as the cheap probe but a different
    // base path.  If the project has a CDN URL but the user pasted
    // the dist mirror, this catches the digest.
    static let apacheReleases = Pattern(
        name: "Apache",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host.contains("apache.org")
                || host.contains("apache.dist")
        },
        extract: { url, session in
            let siblingURL = url.deletingLastPathComponent()
                .appendingPathComponent(url.lastPathComponent + ".sha256")
            return await fetchSimpleSHA(at: siblingURL, session: session)
        }
    )

    // MARK: - Debian (cdimage.debian.org + ftp.debian.org)
    //
    // Debian publishes per-release SHA256SUMS at the release
    // directory level.  Example URLs:
    //   https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso
    //   https://cdimage.debian.org/debian-cd/12.5.0/amd64/iso-cd/SHA256SUMS
    // We strip the filename, append SHA256SUMS, fetch + parse.
    static let debianReleases = Pattern(
        name: "Debian",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host.contains("debian.org")
        },
        extract: { url, session in
            guard let filename = url.pathComponents.last else { return nil }
            let sumsURL = url.deletingLastPathComponent()
                .appendingPathComponent("SHA256SUMS")
            return await fetchAndParseSUMS(
                at: sumsURL, filename: filename, session: session
            )
        }
    )

    // MARK: - Ubuntu (releases.ubuntu.com + cdimage.ubuntu.com)
    //
    // Same pattern as Debian: per-release SHA256SUMS at the
    // directory level.
    //   https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso
    //   https://releases.ubuntu.com/24.04/SHA256SUMS
    static let ubuntuReleases = Pattern(
        name: "Ubuntu",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host.contains("ubuntu.com")
        },
        extract: { url, session in
            guard let filename = url.pathComponents.last else { return nil }
            let sumsURL = url.deletingLastPathComponent()
                .appendingPathComponent("SHA256SUMS")
            return await fetchAndParseSUMS(
                at: sumsURL, filename: filename, session: session
            )
        }
    )

    // MARK: - Arch Linux (archlinux.org/iso/...)
    //
    // Arch publishes a per-release `sha256sums.txt` (lowercase
    // filename, different from Mozilla's `SHA256SUMS`).  Example:
    //   https://archlinux.org/iso/2024.04.01/archlinux-2024.04.01-x86_64.iso
    //   https://archlinux.org/iso/2024.04.01/sha256sums.txt
    static let archReleases = Pattern(
        name: "Arch",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host.contains("archlinux.org")
        },
        extract: { url, session in
            guard let filename = url.pathComponents.last else { return nil }
            let sumsURL = url.deletingLastPathComponent()
                .appendingPathComponent("sha256sums.txt")
            return await fetchAndParseSUMS(
                at: sumsURL, filename: filename, session: session
            )
        }
    )

    // MARK: - GitHub releases (github.com/<owner>/<repo>/releases/download/...)
    //
    // Most OSS projects on GitHub publish per-tag manifest files
    // alongside their release assets:
    //   https://github.com/<owner>/<repo>/releases/download/<tag>/<asset>
    //   https://github.com/<owner>/<repo>/releases/download/<tag>/sha256sums.txt
    //
    // Two common naming conventions:
    //   - `sha256sums.txt` (lowercase) — ripgrep, fd, bat, eza, helix, …
    //   - `SHA256SUMS`     (uppercase) — less common but follows the
    //     Mozilla / Linux-distro convention
    //
    // Per-asset `.sha256` siblings are also common; those are caught
    // by the cheaper `Enrichment.probe(_:)` path before this pattern
    // even runs.  The framework's cost here is two HTTP HEAD-likes
    // (GET, then 404 short-circuits the second on most projects),
    // returning nil cleanly so the existing per-asset probe takes
    // over for projects that don't ship a manifest.
    //
    // Match scope: only `github.com` URLs whose path contains
    // `/releases/download/`.  GitHub redirects asset GETs to
    // `objects.githubusercontent.com/...` but the user-pasted URL is
    // overwhelmingly the github.com form; we don't try to handle the
    // post-redirect host (its parent directory doesn't expose the
    // manifest).
    static let githubReleases = Pattern(
        name: "GitHub Releases",
        matches: { url in
            guard let host = url.host?.lowercased(), host == "github.com"
            else { return false }
            return url.path.contains("/releases/download/")
        },
        extract: { url, session in
            guard let filename = url.pathComponents.last else { return nil }
            let directory = url.deletingLastPathComponent()
            // Try lowercase first (the GitHub-OSS convention) → uppercase
            // fallback (Mozilla/Linux-distro convention some projects
            // adopt).  First non-nil wins; nil → fall through to the
            // existing per-asset .sha256 sibling probe.
            for manifestName in ["sha256sums.txt", "SHA256SUMS"] {
                let sumsURL = directory.appendingPathComponent(manifestName)
                if let digest = await fetchAndParseSUMS(
                    at: sumsURL, filename: filename, session: session
                ) {
                    return digest
                }
            }
            return nil
        }
    )

    // MARK: - Helpers shared across the new patterns

    /// Fetch + parse a SUMS file for one filename.  Common to
    /// Debian + Ubuntu + Arch + future patterns that follow the
    /// same per-directory-SUMS convention.  Returns nil on
    /// transport failure or parse miss.
    static func fetchAndParseSUMS(
        at sumsURL: URL,
        filename: String,
        session: URLSession
    ) async -> String? {
        var req = URLRequest(url: sumsURL)
        req.timeoutInterval = 5
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              http.statusCode < 400,
              let body = String(data: data, encoding: .utf8)
        else { return nil }
        return parseSHA256SUMS(body, filename: filename)
    }

    /// Fetch a raw `<digest>` or `<digest>  <filename>` text file
    /// (the per-file `.sha256` sibling shape).  The first 64 hex
    /// chars on the first non-empty line are the digest.  Common
    /// to Apache + future patterns whose per-file siblings live
    /// at non-standard URL bases.
    static func fetchSimpleSHA(
        at url: URL,
        session: URLSession
    ) async -> String? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 5
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              http.statusCode < 400,
              let body = String(data: data, encoding: .utf8)
        else { return nil }
        for line in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let first = String(line.split(separator: " ").first ?? "")
            if isHex64(first) { return first.lowercased() }
        }
        return nil
    }

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
