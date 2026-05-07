// Copyright © 2026 Splynek. MIT.
//
// SparkleAppcast — minimal Sparkle 2.x appcast parser (Phase 3,
// 2026-05-07).
//
// We don't depend on the actual Sparkle framework — it's a heavy
// runtime + binary blob the app would have to link.  Instead, the
// appcast is a simple RSS-shaped XML we parse with XMLParser to
// extract just what the Updates tab needs:
//
//   - sparkle:version            (build / version of the latest item)
//   - sparkle:shortVersionString (display version)
//   - enclosure url              (download URL)
//   - enclosure length           (size in bytes)
//   - enclosure sparkle:edSignature  (Ed25519 signature when present)
//   - sparkle:releaseNotesLink   (HTML URL — fetched lazily)
//   - description                (inline release notes — preferred when present)
//
// Tests inject synthetic XML; production fetches via URLSession.

import Foundation

public enum SparkleAppcast {

    public struct Item: Equatable, Sendable {
        public var version: String?
        public var shortVersion: String?
        public var enclosureURL: URL?
        public var sizeBytes: Int64?
        public var sha256: String?       // when publisher includes it (rare; usually Ed25519 only)
        public var releaseNotesText: String?
    }

    /// Parse the bytes of a Sparkle appcast XML into the latest
    /// item (the first one — Sparkle convention is reverse-chrono).
    /// Returns nil when the XML doesn't contain a usable item.
    public static func parseLatest(_ data: Data) -> Item? {
        let parser = XMLParser(data: data)
        let delegate = AppcastDelegate()
        parser.delegate = delegate
        parser.shouldProcessNamespaces = true
        guard parser.parse() else { return nil }
        return delegate.firstItem
    }

    private final class AppcastDelegate: NSObject, XMLParserDelegate {
        var firstItem: Item?
        private var current: Item?
        private var charBuffer: String = ""
        private var inItem = false

        func parser(_ parser: XMLParser,
                    didStartElement elementName: String,
                    namespaceURI: String?,
                    qualifiedName qName: String?,
                    attributes attributeDict: [String : String] = [:])
        {
            charBuffer = ""
            switch elementName {
            case "item":
                if firstItem == nil {
                    inItem = true
                    current = Item()
                }
            case "enclosure":
                guard inItem else { return }
                if let url = attributeDict["url"], let parsed = URL(string: url) {
                    current?.enclosureURL = parsed
                }
                if let lengthStr = attributeDict["length"], let length = Int64(lengthStr) {
                    current?.sizeBytes = length
                }
                // Sparkle 2.x: Ed25519 sig is the standard; SHA-256
                // appears in older + custom appcasts.
                if let sha = attributeDict["sparkle:sha256"] {
                    current?.sha256 = sha
                }
                // Some publishers put version on the enclosure too.
                if let v = attributeDict["sparkle:version"] {
                    current?.version = v
                }
                if let s = attributeDict["sparkle:shortVersionString"] {
                    current?.shortVersion = s
                }
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
            guard inItem else { return }
            let trimmed = charBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
            // qName carries "sparkle:version" while elementName has been
            // namespace-stripped to just "version".  Match on both shapes.
            switch elementName {
            case "version":
                if current?.version == nil { current?.version = trimmed.isEmpty ? nil : trimmed }
            case "shortVersionString":
                if current?.shortVersion == nil { current?.shortVersion = trimmed.isEmpty ? nil : trimmed }
            case "description":
                if !trimmed.isEmpty { current?.releaseNotesText = trimmed }
            case "item":
                if firstItem == nil, let c = current { firstItem = c }
                inItem = false
                current = nil
            default:
                break
            }
            charBuffer = ""
        }
    }
}
