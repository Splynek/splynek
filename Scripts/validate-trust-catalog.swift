#!/usr/bin/env swift

// v1.5: offline lint for Scripts/trust-catalog.json.  Stricter than
// the Sovereignty validator because Trust ships claims about specific
// named apps — every one needs to read as factual reporting.
//
// The regenerator already enforces hard requirements (https URLs,
// valid enums, no banned phrases, valid dates).  This validator
// adds soft quality checks suitable for CI:
//
//   • lastReviewed older than 6 months → warn
//   • concern with >2 high+severe concerns and no fallback alts → warn
//   • summary >280 chars → warn (reads as commentary, not a fact)
//   • summary <30 chars → warn (probably too terse to be informative)
//   • sourceName not in known list → warn (probably a typo)
//
// Run: swift Scripts/validate-trust-catalog.swift [--strict]
// `--strict` makes warnings fail the run.  Zero deps.

import Foundation

struct RawConcern: Decodable {
    let id, kind, axis, severity, summary, evidenceURL, evidenceDate, sourceName: String
}
struct RawAlt: Decodable { let id, name, homepage, note: String }
struct RawEntry: Decodable {
    let targetBundleID, targetDisplayName, lastReviewed: String
    let concerns: [RawConcern]
    let fallbackAlternatives: [RawAlt]
}
struct RawCatalog: Decodable { let version: Int; let comment: String?; let entries: [RawEntry] }

let knownSources: Set<String> = [
    "Apple App Store",
    "Apple Security Notes",
    "Microsoft Security Response Center",
    "MSRC",
    "Google Project Zero",
    "Adobe Security Bulletin",
    "Mozilla Security Advisory",
    "Cursor privacy policy",
    "CNIL",
    "Irish DPC",
    "Garante per la protezione dei dati personali",
    "ICO",
    "AEPD",
    "Bundeskartellamt",
    "Datatilsynet",
    "FTC",
    "SEC",
    "California AG",
    "US OFAC",
    "US CISA",
    "US BIS",
    "NVD",
    "HIBP",
    "LastPass security advisory",
    "Slack security advisory",
]

struct Finding {
    enum Severity: String { case error, warning, info }
    let severity: Severity
    let entry: String
    let rule: String
    let message: String
}

let args = Array(CommandLine.arguments.dropFirst())
let strict = args.contains("--strict")

let url = URL(fileURLWithPath: "Scripts/trust-catalog.json")
do {
    let data = try Data(contentsOf: url)
    let cat = try JSONDecoder().decode(RawCatalog.self, from: data)

    var findings: [Finding] = []

    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    let now = Date()
    let sixMonthsAgo = now.addingTimeInterval(-180 * 86_400)

    for entry in cat.entries {
        // lastReviewed staleness
        if let last = f.date(from: entry.lastReviewed), last < sixMonthsAgo {
            let cal = Calendar(identifier: .gregorian)
            let months = cal.dateComponents([.month], from: last, to: now).month ?? 0
            findings.append(.init(severity: .warning, entry: entry.targetBundleID,
                                  rule: "stale-review",
                                  message: "lastReviewed \(months) months ago — re-verify sources"))
        }

        // Summary length + sourceName quality
        for c in entry.concerns {
            let len = c.summary.count
            if len > 280 {
                findings.append(.init(severity: .warning, entry: c.id,
                                      rule: "summary-long",
                                      message: "summary is \(len) chars (>280 reads as commentary)"))
            }
            if len < 30 {
                findings.append(.init(severity: .warning, entry: c.id,
                                      rule: "summary-short",
                                      message: "summary is \(len) chars (probably too terse)"))
            }
            if !knownSources.contains(c.sourceName) {
                findings.append(.init(severity: .warning, entry: c.id,
                                      rule: "unknown-source",
                                      message: "sourceName '\(c.sourceName)' not in allowlist — typo or new source?"))
            }
        }

        // Apps with multiple severe concerns + no fallback alts
        let severeCount = entry.concerns.filter {
            $0.severity == "high" || $0.severity == "severe"
        }.count
        if severeCount >= 2 && entry.fallbackAlternatives.isEmpty {
            findings.append(.init(severity: .info, entry: entry.targetBundleID,
                                  rule: "no-alts-but-severe",
                                  message: "\(severeCount) high+severe concerns and no Trust fallback alts — relies entirely on Sovereignty"))
        }
    }

    let errors = findings.filter { $0.severity == .error }.count
    let warnings = findings.filter { $0.severity == .warning }.count
    let infos = findings.filter { $0.severity == .info }.count

    if findings.isEmpty {
        print("✓ \(cat.entries.count) Trust entries, no lint findings.")
    } else {
        for fnd in findings {
            let tag: String
            switch fnd.severity {
            case .error:   tag = "✗ ERROR  "
            case .warning: tag = "⚠ WARN   "
            case .info:    tag = "ℹ INFO   "
            }
            print("\(tag)[\(fnd.rule)] \(fnd.entry) — \(fnd.message)")
        }
        print("")
        print("Summary: \(cat.entries.count) entries · \(errors) errors · \(warnings) warnings · \(infos) info")
    }

    if errors > 0 { exit(1) }
    if strict && warnings > 0 { exit(2) }
} catch {
    fputs("error: \(error)\n", stderr)
    exit(3)
}
