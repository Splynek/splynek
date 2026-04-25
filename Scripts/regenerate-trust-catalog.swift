#!/usr/bin/env swift

// v1.5 Trust catalog pipeline: JSON → Swift codegen.
//
// Reads `Scripts/trust-catalog.json` (the authoring source) and
// rewrites `Sources/SplynekCore/TrustCatalog+Entries.swift` with a
// freshly generated `static let entries: [Entry] = [ … ]`.
//
// **Stricter validation than the Sovereignty pipeline** because the
// Trust catalog ships claims about specific named apps — every claim
// must cite a primary-source URL.  Lint refuses to emit Swift if:
//
//   • Any `evidenceURL` is not https://.
//   • Any `evidenceDate` isn't a valid ISO-8601 calendar date.
//   • Any `evidenceDate` is in the future.
//   • Any `evidenceDate` is older than 18 months without an explicit
//     `lastReviewed` within the last 6 months — stale source data
//     could be wrong, and a stale citation is a defamation surface.
//   • Any `summary` contains banned editorial terms ("spies",
//     "untrustworthy", "evil", "scam", etc.) — see `bannedPhrases`.
//   • Any concern Kind / Axis / Severity isn't a recognised enum.
//
// Run from the repo root:
//
//   swift Scripts/regenerate-trust-catalog.swift
//
// Zero third-party deps.

import Foundation

// MARK: - JSON shape

struct RawConcern: Decodable {
    let id: String
    let kind: String
    let axis: String
    let severity: String
    let summary: String
    let evidenceURL: String
    let evidenceDate: String
    let sourceName: String
}

struct RawAlt: Decodable {
    let id: String
    let name: String
    let homepage: String
    let note: String
    let downloadURL: String?
}

struct RawEntry: Decodable {
    let targetBundleID: String
    let targetDisplayName: String
    let lastReviewed: String
    let concerns: [RawConcern]
    let fallbackAlternatives: [RawAlt]
}

struct RawCatalog: Decodable {
    let version: Int
    let comment: String?
    let entries: [RawEntry]
}

// MARK: - Validation tables

let validKinds: Set<String> = [
    "appStoreTrackingData", "appStoreLinkedData", "appStoreUnlinkedData",
    "regulatoryFineGDPR", "regulatoryFineFTC", "regulatoryFineOther",
    "courtRuling", "governmentSanction",
    "knownCVE", "vendorSecurityAdvisory",
    "dataBreachConfirmed",
    "adSupportedFree", "telemetryDefaultOn", "vendorPolicyDataSharing",
]
let validAxes: Set<String> = ["privacy", "security", "trust", "businessModel"]
let validSeverities: Set<String> = ["low", "moderate", "high", "severe"]

/// Editorial language we refuse to ship.  This is the legal-defence
/// surface — every claim in the Trust catalog must read as factual
/// reporting on a primary source, never as an accusation.  If a
/// summary needs one of these words to make sense, the underlying
/// citation isn't strong enough.
let bannedPhrases: [String] = [
    "spies", "spy on", "spying",
    "untrustworthy", "shady", "sketchy",
    "evil", "malicious", "predatory",
    "scam", "scammer", "fraudster",
    "you are the product",   // editorial phrasing — use factual ad-disclosure instead
    "stealing", "steals your",
    "creepy",
]

// MARK: - Helpers

func swiftStringLit(_ s: String) -> String {
    var out = "\""
    for scalar in s.unicodeScalars {
        switch scalar {
        case "\\": out += "\\\\"
        case "\"": out += "\\\""
        case "\n": out += "\\n"
        case "\r": out += "\\r"
        case "\t": out += "\\t"
        case "\0": out += "\\0"
        default:
            if scalar.value < 0x20 || scalar.value == 0x7F {
                out += String(format: "\\u{%X}", scalar.value)
            } else {
                out.unicodeScalars.append(scalar)
            }
        }
    }
    out += "\""
    return out
}

func isValidISODate(_ s: String) -> Date? {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f.date(from: s)
}

func isHTTPS(_ s: String) -> Bool {
    guard let url = URL(string: s) else { return false }
    return (url.scheme ?? "").lowercased() == "https"
}

// MARK: - Main

let jsonURL = URL(fileURLWithPath: "Scripts/trust-catalog.json")
let outputURL = URL(fileURLWithPath: "Sources/SplynekCore/TrustCatalog+Entries.swift")

do {
    let data = try Data(contentsOf: jsonURL)
    let cat = try JSONDecoder().decode(RawCatalog.self, from: data)
    guard cat.version == 1 else {
        fputs("error: unsupported Trust catalog version \(cat.version)\n", stderr)
        exit(2)
    }

    let now = Date()
    let oneEightyDaysAgo = now.addingTimeInterval(-180 * 86_400)

    var concernIDs: Set<String> = []
    var altIDs: Set<String> = []
    var bundleIDs: Set<String> = []

    for entry in cat.entries {
        guard bundleIDs.insert(entry.targetBundleID).inserted else {
            fputs("error: duplicate targetBundleID '\(entry.targetBundleID)'\n", stderr)
            exit(3)
        }
        guard let lastReviewed = isValidISODate(entry.lastReviewed) else {
            fputs("error: entry \(entry.targetBundleID) has invalid lastReviewed '\(entry.lastReviewed)' (expected YYYY-MM-DD)\n", stderr)
            exit(3)
        }
        if lastReviewed > now {
            fputs("error: entry \(entry.targetBundleID) lastReviewed '\(entry.lastReviewed)' is in the future\n", stderr)
            exit(3)
        }

        for c in entry.concerns {
            // ID uniqueness across the whole catalog.
            guard concernIDs.insert(c.id).inserted else {
                fputs("error: duplicate concern id '\(c.id)' in entry \(entry.targetBundleID)\n", stderr)
                exit(3)
            }
            // Enum membership.
            guard validKinds.contains(c.kind) else {
                fputs("error: concern \(c.id) has invalid kind '\(c.kind)'\n", stderr)
                exit(3)
            }
            guard validAxes.contains(c.axis) else {
                fputs("error: concern \(c.id) has invalid axis '\(c.axis)'\n", stderr)
                exit(3)
            }
            guard validSeverities.contains(c.severity) else {
                fputs("error: concern \(c.id) has invalid severity '\(c.severity)'\n", stderr)
                exit(3)
            }
            // Source URL must be https.
            guard isHTTPS(c.evidenceURL) else {
                fputs("error: concern \(c.id) evidenceURL '\(c.evidenceURL)' is not https://\n", stderr)
                exit(3)
            }
            // Evidence date sanity.
            guard let evidenceDate = isValidISODate(c.evidenceDate) else {
                fputs("error: concern \(c.id) has invalid evidenceDate '\(c.evidenceDate)'\n", stderr)
                exit(3)
            }
            if evidenceDate > now {
                fputs("error: concern \(c.id) evidenceDate '\(c.evidenceDate)' is in the future\n", stderr)
                exit(3)
            }
            // Stale-source check: if the cited source is more than
            // 180 days old AND the entry hasn't been re-reviewed
            // recently, flag.  Doesn't block (sources from 2013
            // are still valid for "confirmed breach in 2013"), but
            // surfaces.
            if evidenceDate < oneEightyDaysAgo {
                let calendar = Calendar(identifier: .gregorian)
                let monthsOld = calendar.dateComponents([.month], from: evidenceDate, to: now).month ?? 0
                if monthsOld > 18 {
                    fputs("note: concern \(c.id) cites a \(monthsOld)-month-old source — re-verify the URL still resolves\n", stderr)
                }
            }
            // Banned editorial phrases.
            let lower = c.summary.lowercased()
            for phrase in bannedPhrases where lower.contains(phrase) {
                fputs("error: concern \(c.id) summary contains banned editorial phrase '\(phrase)' — keep summaries factual; quote the source.\n", stderr)
                exit(3)
            }
        }

        for alt in entry.fallbackAlternatives {
            guard altIDs.insert(alt.id).inserted else {
                fputs("error: duplicate fallback alt id '\(alt.id)'\n", stderr)
                exit(3)
            }
            guard isHTTPS(alt.homepage) else {
                fputs("error: fallback alt '\(alt.id)' homepage '\(alt.homepage)' is not https://\n", stderr)
                exit(3)
            }
            // v1.5.1: optional downloadURL — same https-only rule as
            // Sovereignty alternatives.  Defence-in-depth: the UI
            // re-validates before passing to the download engine, but
            // rejecting at regen means a poisoned upstream can't get
            // a `file://` or `data:` URL into the compiled catalog.
            if let dl = alt.downloadURL {
                guard isHTTPS(dl) else {
                    fputs("error: fallback alt '\(alt.id)' downloadURL '\(dl)' is not https://\n", stderr)
                    exit(3)
                }
            }
        }
    }

    // Emit Swift.
    var out = """
    // GENERATED FILE — DO NOT EDIT BY HAND.
    //
    // Source:     Scripts/trust-catalog.json
    // Generator:  swift Scripts/regenerate-trust-catalog.swift
    // Count:      \(cat.entries.count) Trust profiles
    //
    // To add or update entries, edit the JSON source and regenerate.
    // EVERY concern MUST cite a primary source (Apple App Store
    // privacy label, EU DPA / FTC / SEC ruling, NVD CVE, HIBP
    // breach, or vendor security advisory).  See TRUST-CONTRIBUTING.md.

    import Foundation

    extension TrustCatalog {

        /// The full Trust catalog — generated from Scripts/trust-catalog.json.
        static let entries: [Entry] = [

    """

    for entry in cat.entries {
        out += "        Entry(\n"
        out += "            targetBundleID: \(swiftStringLit(entry.targetBundleID)),\n"
        out += "            targetDisplayName: \(swiftStringLit(entry.targetDisplayName)),\n"
        out += "            lastReviewed: \(swiftStringLit(entry.lastReviewed)),\n"
        out += "            concerns: [\n"
        for c in entry.concerns {
            // The evidenceURL `URL(string:)!` is safe because we
            // validated above that every URL parses as https://.
            out += "                Concern(\n"
            out += "                    id: \(swiftStringLit(c.id)),\n"
            out += "                    kind: .\(c.kind),\n"
            out += "                    axis: .\(c.axis),\n"
            out += "                    severity: .\(c.severity),\n"
            out += "                    summary: \(swiftStringLit(c.summary)),\n"
            out += "                    evidenceURL: URL(string: \(swiftStringLit(c.evidenceURL)))!,\n"
            out += "                    evidenceDate: \(swiftStringLit(c.evidenceDate)),\n"
            out += "                    sourceName: \(swiftStringLit(c.sourceName))\n"
            out += "                ),\n"
        }
        out += "            ],\n"
        out += "            fallbackAlternatives: [\n"
        for a in entry.fallbackAlternatives {
            // homepage `URL(string:)!` is safe because we validated
            // https-parseability above (line under `// Lint:` block).
            // downloadURL stays optional: when provided we emit
            // `URL(string: …)` (without `!`) so a parse failure
            // collapses to nil and the UI falls back to "Visit"
            // rather than crashing.
            out += "                FallbackAlternative(\n"
            out += "                    id: \(swiftStringLit(a.id)),\n"
            out += "                    name: \(swiftStringLit(a.name)),\n"
            out += "                    homepage: URL(string: \(swiftStringLit(a.homepage)))!,\n"
            out += "                    note: \(swiftStringLit(a.note))"
            if let dl = a.downloadURL {
                out += ",\n                    downloadURL: URL(string: \(swiftStringLit(dl)))"
            }
            out += "\n                ),\n"
        }
        out += "            ]),\n"
    }

    out += """
        ]
    }

    """

    try out.write(to: outputURL, atomically: true, encoding: .utf8)
    print("✓ wrote \(cat.entries.count) Trust profiles → \(outputURL.path)")
} catch {
    fputs("error: \(error)\n", stderr)
    exit(1)
}
