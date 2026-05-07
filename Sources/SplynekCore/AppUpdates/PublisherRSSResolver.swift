// Copyright © 2026 Splynek. MIT.
//
// PublisherRSSResolver — generic RSS / Atom parser for publishers
// that expose release notes via a non-Sparkle feed.  Phase 3
// follow-up (2026-05-07).
//
// Use cases that DON'T fit Sparkle or GitHub Releases:
//
//   - KDE projects (Kdenlive, Krita, etc.) publish on
//     download.kde.org with an RSS feed at /release-announcements/
//   - Blender's release feed at blender.org/atom.xml
//   - Mozilla's product RSS at mozilla.org/firefox/releases/
//   - Some indie devs ship a Wordpress feed instead of an appcast
//
// Strategy: parse `<title>` + `<link>` + `<pubDate>` of the most
// recent `<item>` (RSS) or `<entry>` (Atom).  Try to extract a
// version number from the title via regex.  If we can't parse
// the version, the caller falls back to .unknown — the feed is
// for diagnostics only at that point.
//
// Pure XML parsing via XMLParser; no network in this module.
// Tests inject synthetic feeds for both RSS 2.0 and Atom 1.0.

import Foundation

public enum PublisherRSSResolver {

    public struct Item: Equatable, Sendable {
        public var title: String
        public var link: URL?
        public var pubDate: Date?
        /// Extracted from `title` via the version regex below.
        /// nil when the title doesn't match (caller treats as
        /// "couldn't determine version").
        public var version: String?
    }

    /// Parse the bytes of an RSS/Atom feed and return the latest
    /// item.  Returns nil when the feed is malformed.
    public static func parseLatest(_ data: Data) -> Item? {
        let parser = XMLParser(data: data)
        let delegate = FeedDelegate()
        parser.delegate = delegate
        guard parser.parse() else { return nil }
        return delegate.firstItem
    }

    /// Try to extract a version from a title like:
    ///   "Kdenlive 24.05.0 released"  → "24.05.0"
    ///   "v1.2.3 - Release Notes"     → "1.2.3"
    ///   "Blender 4.2.1 LTS"          → "4.2.1"
    ///
    /// Returns nil when no semver-shaped substring is found.
    /// Public so tests can exercise the regex directly.
    public static func extractVersion(from title: String) -> String? {
        // Match digits + (.digits)+ optionally followed by extras.
        // We deliberately don't accept date-shaped versions like
        // "2024-05-07" here — those rarely appear in release titles
        // and we'd risk false matches in dates inside titles.
        let pattern = #"(?:^|\s|v)(\d+\.\d+(?:\.\d+)?(?:\.\d+)?)"#
        guard let re = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(title.startIndex..., in: title)
        guard let match = re.firstMatch(in: title, range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: title)
        else { return nil }
        return String(title[r])
    }

    private final class FeedDelegate: NSObject, XMLParserDelegate {
        var firstItem: Item?
        private var current: Item?
        private var charBuffer: String = ""
        private var inItem = false
        private var inLink = false
        private var atomLinkHref: String?

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes attributeDict: [String: String] = [:])
        {
            charBuffer = ""
            switch elementName.lowercased() {
            case "item", "entry":
                if firstItem == nil {
                    inItem = true
                    current = Item(title: "", link: nil, pubDate: nil, version: nil)
                }
            case "link":
                guard inItem else { return }
                // Atom's <link> has the URL in the `href` attribute.
                // RSS's <link> has the URL in element text.  We
                // remember both — text wins if present (most RSS),
                // attribute is the Atom fallback.
                if let href = attributeDict["href"], !href.isEmpty {
                    atomLinkHref = href
                }
                inLink = true
            default:
                break
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            charBuffer.append(string)
        }

        func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
            if let s = String(data: CDATABlock, encoding: .utf8) {
                charBuffer.append(s)
            }
        }

        func parser(_ parser: XMLParser,
                    didEndElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?)
        {
            guard inItem, var item = current else { return }
            let trimmed = charBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            switch elementName.lowercased() {
            case "title":
                item.title = trimmed
                item.version = PublisherRSSResolver.extractVersion(from: trimmed)
            case "link":
                let urlString = trimmed.isEmpty ? (atomLinkHref ?? "") : trimmed
                if !urlString.isEmpty, let u = URL(string: urlString) {
                    item.link = u
                }
                inLink = false
            case "pubdate", "published", "updated":
                item.pubDate = Self.parseDate(trimmed)
            case "item", "entry":
                if firstItem == nil { firstItem = item }
                inItem = false
                current = nil
                charBuffer = ""
                return
            default:
                break
            }
            current = item
            charBuffer = ""
        }

        /// Try a few common date formats: RFC 822 (RSS), ISO 8601
        /// (Atom), and a couple of permissive variants.
        private static func parseDate(_ s: String) -> Date? {
            let isoMs = ISO8601DateFormatter()
            isoMs.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = isoMs.date(from: s) { return d }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: s) { return d }
            // RFC 822 — RSS pubDate.  Locale-pinned so non-English
            // system locales don't break matching.
            let rfc822 = DateFormatter()
            rfc822.locale = Locale(identifier: "en_US_POSIX")
            rfc822.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            return rfc822.date(from: s)
        }
    }
}
