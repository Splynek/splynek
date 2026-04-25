#!/usr/bin/env swift

// v1.4 catalog pipeline: JSON → Swift codegen.
//
// Reads `Scripts/sovereignty-catalog.json` (the authoring source)
// and rewrites `Sources/SplynekCore/SovereigntyCatalog+Entries.swift`
// with a freshly generated `static let entries: [Entry] = [ … ]`.
//
// Run from the repo root:
//
//   swift Scripts/regenerate-sovereignty-catalog.swift
//
// This gives us "best of both worlds": JSON is the source of truth
// for catalog data (diffable, bulk-importable, community-friendly),
// and the Swift output keeps compile-time type safety + runtime speed.
//
// Zero third-party deps (matches Splynek's CLT-only build invariant).

import Foundation

// MARK: - JSON shape

struct RawAlt: Decodable {
    let id: String
    let origin: String
    let name: String
    let homepage: String
    let note: String
    let downloadURL: String?
}

struct RawEntry: Decodable {
    let targetBundleID: String
    let targetDisplayName: String
    let targetOrigin: String
    let alternatives: [RawAlt]
}

struct RawCatalog: Decodable {
    let version: Int
    let comment: String?
    let entries: [RawEntry]
}

// MARK: - Helpers

/// Emit a Swift string literal escaping every character that would
/// otherwise produce invalid Swift or silently corrupt round-trip:
/// quotes, backslashes, all C0 control characters (\n \r \t plus the
/// rest of the 0x00–0x1F range as `\u{HH}`).  v1.4 audit hardened
/// against tabs / smart-quote-NBSP / null in catalog notes that were
/// emitted as raw bytes and broke compile.
func swiftStringLit(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\\":  out += "\\\\"
        case "\"":  out += "\\\""
        case "\n":  out += "\\n"
        case "\r":  out += "\\r"
        case "\t":  out += "\\t"
        case "\0":  out += "\\0"
        default:
            if scalar.value < 0x20 || scalar.value == 0x7F {
                // C0 / DEL — emit Unicode escape so the literal is
                // valid + visually obvious in diffs.
                out += String(format: "\\u{%X}", scalar.value)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
    }
    out += "\""
    return out
}

let validOrigins: Set<String> = [
    "europe", "oss", "europeAndOSS",
    "unitedStates", "china", "russia", "other",
]

// MARK: - Main

let jsonURL = URL(fileURLWithPath: "Scripts/sovereignty-catalog.json")
let outputURL = URL(fileURLWithPath: "Sources/SplynekCore/SovereigntyCatalog+Entries.swift")

do {
    let data = try Data(contentsOf: jsonURL)
    let cat = try JSONDecoder().decode(RawCatalog.self, from: data)

    guard cat.version == 1 else {
        fputs("error: unsupported catalog version \(cat.version)\n", stderr)
        exit(2)
    }

    // Lint: origins, URL parseability + scheme safety, duplicate IDs.
    //
    // Scheme safety (v1.4 audit hardening): we reject any `file://`,
    // `data:`, `javascript:`, custom-scheme URLs at regeneration time.
    // The downstream consumer (`SovereigntyView.actionButton`) defends
    // again at click-time, but rejecting bad schemes here means a
    // poisoned upstream JSON source can't get a `file:///etc/passwd`
    // entry into the compiled catalog at all.
    func isSafeURLScheme(_ s: String, allowHTTP: Bool) -> Bool {
        guard let url = URL(string: s), let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "https" || (allowHTTP && scheme == "http")
    }

    var seenIDs: Set<String> = []
    for entry in cat.entries {
        guard validOrigins.contains(entry.targetOrigin) else {
            fputs("error: entry \(entry.targetBundleID) has invalid targetOrigin '\(entry.targetOrigin)'\n", stderr)
            exit(3)
        }
        for alt in entry.alternatives {
            guard validOrigins.contains(alt.origin) else {
                fputs("error: alt \(alt.id) has invalid origin '\(alt.origin)'\n", stderr)
                exit(3)
            }
            // Homepages opened in user's browser — http or https OK.
            guard isSafeURLScheme(alt.homepage, allowHTTP: true) else {
                fputs("error: alt \(alt.id) has unsafe/unparseable homepage '\(alt.homepage)' (only http/https allowed)\n", stderr)
                exit(3)
            }
            // Download URLs go through the engine — https-only.
            if let dl = alt.downloadURL {
                guard isSafeURLScheme(dl, allowHTTP: false) else {
                    fputs("error: alt \(alt.id) has unsafe/unparseable downloadURL '\(dl)' (only https allowed)\n", stderr)
                    exit(3)
                }
            }
            guard seenIDs.insert(alt.id).inserted else {
                fputs("error: duplicate alternative id '\(alt.id)'\n", stderr)
                exit(3)
            }
        }
    }

    // Emit Swift.
    var out = """
    // GENERATED FILE — DO NOT EDIT BY HAND.
    //
    // Source:     Scripts/sovereignty-catalog.json
    // Generator:  swift Scripts/regenerate-sovereignty-catalog.swift
    // Count:      \(cat.entries.count) entries
    //
    // To add, correct, or remove entries, edit the JSON source and
    // regenerate.  See SOVEREIGNTY-CONTRIBUTING.md for the pipeline.

    import Foundation

    extension SovereigntyCatalog {

        /// The full catalog — generated from Scripts/sovereignty-catalog.json.
        static let entries: [Entry] = [

    """

    for entry in cat.entries {
        out += "        Entry(\n"
        out += "            targetBundleID: \(swiftStringLit(entry.targetBundleID)),\n"
        out += "            targetDisplayName: \(swiftStringLit(entry.targetDisplayName)),\n"
        out += "            targetOrigin: .\(entry.targetOrigin),\n"
        out += "            alternatives: [\n"
        for alt in entry.alternatives {
            // The homepage `URL(string:)!` is safe because we validated
            // every URL parses cleanly above (lines under "Lint:" — exit
            // 3 if any alt's homepage fails to parse).  The downloadURL
            // is intentionally not force-unwrapped: if it fails to
            // parse later, the field becomes nil and the UI falls back
            // to the homepage "Visit" button instead of crashing.
            out += "                .init(id: \(swiftStringLit(alt.id)),\n"
            out += "                      origin: .\(alt.origin),\n"
            out += "                      name: \(swiftStringLit(alt.name)),\n"
            out += "                      homepage: URL(string: \(swiftStringLit(alt.homepage)))!,\n"
            out += "                      note: \(swiftStringLit(alt.note))"
            if let dl = alt.downloadURL {
                out += ",\n                      downloadURL: URL(string: \(swiftStringLit(dl)))"
            }
            out += "),\n"
        }
        out += "            ]),\n"
    }

    out += """
        ]
    }

    """

    try out.write(to: outputURL, atomically: true, encoding: .utf8)
    print("✓ wrote \(cat.entries.count) entries → \(outputURL.path)")
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
