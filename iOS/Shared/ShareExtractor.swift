// Copyright © 2026 Splynek. MIT.
//
// ShareExtractor — pure URL-extraction logic for the iOS Share
// Extension.  Kept pure (no UIKit / no UniformTypeIdentifiers
// dependencies in the public surface) so unit tests can hit it
// without spinning up an extension host.
//
// The extension's `ShareViewController` does the iOS-glue work
// (NSExtensionItem → NSItemProvider → loadItem(forTypeIdentifier:))
// and then hands the resulting Any payloads to the static API
// here, which normalises them into a single canonical URL.

import Foundation

public enum ShareExtractor {
    /// Inspect a single payload (typically returned by
    /// `NSItemProvider.loadItem(forTypeIdentifier:)`) and try to
    /// extract a `URL`.  Handles `URL`, `String`, and `NSURL`.
    public static func url(from payload: Any?) -> URL? {
        switch payload {
        case let u as URL:
            return canonicalize(u)
        case let s as String:
            return urlFromString(s)
        case let nsurl as NSURL:
            return canonicalize(nsurl as URL)
        default:
            return nil
        }
    }

    /// Pick the best URL from an unordered collection of payloads.
    /// Prefers https → http → file; ignores in-app schemes
    /// (`x-callback-url://`, `instagram://`) which are useless for
    /// downloading.
    public static func bestURL(from payloads: [Any?]) -> URL? {
        let extracted = payloads.compactMap { url(from: $0) }
        if let https = extracted.first(where: { $0.scheme?.lowercased() == "https" }) {
            return https
        }
        if let http = extracted.first(where: { $0.scheme?.lowercased() == "http" }) {
            return http
        }
        return extracted.first
    }

    /// Try to parse a URL out of a free-text string.  Many share
    /// sources hand us raw text containing a URL embedded in a longer
    /// message ("check this out: https://example.com/foo bar").
    public static func urlFromString(_ raw: String) -> URL? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let direct = URL(string: trimmed),
           let scheme = direct.scheme, !scheme.isEmpty {
            return canonicalize(direct)
        }
        // Fall back to NSDataDetector for embedded URLs.  iOS ships
        // the regex globally; deployment-target gate is iOS 4.
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        guard let detector,
              let match = detector.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
              let url = match.url
        else { return nil }
        return canonicalize(url)
    }

    /// Light normalization: drop tracking params + fragment, leave
    /// everything else untouched.  This is *not* an aggressive
    /// privacy filter — Splynek's Trust scan handles that on the Mac
    /// side.  The goal here is just "if two share-sheet captures of
    /// the same article URL come in, deduplicate them visually."
    public static func canonicalize(_ url: URL) -> URL {
        guard var comps = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return url
        }
        // Strip common tracking params.
        if let items = comps.queryItems {
            let trackingKeys: Set<String> = [
                "utm_source", "utm_medium", "utm_campaign", "utm_term",
                "utm_content", "utm_id", "fbclid", "gclid", "mc_cid",
                "mc_eid", "_hsenc", "_hsmi", "ref_src", "ref_url"
            ]
            let cleaned = items.filter { !trackingKeys.contains($0.name.lowercased()) }
            comps.queryItems = cleaned.isEmpty ? nil : cleaned
        }
        return comps.url ?? url
    }
}
