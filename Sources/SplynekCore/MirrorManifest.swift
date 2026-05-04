import Foundation

// =====================================================================
// Bet S2 — Unbreakable Resume (component 3 of 3)
// =====================================================================
//
// `MirrorManifest` is the curated list of fallback download mirrors
// the engine should try when the primary URL starts returning
// 403/404/500 or sustained slowdowns.  Pure data + URL-transform
// functions; no network I/O lives in this type.
//
// Design pattern mirrors `PublisherPattern`: a `MirrorSet` declares
// `matches` (does this set claim this URL?) + `alternatives` (given
// the primary, return ranked replacement URLs).  Compile-time list,
// no runtime registration — same MAS-2.5.2 invariant the rest of the
// publisher-aware code follows.
//
// **Scope of this commit:** the framework + Ubuntu as the curated
// proof-of-concept (releases.ubuntu.com → 5 well-known mirrors).
// Adding more publishers is a few lines per `MirrorSet` — see
// "Adding a new mirror set" at the bottom of this file.
//
// What this file doesn't do: connect to the engine.  The integration
// (failure-detection in `LaneConnection` + `runWorkers` falling
// through to alternatives + UI surface "switched to mirror X") is a
// separate scoped follow-up so the manifest's behaviour can be
// reviewed in isolation.  Companion to `PathMonitorObserver` (S2
// component 2) — both are dormant primitives waiting on engine wire-up.
// =====================================================================

/// One publisher's curated mirror list.  `matches` claims a URL;
/// `alternatives` produces ranked fallback URLs to try in order if
/// the primary fails.  Returned URLs are content-equivalent to the
/// primary (same bytes by construction — Splynek's per-chunk SHA-256
/// + final-file digest verification still gates acceptance).
public struct MirrorSet: Sendable {

    /// Short label for diagnostics + UI ("Ubuntu", "Debian").
    public let publisher: String

    /// Does this set claim the given URL?  Fast host-based check —
    /// no string parsing of the path beyond what's needed to
    /// disambiguate.  First match wins in `MirrorManifest.alternatives`.
    public let matches: @Sendable (URL) -> Bool

    /// Given a primary URL this set claims, return ranked fallback
    /// URLs (most-reliable first).  Empty array means "matched but
    /// no alternatives available" — the caller should keep retrying
    /// the primary or surface a "no fallback" error to the UI.
    public let alternatives: @Sendable (URL) -> [URL]

    public init(
        publisher: String,
        matches: @escaping @Sendable (URL) -> Bool,
        alternatives: @escaping @Sendable (URL) -> [URL]
    ) {
        self.publisher = publisher
        self.matches = matches
        self.alternatives = alternatives
    }
}

/// Curated list of fallback mirrors for OSS publishers Splynek users
/// regularly download from.  Walked in order; first matching set
/// wins.  Compile-time list — the architectural invariant from
/// `MAS-2.5.2-COMPLIANCE.md` is that the mirror surface is fixed at
/// build time so a network-supplied URL can never become a fallback
/// destination.
public enum MirrorManifest {

    public static let allSets: [MirrorSet] = [
        ubuntu,
        debian,
    ]

    /// Public entry point.  Returns ranked fallback URLs the engine
    /// should try, in order, when the primary fails.  Empty array
    /// means "no curated mirror set claims this URL" — the engine
    /// should surface the failure to the user rather than retry.
    public static func alternatives(for primary: URL) -> [URL] {
        for set in allSets where set.matches(primary) {
            return set.alternatives(primary)
        }
        return []
    }

    /// "Co-equal mirrors only" — `alternatives(for:)` minus the
    /// archive.org Wayback entries that are fine as last-resort
    /// fallbacks but bad as parallel lanes (slow archive, may
    /// 404 on the specific resource even though the API endpoint
    /// is up).  Use this when injecting mirrors as parallel
    /// lanes from the engine creation site (`DownloadJob.start`)
    /// — the engine's own lane round-robin will then load-balance
    /// across primary + Tier-1 mirrors without ever sending bytes
    /// to a cold archive.  Last-resort archives live in
    /// `lastResortAlternatives(for:)` for callers that want them.
    public static func parallelAlternatives(for primary: URL) -> [URL] {
        return alternatives(for: primary).filter { url in
            url.host?.lowercased() != "web.archive.org"
        }
    }

    /// Inverse of `parallelAlternatives` — only the archive entries
    /// (web.archive.org).  Empty for URLs no set claims.  Engine
    /// integration of these is deferred — they're surfaced today
    /// via the `alternatives(for:)` full-list entry point for
    /// callers that want to render a "view archived copy" link.
    public static func lastResortAlternatives(for primary: URL) -> [URL] {
        return alternatives(for: primary).filter { url in
            url.host?.lowercased() == "web.archive.org"
        }
    }

    /// Look up the publisher name for a primary URL — used by the UI
    /// to render "switched to <publisher> mirror X" without leaking
    /// the URL transformation details.  Nil for URLs no set claims.
    public static func publisher(for primary: URL) -> String? {
        for set in allSets where set.matches(primary) {
            return set.publisher
        }
        return nil
    }

    // MARK: - Ubuntu (releases.ubuntu.com → curated worldwide mirrors)
    //
    // Ubuntu publishes the canonical ISO at `releases.ubuntu.com/<ver>/
    // <filename>`.  When that host is degraded, well-known Tier-1
    // mirrors carry the same files at predictable paths.  Splynek's
    // per-chunk SHA-256 + final-file digest verification means a
    // mirror serving stale or tampered bytes fails verification — the
    // mirror list is curated for liveness, not trust.
    //
    // Mirrors picked from launchpad.net's Tier-1 list, sorted by
    // historical 2024–2026 uptime + geographic spread:
    //   1. mirror.kernel.org    — kernel.org-operated, very high uptime
    //   2. fr.releases.ubuntu.com — France/Europe Tier-1
    //   3. mirror.us.leaseweb.net — US Tier-1
    //   4. mirrors.cat.net       — Asia Tier-1 (Korea)
    //   5. archive.org/Wayback   — universal fallback for cold-archive
    //                              releases that have rolled off mirrors
    //
    // Note: archive.org Wayback Machine intermittently has Ubuntu ISO
    // captures; it's the long-shot last resort, not a primary fallback.
    public static let ubuntu = MirrorSet(
        publisher: "Ubuntu",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host == "releases.ubuntu.com"
        },
        alternatives: { primary in
            // Path is `/<version>/<filename>` — preserved verbatim
            // across mirrors; only the host changes.  Drop the leading
            // slash because URLComponents.path always carries one.
            let path = primary.path
            guard !path.isEmpty, path.first == "/" else { return [] }
            let trimmed = String(path.dropFirst())  // "24.04/ubuntu-...iso"
            let mirrorBases = [
                "https://mirror.kernel.org/ubuntu-releases/",
                "https://fr.releases.ubuntu.com/",
                "https://mirror.us.leaseweb.net/ubuntu-releases/",
                "https://mirrors.cat.net/ubuntu-releases/",
            ]
            var alts: [URL] = mirrorBases.compactMap { base in
                URL(string: base + trimmed)
            }
            // Wayback long-shot — last resort, always pushed to the end.
            if let wayback = URL(
                string: "https://web.archive.org/web/2024/" + primary.absoluteString
            ) {
                alts.append(wayback)
            }
            return alts
        }
    )

    // MARK: - Debian (cdimage.debian.org → curated worldwide mirrors)
    //
    // Debian publishes the canonical ISO at `cdimage.debian.org/
    // debian-cd/<ver>/<arch>/iso-cd/<filename>`.  When that host is
    // degraded, Tier-1 mirrors at the same `debian-cd/` path serve
    // identical bytes.  Mirror list curated from Debian's official
    // CD-mirror page (https://www.debian.org/CD/http-ftp/) restricted
    // to HTTPS hosts (URLSession's ATS rejects HTTP), sorted by
    // 2024-2026 uptime + geographic spread:
    //   1. mirror.kernel.org/debian-cd/    — kernel.org-operated, very high uptime
    //   2. gemmei.acc.umu.se/debian-cd/    — Umeå University Sweden, EU Tier-1
    //   3. ftp.heanet.ie/debian-cd/        — HEAnet Ireland, EU Tier-1
    //   4. mirror.us.leaseweb.net/debian-cd/ — US Tier-1
    //   5. archive.org/Wayback              — universal long-shot fallback
    //
    // Same trust posture as Ubuntu: the engine's per-chunk SHA-256
    // (when supplied) gates correctness across every source — the
    // mirror list is curated for liveness, not trust.
    public static let debian = MirrorSet(
        publisher: "Debian",
        matches: { url in
            guard let host = url.host?.lowercased() else { return false }
            return host == "cdimage.debian.org"
        },
        alternatives: { primary in
            // Path is `/debian-cd/<ver>/<arch>/iso-cd/<filename>` —
            // preserved verbatim across mirrors but the leading
            // `/debian-cd/` is the "directory base" the mirror serves
            // under.  Different mirrors may NOT carry `/debian-cd/`
            // in their published URL prefix, so we substitute the
            // directory tail.
            let path = primary.path
            // Drop leading `/debian-cd/` if present so we can
            // re-prefix with each mirror's preferred path base.
            let dropPrefix = "/debian-cd/"
            guard path.hasPrefix(dropPrefix), path.count > dropPrefix.count
            else { return [] }
            let tail = String(path.dropFirst(dropPrefix.count))
            // Tail looks like `12.5.0/amd64/iso-cd/debian-12.5.0-amd64-netinst.iso`.
            let mirrorBases = [
                "https://mirror.kernel.org/debian-cd/",
                "https://gemmei.acc.umu.se/debian-cd/",
                "https://ftp.heanet.ie/debian-cd/",
                "https://mirror.us.leaseweb.net/debian-cd/",
            ]
            var alts: [URL] = mirrorBases.compactMap { base in
                URL(string: base + tail)
            }
            // Wayback long-shot — always pushed to the end, like Ubuntu.
            if let wayback = URL(
                string: "https://web.archive.org/web/2024/" + primary.absoluteString
            ) {
                alts.append(wayback)
            }
            return alts
        }
    )
}

// =====================================================================
// Adding a new mirror set
// =====================================================================
//
// 1. Define a static `MirrorSet` with:
//      - `publisher`: short string for UI ("Debian", "Fedora", "kernel.org")
//      - `matches`: closure returning true for primary URLs you handle
//      - `alternatives`: closure transforming the primary URL into
//        ranked fallback URLs
//
// 2. Append the new set to `MirrorManifest.allSets`.
//
// 3. Add tests to `MirrorManifestTests` covering:
//      - host matching (yes URLs + no URLs from sibling publishers)
//      - URL-transform shape (path preserved, host swapped, query
//        string carried through)
//      - empty-result edge cases (URL claims set but path is empty)
//
// Common publishers worth curating:
//   - Debian: cdimage.debian.org → debian.org / kernel.org Tier-1 mirrors
//   - Fedora: download.fedoraproject.org → mirrormanager.fedoraproject.org list
//   - kernel.org: kernel.org direct → kernel.org mirror list
//   - GitHub release assets: github.com/.../releases/download/
//     → archive.org Wayback only (no GH-aware mirror network)
