#!/usr/bin/env swift

// v1.4 discovery engine: finds apps NOT yet in the Sovereignty catalog.
//
// Reads from any combination of:
//   • Scripts/sources/*.json       — external-source files (community
//                                     contributions, ingester output)
//   • /Applications/ (and nested)  — the scan-the-local-Mac mode, via
//                                     --from-apps (optional)
//   • A `--from-file foo.txt`      — one display-name per line, for
//                                     ad-hoc seeding from curated lists
//
// Emits `Scripts/candidates.json`: apps NOT already in the catalog,
// deduplicated, with suggested category if the source provided one.
// This is the feedstock for `ai-propose.swift`, which drafts
// alternative-sets using a local LLM.
//
// Source-file schema (Scripts/sources/*.json):
//
//     {
//       "source": "switching.software",
//       "license": "CC-BY-4.0",
//       "url": "https://switching.software",
//       "entries": [
//         { "bundleID": "com.example.app",
//           "displayName": "Example App",
//           "origin": "unitedStates",
//           "category": "chat-personal" }
//       ]
//     }
//
// Everything else is optional; displayName is the only required field.
// If `bundleID` is missing, we synthesise a best-guess reverse-DNS from
// the displayName — the AI/human review step can correct later.
//
// Zero third-party deps.  Run from the repo root:
//
//   swift Scripts/discover.swift
//   swift Scripts/discover.swift --from-apps
//   swift Scripts/discover.swift --from-file apps.txt

import Foundation

// MARK: - Shapes

struct SourceEntry: Decodable {
    let bundleID: String?
    let displayName: String
    let origin: String?
    let category: String?
    let note: String?
}
struct SourceFile: Decodable {
    let source: String?
    let license: String?
    let url: String?
    let entries: [SourceEntry]
}

struct Candidate: Encodable {
    let bundleID: String
    let displayName: String
    let origin: String?       // if known
    let category: String?     // if known
    let source: String        // where we found it
    let note: String?
}

struct CatalogRawAlt: Decodable {}  // we don't care about alt fields
struct CatalogRawEntry: Decodable {
    let targetBundleID: String
    let targetDisplayName: String
}
struct CatalogShape: Decodable {
    let entries: [CatalogRawEntry]
}

// MARK: - Helpers

/// Synthesise a plausible reverse-DNS bundle ID from a display name.
/// Result is deterministic and ASCII-only: "Signal Desktop" → "app.unknown.signaldesktop".
/// The `app.unknown.*` prefix is a clear flag that review is needed.
func synthesiseBundleID(_ displayName: String) -> String {
    let cleaned = displayName
        .lowercased()
        .unicodeScalars
        .filter { CharacterSet.alphanumerics.contains($0) }
        .map { String($0) }
        .joined()
    if cleaned.isEmpty { return "app.unknown.unnamed" }
    return "app.unknown.\(cleaned)"
}

/// Normalise a display name for matching-by-name (lowercase, strip spaces).
func nameKey(_ s: String) -> String {
    s.lowercased().unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }
        .map { String($0) }.joined()
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())
var fromApps = false
var fromFile: String?
var sourcesDir = "Scripts/sources"
var outputPath = "Scripts/candidates.json"

var i = 0
while i < args.count {
    let a = args[i]
    switch a {
    case "--from-apps": fromApps = true
    case "--from-file":
        if i + 1 < args.count { fromFile = args[i+1]; i += 1 }
    case "--sources-dir":
        if i + 1 < args.count { sourcesDir = args[i+1]; i += 1 }
    case "--output":
        if i + 1 < args.count { outputPath = args[i+1]; i += 1 }
    case "--help", "-h":
        print("""
        discover.swift — find apps not yet in sovereignty-catalog.json

        Usage:
          swift Scripts/discover.swift [flags]

        --from-apps          Enumerate /Applications/ + ~/Applications/.
        --from-file PATH     Read display-names (one per line) from PATH.
        --sources-dir DIR    Directory of source JSON files (default Scripts/sources).
        --output PATH        Output file (default Scripts/candidates.json).
        """)
        exit(0)
    default:
        fputs("warn: unknown flag '\(a)'\n", stderr)
    }
    i += 1
}

// 1. Load the current catalog — we only emit candidates that DON'T
//    appear here (by bundle ID or display name).
let catalogURL = URL(fileURLWithPath: "Scripts/sovereignty-catalog.json")
guard let catalogData = try? Data(contentsOf: catalogURL),
      let catalog = try? JSONDecoder().decode(CatalogShape.self, from: catalogData) else {
    fputs("error: could not read Scripts/sovereignty-catalog.json\n", stderr)
    exit(1)
}
let knownBundleIDs = Set(catalog.entries.map { $0.targetBundleID })
let knownNames = Set(catalog.entries.map { nameKey($0.targetDisplayName) })

// 2. Gather input: source-dir + optional --from-apps + optional --from-file
var inputs: [(bundleID: String?, displayName: String, origin: String?, category: String?, note: String?, source: String)] = []

let fm = FileManager.default
let sourcesURL = URL(fileURLWithPath: sourcesDir)
if fm.fileExists(atPath: sourcesURL.path) {
    if let files = try? fm.contentsOfDirectory(at: sourcesURL, includingPropertiesForKeys: nil) {
        for file in files where file.pathExtension == "json" {
            guard let data = try? Data(contentsOf: file),
                  let src = try? JSONDecoder().decode(SourceFile.self, from: data) else {
                fputs("warn: skipping unparseable source \(file.lastPathComponent)\n", stderr)
                continue
            }
            let label = src.source ?? file.lastPathComponent
            for e in src.entries {
                inputs.append((e.bundleID, e.displayName, e.origin, e.category, e.note, label))
            }
        }
    }
}

if fromApps {
    let appDirs = ["/Applications", "/Applications/Utilities",
                   (NSHomeDirectory() as NSString).appendingPathComponent("Applications")]
    for dir in appDirs {
        guard let files = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for f in files where f.hasSuffix(".app") {
            let appURL = URL(fileURLWithPath: "\(dir)/\(f)")
            var displayName = (f as NSString).deletingPathExtension
            var bundleID: String?
            if let bundle = Bundle(url: appURL) {
                bundleID = bundle.bundleIdentifier
                if let n = bundle.infoDictionary?["CFBundleDisplayName"] as? String { displayName = n }
                else if let n = bundle.infoDictionary?["CFBundleName"] as? String { displayName = n }
            }
            inputs.append((bundleID, displayName, nil, nil, nil, "local:\(dir)"))
        }
    }
}

if let path = fromFile {
    if let content = try? String(contentsOfFile: path, encoding: .utf8) {
        for line in content.split(separator: "\n") {
            let name = line.trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                inputs.append((nil, name, nil, nil, nil, "file:\(path)"))
            }
        }
    }
}

if inputs.isEmpty {
    fputs("warn: no inputs found. Populate Scripts/sources/*.json, use --from-apps, or --from-file.\n", stderr)
}

// 3. Filter out already-catalogued apps.
var candidates: [Candidate] = []
var seenKeys: Set<String> = []

for inp in inputs {
    let bid = inp.bundleID ?? synthesiseBundleID(inp.displayName)
    let nk = nameKey(inp.displayName)
    if knownBundleIDs.contains(bid) { continue }
    if knownNames.contains(nk) { continue }
    // Dedupe within this discovery run — same app may appear in
    // multiple sources.  Prefer the first (which may have richer fields).
    let key = bid + "|" + nk
    if seenKeys.contains(key) { continue }
    seenKeys.insert(key)
    candidates.append(Candidate(
        bundleID: bid,
        displayName: inp.displayName,
        origin: inp.origin,
        category: inp.category,
        source: inp.source,
        note: inp.note
    ))
}

// 4. Emit candidates.json.
struct Out: Encodable {
    let version: Int
    let generatedAt: String
    let totalKnown: Int
    let totalInputs: Int
    let candidates: [Candidate]
}
let iso = ISO8601DateFormatter()
let out = Out(version: 1,
              generatedAt: iso.string(from: Date()),
              totalKnown: knownBundleIDs.count,
              totalInputs: inputs.count,
              candidates: candidates)

let encoder = JSONEncoder()
encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
do {
    let data = try encoder.encode(out)
    try data.write(to: URL(fileURLWithPath: outputPath))
    print("✓ discovered \(candidates.count) new candidates from \(inputs.count) inputs")
    print("   wrote \(outputPath)")
    if candidates.isEmpty {
        print("   (nothing new — catalog is already a superset of these sources)")
    } else {
        let withOrigin = candidates.filter { $0.origin != nil }.count
        print("   \(withOrigin) have known origin · \(candidates.count - withOrigin) need AI/human classification")
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(2)
}
