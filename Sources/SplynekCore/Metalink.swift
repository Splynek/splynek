import Foundation

/// Minimal parser for IETF Metalink 4 (`application/metalink4+xml`, RFC 5854)
/// and the older Metalink 3 namespace. We only care about the first `<file>`
/// element because Splynek still handles one file at a time.
struct MetalinkFile {
    var name: String
    var size: Int64?
    var sha256: String?
    var urls: [URL]  // preserved in priority order (lower = preferred)
}

enum MetalinkError: Error, LocalizedError {
    case noFile
    case noURLs
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .noFile:               return "Metalink: no <file> element."
        case .noURLs:               return "Metalink: file has no <url> entries."
        case .parseFailed(let s):   return "Metalink parse failed: \(s)"
        }
    }
}

enum Metalink {
    static func parse(_ data: Data) throws -> MetalinkFile {
        let handler = Handler()
        let parser = XMLParser(data: data)
        parser.delegate = handler
        if !parser.parse() {
            let err = parser.parserError?.localizedDescription ?? "malformed XML"
            throw MetalinkError.parseFailed(err)
        }
        guard let file = handler.file else { throw MetalinkError.noFile }
        guard !file.urls.isEmpty else { throw MetalinkError.noURLs }
        return file
    }

    static func parse(contentsOf url: URL) throws -> MetalinkFile {
        let data = try Data(contentsOf: url)
        return try parse(data)
    }

    // MARK: XML parser delegate

    private final class Handler: NSObject, XMLParserDelegate {
        var file: MetalinkFile?
        private var current: PendingURL?
        private var text: String = ""
        private var currentHashType: String = ""
        private var inFile = false

        struct PendingURL { var priority: Int; var value: String }

        func parser(
            _ parser: XMLParser,
            didStartElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?,
            attributes attributeDict: [String: String] = [:]
        ) {
            let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
            switch local.lowercased() {
            case "file":
                inFile = true
                file = MetalinkFile(
                    name: attributeDict["name"] ?? attributeDict["Name"] ?? "download.bin",
                    size: nil, sha256: nil, urls: []
                )
            case "url":
                let pr = Int(attributeDict["priority"] ?? "100") ?? 100
                current = PendingURL(priority: pr, value: "")
            case "hash":
                currentHashType = (attributeDict["type"] ?? "").lowercased()
            default:
                break
            }
            text = ""
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            text += string
        }

        func parser(
            _ parser: XMLParser,
            didEndElement elementName: String,
            namespaceURI: String?,
            qualifiedName qName: String?
        ) {
            let local = elementName.split(separator: ":").last.map(String.init) ?? elementName
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch local.lowercased() {
            case "file":
                inFile = false
            case "size", "length":
                if inFile { file?.size = Int64(trimmed) }
            case "hash":
                if inFile, currentHashType == "sha-256" || currentHashType == "sha256" {
                    file?.sha256 = trimmed.lowercased()
                }
                currentHashType = ""
            case "url":
                if inFile, var entry = current, !trimmed.isEmpty {
                    entry.value = trimmed
                    if var f = file {
                        let candidates = (f.urls + [URL(string: trimmed)].compactMap { $0 })
                        // Maintain priority ordering by sorting ascending.
                        var pairs = zip(candidates, f.urls.map { _ in 100 } + [entry.priority])
                            .map { ($0, $1) }
                        pairs.sort { $0.1 < $1.1 }
                        f.urls = pairs.map(\.0)
                        file = f
                    }
                }
                current = nil
            default:
                break
            }
            text = ""
        }
    }
}
