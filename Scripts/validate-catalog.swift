#!/usr/bin/env swift

// v1.4 quality engine: offline validator for sovereignty-catalog.json.
//
// Complements SovereigntyCatalogTests (which enforces the load-bearing
// invariants at test time) with a richer **lint** pass that catches
// lower-severity quality issues: short/long notes, placeholder-looking
// homepages, non-reverse-DNS bundle IDs, alternatives with the same
// name inside one entry, etc.
//
// The invariant tests still stop the build on structural violations.
// This lint is softer — it prints a report and exits non-zero only
// when `--strict` is passed.  Intended for:
//   • pre-commit hook   (`swift Scripts/validate-catalog.swift`)
//   • weekly CI job     (`swift Scripts/validate-catalog.swift --strict`)
//   • manual authoring  (`swift Scripts/validate-catalog.swift --json`)
//
// Run from the repo root.  Zero third-party deps.

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

// MARK: - Lint rules

struct Finding {
    enum Severity: String { case error, warning, info }
    let severity: Severity
    let entryID: String    // targetBundleID
    let rule: String
    let message: String
}

let validOrigins: Set<String> = [
    "europe", "oss", "europeAndOSS", "unitedStates", "china", "russia", "other",
]
let recommendableOrigins: Set<String> = ["europe", "oss", "europeAndOSS"]
let forbiddenAltOrigins: Set<String> = ["unitedStates", "china", "russia"]

// Reverse-DNS bundle ID: two or more segments, lowercase alnum + hyphen.
// We don't demand full spec-compliance because Apple-signed apps sometimes
// use capitals / odd segments — but a bare word like "skype" is a red flag.
//
// These regexes are hard-coded literals — if NSRegularExpression init
// fails, that's a programmer error in the script itself (not in user
// data), so we surface it as a fatalError with a clear message rather
// than `try!` which prints an unfriendly trap message.
func mustCompile(_ pattern: String) -> NSRegularExpression {
    do {
        return try NSRegularExpression(pattern: pattern)
    } catch {
        fputs("validate-catalog: internal error compiling regex '\(pattern)': \(error)\n", stderr)
        exit(99)
    }
}
let bundleIDRegex = mustCompile(#"^[A-Za-z0-9][A-Za-z0-9_-]*(\.[A-Za-z0-9][A-Za-z0-9_-]*)+$"#)
let altIDRegex    = mustCompile(#"^[a-z0-9][a-z0-9_-]*:[a-z0-9][a-z0-9_-]*$"#)

// Placeholder-looking hosts we treat as definitely-bad.
let placeholderHosts: Set<String> = [
    "example.com", "localhost", "127.0.0.1", "tbd", "placeholder",
]

func lint(_ catalog: RawCatalog) -> [Finding] {
    var findings: [Finding] = []
    var seenBundleIDs: [String: Int] = [:]
    var seenAltIDs: [String: Int] = [:]

    for (idx, entry) in catalog.entries.enumerated() {
        let here = entry.targetBundleID
        let f = { (sev: Finding.Severity, rule: String, msg: String) in
            findings.append(.init(severity: sev, entryID: here, rule: rule, message: msg))
        }

        // — Target checks —
        let bidSeen = (seenBundleIDs[entry.targetBundleID] ?? 0) + 1
        seenBundleIDs[entry.targetBundleID] = bidSeen
        if bidSeen > 1 {
            f(.error, "dup-bundle-id",
              "duplicate targetBundleID (already seen in an earlier entry)")
        }
        if !isValidBundleID(entry.targetBundleID) {
            f(.warning, "bundle-id-format",
              "targetBundleID '\(entry.targetBundleID)' doesn't look like reverse-DNS")
        }
        if entry.targetDisplayName.trimmingCharacters(in: .whitespaces).isEmpty {
            f(.error, "empty-name", "targetDisplayName is empty")
        }
        if entry.targetDisplayName.count > 100 {
            f(.warning, "name-length",
              "targetDisplayName is \(entry.targetDisplayName.count) chars (>100 is too long)")
        }
        if !validOrigins.contains(entry.targetOrigin) {
            f(.error, "bad-origin",
              "targetOrigin '\(entry.targetOrigin)' is not a recognised enum case")
        }
        if recommendableOrigins.contains(entry.targetOrigin) {
            f(.error, "target-is-recommendable",
              "targetOrigin=\(entry.targetOrigin) — European/OSS apps aren't sovereignty targets")
        }

        // — Alternatives checks —
        if entry.alternatives.isEmpty {
            f(.error, "no-alternatives", "entry has zero alternatives")
        }
        let recommendableCount = entry.alternatives.filter {
            recommendableOrigins.contains($0.origin)
        }.count
        if recommendableCount == 0 {
            f(.error, "no-recommendable-alt",
              "entry has no .europe / .oss / .europeAndOSS alternative")
        }
        var namesHere: Set<String> = []
        for alt in entry.alternatives {
            // ID
            let altSeen = (seenAltIDs[alt.id] ?? 0) + 1
            seenAltIDs[alt.id] = altSeen
            if altSeen > 1 {
                f(.error, "dup-alt-id",
                  "alternative id '\(alt.id)' is not unique across the catalog")
            }
            if altIDRegex.firstMatch(in: alt.id, range: NSRange(alt.id.startIndex..., in: alt.id)) == nil {
                f(.warning, "alt-id-format",
                  "alt id '\(alt.id)' doesn't match '<slug>:<slug>'")
            }
            // Origin
            if !validOrigins.contains(alt.origin) {
                f(.error, "bad-alt-origin",
                  "alt '\(alt.id)' origin '\(alt.origin)' is not a recognised enum case")
            }
            if forbiddenAltOrigins.contains(alt.origin) {
                f(.error, "forbidden-alt-origin",
                  "alt '\(alt.id)' origin=\(alt.origin) — US/CN/RU alts are NEVER recommendable")
            }
            // Name
            let trimmedName = alt.name.trimmingCharacters(in: .whitespaces)
            if trimmedName.isEmpty {
                f(.error, "empty-alt-name", "alt '\(alt.id)' has empty name")
            }
            if trimmedName.count > 80 {
                f(.warning, "alt-name-long",
                  "alt '\(alt.id)' name is \(trimmedName.count) chars (>80)")
            }
            let nameLower = trimmedName.lowercased()
            if !nameLower.isEmpty {
                if namesHere.contains(nameLower) {
                    f(.warning, "dup-alt-name-in-entry",
                      "alt '\(alt.id)' name '\(trimmedName)' repeats within this entry")
                }
                namesHere.insert(nameLower)
            }
            // Homepage
            if let url = URL(string: alt.homepage), let host = url.host {
                if (url.scheme ?? "").lowercased() != "https" {
                    f(.warning, "homepage-not-https",
                      "alt '\(alt.id)' homepage uses scheme '\(url.scheme ?? "<none>")' (prefer https)")
                }
                if placeholderHosts.contains(host.lowercased()) {
                    f(.error, "placeholder-host",
                      "alt '\(alt.id)' homepage host '\(host)' is a placeholder")
                }
            } else {
                f(.error, "bad-homepage-url",
                  "alt '\(alt.id)' homepage '\(alt.homepage)' is not a parseable URL")
            }
            // Note
            let trimmedNote = alt.note.trimmingCharacters(in: .whitespaces)
            if trimmedNote.count < 10 {
                f(.warning, "note-short",
                  "alt '\(alt.id)' note is \(trimmedNote.count) chars (short — include country + license)")
            }
            if trimmedNote.count > 250 {
                f(.warning, "note-long",
                  "alt '\(alt.id)' note is \(trimmedNote.count) chars (>250)")
            }
            // Download URL
            if let dl = alt.downloadURL {
                if let url = URL(string: dl) {
                    if (url.scheme ?? "").lowercased() != "https" {
                        f(.warning, "download-not-https",
                          "alt '\(alt.id)' downloadURL scheme is '\(url.scheme ?? "<none>")' (should be https)")
                    }
                } else {
                    f(.error, "bad-download-url",
                      "alt '\(alt.id)' downloadURL '\(dl)' is not a parseable URL")
                }
            }
        }
        _ = idx
    }
    return findings
}

func isValidBundleID(_ s: String) -> Bool {
    let r = NSRange(s.startIndex..., in: s)
    return bundleIDRegex.firstMatch(in: s, range: r) != nil
}

// MARK: - Output

enum OutputFormat { case text, json }

func printReport(_ findings: [Finding], total: Int, format: OutputFormat) {
    let errors = findings.filter { $0.severity == .error }
    let warnings = findings.filter { $0.severity == .warning }
    let infos = findings.filter { $0.severity == .info }

    switch format {
    case .json:
        struct Out: Encodable {
            let totalEntries: Int
            let errorCount: Int
            let warningCount: Int
            let infoCount: Int
            let findings: [Item]
            struct Item: Encodable {
                let severity: String
                let entry: String
                let rule: String
                let message: String
            }
        }
        let out = Out(
            totalEntries: total,
            errorCount: errors.count,
            warningCount: warnings.count,
            infoCount: infos.count,
            findings: findings.map { .init(severity: $0.severity.rawValue,
                                           entry: $0.entryID, rule: $0.rule, message: $0.message) }
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        if let data = try? encoder.encode(out),
           let s = String(data: data, encoding: .utf8) {
            print(s)
        }
    case .text:
        if errors.isEmpty && warnings.isEmpty {
            print("✓ \(total) entries, no lint findings.")
            return
        }
        for f in findings {
            let tag: String
            switch f.severity {
            case .error:   tag = "✗ ERROR  "
            case .warning: tag = "⚠ WARN   "
            case .info:    tag = "ℹ INFO   "
            }
            print("\(tag) [\(f.rule)] \(f.entryID) — \(f.message)")
        }
        print("")
        print("Summary: \(total) entries · \(errors.count) errors · \(warnings.count) warnings · \(infos.count) info")
    }
}

// MARK: - Main

let args = Array(CommandLine.arguments.dropFirst())
var strict = false
var format: OutputFormat = .text
for arg in args {
    switch arg {
    case "--strict":  strict = true
    case "--json":    format = .json
    case "--help", "-h":
        print("""
        validate-catalog.swift — lint Scripts/sovereignty-catalog.json

        Usage:
          swift Scripts/validate-catalog.swift [--strict] [--json]

        --strict   Exit non-zero if any warnings are found (errors already do).
        --json     Emit findings as JSON instead of text.
        """)
        exit(0)
    default:
        fputs("warn: unknown flag '\(arg)'\n", stderr)
    }
}

let jsonURL = URL(fileURLWithPath: "Scripts/sovereignty-catalog.json")
do {
    let data = try Data(contentsOf: jsonURL)
    let cat = try JSONDecoder().decode(RawCatalog.self, from: data)
    let findings = lint(cat)
    printReport(findings, total: cat.entries.count, format: format)

    let errorCount = findings.filter { $0.severity == .error }.count
    let warningCount = findings.filter { $0.severity == .warning }.count
    if errorCount > 0 {
        exit(1)
    }
    if strict && warningCount > 0 {
        exit(2)
    }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(3)
}
