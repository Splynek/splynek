#!/usr/bin/env swift

// v1.4 discovery engine — merge AI-drafted proposals into the catalog.
//
// Reads Scripts/proposals.json (output of ai-propose.swift), shows each
// proposal in a reviewer-friendly format, and on approval merges it
// into Scripts/sovereignty-catalog.json.  Then:
//
//   swift Scripts/regenerate-sovereignty-catalog.swift
//   swift run splynek-test
//
// to refresh the Swift + verify invariants.
//
// Two modes:
//   1. INTERACTIVE (default).  Walks proposals one-by-one with prompts:
//      'a' accept · 'e' edit (opens $EDITOR on a temp JSON snippet) ·
//      's' skip · 'q' quit.
//   2. BATCH (`--auto-accept high`).  Auto-merge proposals where
//      confidence == high; skip everything else.  For trusted
//      bulk-flow situations (well-known SaaS apps, weekly cron).
//
// Always merges via the same JSON shape `seed-sovereignty-bulk.swift`
// uses, so the existing regenerator round-trips cleanly.
//
// Zero third-party deps.

import Foundation

// MARK: - Shapes

struct ProposedAlt: Codable {
    let name: String
    let origin: String
    let homepage: String
    let note: String
}
struct Proposal: Codable {
    let bundleID: String
    let displayName: String
    let suggestedOrigin: String
    let suggestedCategory: String
    let confidence: String
    let alternatives: [ProposedAlt]
    let source: String
    let modelRationale: String?
}
struct ProposalsFile: Codable {
    let version: Int
    let generatedAt: String?
    let model: String?
    let proposals: [Proposal]
}

struct CatalogAlt: Codable {
    let id: String
    let origin: String
    let name: String
    let homepage: String
    let note: String
    let downloadURL: String?
}
struct CatalogEntry: Codable {
    let targetBundleID: String
    let targetDisplayName: String
    let targetOrigin: String
    let alternatives: [CatalogAlt]
}
struct Catalog: Codable {
    let version: Int
    let comment: String
    var entries: [CatalogEntry]
}

// MARK: - Validation rules (mirror SovereigntyCatalogTests + lint)

let validOrigins: Set<String> = [
    "europe", "oss", "europeAndOSS", "unitedStates", "china", "russia", "other",
]
let recommendableOrigins: Set<String> = ["europe", "oss", "europeAndOSS"]
let forbiddenAltOrigins: Set<String> = ["unitedStates", "china", "russia"]

enum ValidationError: Error, CustomStringConvertible {
    case targetIsRecommendable, badTargetOrigin
    case noAlternatives, noRecommendableAlt
    case badAltOrigin(String), forbiddenAltOrigin(String)
    case unparseableHomepage(String)
    case duplicateBundleID
    var description: String {
        switch self {
        case .targetIsRecommendable: return "target origin is European/OSS — not a sovereignty target"
        case .badTargetOrigin:       return "targetOrigin not a recognised enum case"
        case .noAlternatives:        return "no alternatives"
        case .noRecommendableAlt:    return "no .europe/.oss/.europeAndOSS alternative"
        case .badAltOrigin(let o):   return "alt origin '\(o)' invalid"
        case .forbiddenAltOrigin(let o): return "alt origin '\(o)' is US/CN/RU — forbidden"
        case .unparseableHomepage(let h): return "alt homepage '\(h)' unparseable"
        case .duplicateBundleID:     return "bundleID already in catalog"
        }
    }
}

func validate(_ p: Proposal, knownBundleIDs: Set<String>) throws {
    guard !knownBundleIDs.contains(p.bundleID) else { throw ValidationError.duplicateBundleID }
    guard validOrigins.contains(p.suggestedOrigin) else { throw ValidationError.badTargetOrigin }
    if recommendableOrigins.contains(p.suggestedOrigin) { throw ValidationError.targetIsRecommendable }
    guard !p.alternatives.isEmpty else { throw ValidationError.noAlternatives }
    let recommendable = p.alternatives.filter { recommendableOrigins.contains($0.origin) }
    if recommendable.isEmpty { throw ValidationError.noRecommendableAlt }
    for alt in p.alternatives {
        guard validOrigins.contains(alt.origin) else { throw ValidationError.badAltOrigin(alt.origin) }
        if forbiddenAltOrigins.contains(alt.origin) { throw ValidationError.forbiddenAltOrigin(alt.origin) }
        // v1.4 audit hardening: scheme safety.  AI-drafted proposals
        // are inherently untrusted (the LLM can hallucinate any URL),
        // so we reject anything that isn't http/https before merge.
        // The regenerator enforces the same rule downstream — both
        // layers, neither relies on the other.
        guard let url = URL(string: alt.homepage),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw ValidationError.unparseableHomepage(alt.homepage)
        }
    }
}

// MARK: - Mapping

/// Convert a proposal to a catalog Entry.  Generates alt IDs of the form
/// `<bundleID-slug>:<alt-name-slug>` so they're unique across the catalog
/// and human-readable in PR diffs.
func entry(from p: Proposal) -> CatalogEntry {
    let targetSlug = slug(p.bundleID)
    let alts: [CatalogAlt] = p.alternatives.map { a in
        CatalogAlt(
            id: "\(targetSlug):\(slug(a.name))",
            origin: a.origin,
            name: a.name,
            homepage: a.homepage,
            note: a.note,
            downloadURL: nil
        )
    }
    return CatalogEntry(
        targetBundleID: p.bundleID,
        targetDisplayName: p.displayName,
        targetOrigin: p.suggestedOrigin,
        alternatives: alts
    )
}

func slug(_ s: String) -> String {
    let lower = s.lowercased()
    var out = ""
    for c in lower.unicodeScalars {
        if CharacterSet.alphanumerics.contains(c) {
            out.append(Character(c))
        } else if c == "." || c == " " || c == "-" || c == "_" {
            out.append("-")
        }
    }
    while out.contains("--") { out = out.replacingOccurrences(of: "--", with: "-") }
    out = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    return out.isEmpty ? "unknown" : out
}

// MARK: - Pretty-print proposal

func render(_ p: Proposal, index: Int, total: Int) {
    let line = String(repeating: "─", count: 64)
    print("")
    print(line)
    print("[\(index + 1)/\(total)] \(p.displayName)  (\(p.bundleID))")
    print("    confidence: \(p.confidence)   origin: \(p.suggestedOrigin)   category: \(p.suggestedCategory)")
    if let r = p.modelRationale, !r.isEmpty { print("    rationale:  \(r)") }
    print("    source:     \(p.source)")
    print("")
    print("    Alternatives (\(p.alternatives.count)):")
    for (j, alt) in p.alternatives.enumerated() {
        print("      \(j + 1). \(alt.name)  [\(alt.origin)]")
        print("         \(alt.homepage)")
        print("         \(alt.note)")
    }
    print("")
}

// MARK: - Interactive prompt

func promptDecision() -> String {
    print("    [a]ccept · [s]kip · [q]uit  ", terminator: "")
    if let line = readLine() {
        return line.trimmingCharacters(in: .whitespaces).lowercased()
    }
    return "q"
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())
var autoAccept: String?  // "high" | "medium" | "low"  (lowest level to auto-accept)
var inputPath = "Scripts/proposals.json"
var catalogPath = "Scripts/sovereignty-catalog.json"
var dryRun = false

var i = 0
while i < args.count {
    switch args[i] {
    case "--auto-accept":
        if i + 1 < args.count { autoAccept = args[i+1].lowercased(); i += 1 }
    case "--input":
        if i + 1 < args.count { inputPath = args[i+1]; i += 1 }
    case "--catalog":
        if i + 1 < args.count { catalogPath = args[i+1]; i += 1 }
    case "--dry-run": dryRun = true
    case "--help", "-h":
        print("""
        merge-proposals.swift — reviewer-in-the-loop merger

        Usage:
          swift Scripts/merge-proposals.swift [flags]

        --auto-accept LEVEL  Skip prompts; merge all with confidence >= LEVEL
                             (high|medium|low).  No prompt = strict review.
        --input PATH         Proposals file (default Scripts/proposals.json).
        --catalog PATH       Catalog JSON (default Scripts/sovereignty-catalog.json).
        --dry-run            Show what would be merged; don't write.
        """)
        exit(0)
    default: fputs("warn: unknown flag '\(args[i])'\n", stderr)
    }
    i += 1
}

let confLevel: [String: Int] = ["low": 1, "medium": 2, "high": 3]
func meetsAutoLevel(_ confidence: String) -> Bool {
    guard let threshold = autoAccept.flatMap({ confLevel[$0] }) else { return false }
    return (confLevel[confidence.lowercased()] ?? 0) >= threshold
}

guard let propData = try? Data(contentsOf: URL(fileURLWithPath: inputPath)),
      let pf = try? JSONDecoder().decode(ProposalsFile.self, from: propData) else {
    fputs("error: could not read \(inputPath)\n", stderr)
    exit(1)
}
guard let catData = try? Data(contentsOf: URL(fileURLWithPath: catalogPath)),
      var catalog = try? JSONDecoder().decode(Catalog.self, from: catData) else {
    fputs("error: could not read \(catalogPath)\n", stderr)
    exit(1)
}

var knownBundleIDs = Set(catalog.entries.map { $0.targetBundleID })
var accepted = 0, skipped = 0, rejected = 0

// v1.4 audit: the proposals file may contain duplicate bundle IDs
// across proposals (e.g. the same app surfaced by two upstream
// sources, both submitted to the LLM, both produced suggestions).
// Pre-scan and warn so the reviewer sees the dup early.
var batchIDs: [String: Int] = [:]
for p in pf.proposals { batchIDs[p.bundleID, default: 0] += 1 }
let batchDupes = batchIDs.filter { $0.value > 1 }
if !batchDupes.isEmpty {
    fputs("⚠ batch contains duplicate bundle IDs (only the first of each will be merged):\n", stderr)
    for (bid, n) in batchDupes { fputs("    \(n)× \(bid)\n", stderr) }
}
var seenInBatch: Set<String> = []

print("Reviewing \(pf.proposals.count) proposals against \(catalog.entries.count) existing entries.")
if let lvl = autoAccept { print("Auto-accept threshold: \(lvl)") }
if dryRun { print("DRY RUN — no writes will happen.") }

for (idx, p) in pf.proposals.enumerated() {
    // Reject duplicates within the proposals file (after the first).
    if !seenInBatch.insert(p.bundleID).inserted {
        rejected += 1
        fputs("✗ rejected '\(p.displayName)' (\(p.bundleID)): duplicate within this batch\n", stderr)
        continue
    }
    do {
        try validate(p, knownBundleIDs: knownBundleIDs)
    } catch {
        rejected += 1
        fputs("✗ rejected '\(p.displayName)' (\(p.bundleID)): \(error)\n", stderr)
        continue
    }

    var decision: String
    if meetsAutoLevel(p.confidence) {
        decision = "a"
        if !dryRun {
            print("[auto] accepting \(p.displayName) (conf=\(p.confidence))")
        }
    } else {
        render(p, index: idx, total: pf.proposals.count)
        decision = promptDecision()
    }

    switch decision {
    case "a", "y", "yes":
        let e = entry(from: p)
        catalog.entries.append(e)
        knownBundleIDs.insert(e.targetBundleID)
        accepted += 1
    case "q", "quit":
        print("\nQuitting at proposal \(idx + 1)/\(pf.proposals.count). Already-accepted will still be saved.")
        break
    default:
        skipped += 1
    }
    if decision == "q" { break }
}

print("")
print("Summary: \(accepted) accepted · \(skipped) skipped · \(rejected) rejected (validation failed)")

if accepted > 0 && !dryRun {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    do {
        let data = try encoder.encode(catalog)
        try data.write(to: URL(fileURLWithPath: catalogPath))
        print("✓ wrote \(catalog.entries.count) entries to \(catalogPath)")
        print("")
        print("Next:")
        print("  swift Scripts/regenerate-sovereignty-catalog.swift")
        print("  swift Scripts/validate-catalog.swift")
        print("  swift run splynek-test")
    } catch {
        fputs("error: failed to write catalog: \(error)\n", stderr)
        exit(2)
    }
} else if dryRun && accepted > 0 {
    print("(dry-run: would have accepted \(accepted) entries)")
}
