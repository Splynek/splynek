import Foundation

/// Self-served update feed. Splynek fetches a small JSON document at a
/// known URL, parses it, and compares the advertised `version` against the
/// built-in `CFBundleShortVersionString`. If the feed version is higher,
/// the About view surfaces a banner with the release notes and a download
/// link.
///
/// Feed schema (all required):
///
///     {
///       "version": "0.15.0",
///       "notes": "Short changelog or release tagline.",
///       "url":   "https://example.com/Splynek-0.15.0.dmg"
///     }
///
/// The feed URL is configurable via UserDefaults key `updateFeedURL`; if
/// unset, the check is skipped silently (no spammy errors in the UI).
struct UpdateInfo: Codable, Equatable, Hashable {
    var version: String
    var notes: String
    var url: String
    /// Optional SHA-256 of the payload at `url`, hex-encoded. If supplied,
    /// Splynek's self-download flow prefills the integrity field so the
    /// download verifies end-to-end.
    var sha256: String?
}

enum UpdateChecker {

    static var feedURL: URL? {
        if let s = UserDefaults.standard.string(forKey: "updateFeedURL"),
           !s.isEmpty, let u = URL(string: s) {
            return u
        }
        return nil
    }

    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
    }

    /// Fire-and-forget check. Returns an `UpdateInfo` only if the feed
    /// advertises a strictly-higher semver than the running build; nil
    /// otherwise (up-to-date, feed absent, or any error).
    static func check() async -> UpdateInfo? {
        guard let url = feedURL else { return nil }
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        req.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            return nil
        }
        guard let info = try? JSONDecoder().decode(UpdateInfo.self, from: data) else {
            return nil
        }
        return isNewer(info.version, than: currentVersion) ? info : nil
    }

    /// Compare two dotted-numeric versions. Non-numeric suffixes
    /// (`1.2.3-rc1`) are ignored after the first non-numeric character.
    static func isNewer(_ a: String, than b: String) -> Bool {
        let lhs = semverTuple(a)
        let rhs = semverTuple(b)
        let len = max(lhs.count, rhs.count)
        for i in 0..<len {
            let l = i < lhs.count ? lhs[i] : 0
            let r = i < rhs.count ? rhs[i] : 0
            if l != r { return l > r }
        }
        return false
    }

    private static func semverTuple(_ s: String) -> [Int] {
        var out: [Int] = []
        for segment in s.split(separator: ".") {
            var digits = ""
            for ch in segment {
                if ch.isNumber { digits.append(ch) } else { break }
            }
            out.append(Int(digits) ?? 0)
        }
        return out
    }
}
