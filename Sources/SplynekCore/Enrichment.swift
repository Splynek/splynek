import Foundation

/// Results of the "auto-enrichment" sibling probes that fire whenever a
/// URL is ingested into the form. Each probe is a HEAD against a
/// conventional sibling path; present results become visible badges in
/// the Download form and, where applicable, auto-apply (mirrors from
/// `.metalink`, Merkle manifest from `.splynek-manifest`).
///
/// The motivation: a user pastes `https://example.com/big.iso`. The
/// canonical Splynek story is "we multiply the bytes Across interfaces."
/// But many publishers already ship `big.iso.torrent`, `big.iso.metalink`,
/// and `big.iso.sha256` next to the binary. Other tools force the user
/// to notice and opt in. Splynek finds them, tells the user we did, and
/// folds them into the download automatically. The paste experience
/// becomes: paste a URL, watch four pills light up, click Start.
struct EnrichmentReport: Sendable, Equatable {
    /// URL of the sibling we found, if any. The badge links to it.
    var sha256: URL?
    var signature: URL?          // .asc or .sig
    var torrent: URL?
    var metalink: URL?
    var splynekManifest: URL?

    var isEmpty: Bool {
        sha256 == nil && signature == nil &&
        torrent == nil && metalink == nil &&
        splynekManifest == nil
    }

    /// Convenience for the UI: ordered list of present enrichments with
    /// a display label and a system-symbol name.
    var badges: [Badge] {
        var out: [Badge] = []
        if sha256 != nil {
            out.append(.init(label: "SHA-256", systemImage: "checkmark.seal.fill", tint: .green))
        }
        if signature != nil {
            out.append(.init(label: "Signature", systemImage: "signature", tint: .purple))
        }
        if torrent != nil {
            out.append(.init(label: "Torrent", systemImage: "antenna.radiowaves.left.and.right", tint: .blue))
        }
        if metalink != nil {
            out.append(.init(label: "Metalink", systemImage: "square.stack.3d.up.fill", tint: .pink))
        }
        if splynekManifest != nil {
            out.append(.init(label: "Merkle", systemImage: "chevron.left.forwardslash.chevron.right", tint: .orange))
        }
        return out
    }

    struct Badge: Identifiable, Equatable {
        var id: String { label }
        let label: String
        let systemImage: String
        let tint: EnrichmentTint
    }
}

/// Color identifier mirrored to SwiftUI's `Color` at render time, kept
/// here as a plain enum so `EnrichmentReport` stays Sendable.
enum EnrichmentTint: Equatable {
    case green, purple, blue, pink, orange, accent, secondary
}

/// Fires HEAD probes against conventional sibling paths in parallel and
/// returns the aggregated report. All probes are soft — a failed HEAD
/// just means "this sibling doesn't exist"; never raises.
enum Enrichment {

    static func probe(_ url: URL, timeout: TimeInterval = 4) async -> EnrichmentReport {
        async let sha    = headSibling(url, suffix: ".sha256",            timeout: timeout)
        async let asc    = headSibling(url, suffix: ".asc",               timeout: timeout)
        async let sig    = headSibling(url, suffix: ".sig",               timeout: timeout)
        async let tor    = headSibling(url, suffix: ".torrent",           timeout: timeout)
        async let meta   = headSibling(url, suffix: ".metalink",          timeout: timeout)
        async let meta4  = headSibling(url, suffix: ".meta4",             timeout: timeout)
        async let man    = headSibling(url, suffix: ".splynek-manifest",  timeout: timeout)

        let (shaURL, ascURL, sigURL, torURL, metaURL, meta4URL, manURL) =
            await (sha, asc, sig, tor, meta, meta4, man)

        return EnrichmentReport(
            sha256: shaURL,
            signature: ascURL ?? sigURL,
            torrent: torURL,
            metalink: metaURL ?? meta4URL,
            splynekManifest: manURL
        )
    }

    private static func headSibling(
        _ base: URL, suffix: String, timeout: TimeInterval
    ) async -> URL? {
        let sibling = base.deletingLastPathComponent()
            .appendingPathComponent(base.lastPathComponent + suffix)
        var req = URLRequest(url: sibling)
        req.httpMethod = "HEAD"
        req.timeoutInterval = timeout
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse,
              http.statusCode < 400 else {
            return nil
        }
        return sibling
    }
}

// MARK: - Duplicate detection

/// Historical match for a URL the user is about to download again. Used
/// by the VM's pre-start guard to surface a "you already have this"
/// banner with Reveal / Re-verify / Re-download options, instead of
/// silently launching a second copy.
struct DuplicateMatch: Equatable {
    let entry: HistoryEntry
    let fileExists: Bool

    /// Seconds since the prior completion. Useful for the banner.
    var ageSeconds: TimeInterval { -entry.finishedAt.timeIntervalSinceNow }
}

enum Duplicate {
    /// Search history for a previous completion of the same URL whose
    /// output file is still on disk. Host + path match is the minimum;
    /// we also require the file to still exist so Reveal-in-Finder
    /// works. Returns nil if no hit, or if the previous file has been
    /// deleted (in which case a fresh download is clearly intended).
    static func findMatch(for url: URL, in history: [HistoryEntry]) -> DuplicateMatch? {
        let want = url.absoluteString
        guard let prior = history.last(where: { $0.url == want }) else {
            return nil
        }
        let fm = FileManager.default
        let exists = fm.fileExists(atPath: prior.outputPath)
        if !exists { return nil }
        return DuplicateMatch(entry: prior, fileExists: exists)
    }
}
