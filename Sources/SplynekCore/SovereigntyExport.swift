import Foundation

/// v1.4: dump the Sovereignty catalog as JSON.  Public facade used
/// by the `splynek-cli sovereignty-dump` subcommand so the hand-written
/// Swift catalog can be round-tripped into `Scripts/sovereignty-catalog.json`.
///
/// Not used at runtime by the app itself.  Exists purely as a
/// build-time tool to support the Swift ⇄ JSON round-trip during the
/// v1.4 catalog-pipeline refactor.
/// Public because `splynek-cli` is a separate SPM module that
/// imports SplynekCore — internal symbols wouldn't cross the
/// module boundary.  Earlier round of audit suggested narrowing
/// to internal; doing so breaks the splynek-cli compile.  Keep
/// public; the surface is one method.
public enum SovereigntyExport {

    /// Emit the full catalog as pretty-printed JSON on the given
    /// handle (stdout by default).  Format is stable and matches
    /// what `Scripts/regenerate-sovereignty-catalog.swift` consumes.
    public static func dumpJSON(to handle: FileHandle = .standardOutput) throws {
        struct Payload: Encodable {
            let version: Int
            let comment: String
            let entries: [SovereigntyCatalog.Entry]
        }
        let payload = Payload(
            version: 1,
            comment: "Splynek Sovereignty catalog. Edit this file, then run 'swift Scripts/regenerate-sovereignty-catalog.swift' to refresh SovereigntyCatalog+Entries.swift. See SOVEREIGNTY-CONTRIBUTING.md.",
            entries: SovereigntyCatalog.entries
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(payload)
        handle.write(data)
        handle.write(Data("\n".utf8))
    }

    // =================================================================
    // v1.7.x: CSV export of installed-apps × catalog matches
    // =================================================================
    //
    // Designed for spreadsheet consumption + downstream tooling — RFC
    // 4180 dialect, UTF-8 with no BOM, `\n` line endings.  Scope: only
    // installed apps that have a catalog hit; each (installed-app,
    // alternative) pair becomes one row.  Cells are English regardless
    // of UI locale because CSV is canonically a data-interchange format
    // and English keeps downstream `joins`/`sorts` predictable.

    /// Schema version embedded as a comment in row 0 — bump when the
    /// column set changes so downstream tooling can detect format drift.
    static let csvSchemaVersion = 1

    /// Columns emitted by `csv(installedApps:scannedAt:)`, in order.
    /// Mirrors the natural fields of `SovereigntyCatalog.Entry` +
    /// `Alternative`, plus a `scanned_at` ISO-8601 timestamp.
    static let csvColumns: [String] = [
        "bundleID",
        "displayName",
        "origin",
        "alt_name",
        "alt_origin",
        "alt_homepage",
        "alt_note",
        "alt_canInstall",
        "alt_downloadURL",
        "scanned_at",
    ]

    /// Render one CSV file body as a String.  Caller writes via
    /// `Data(_.utf8).write(to:options:.atomic)`.  Empty installed-apps
    /// input still produces a valid file (schema-version comment +
    /// header row).
    static func csv(
        installedApps: [SovereigntyScanner.InstalledApp],
        scannedAt: Date = Date()
    ) -> String {
        var lines: [String] = []
        // Schema-version pseudo-comment.  RFC 4180 doesn't define
        // comments, but most parsers tolerate a `#`-prefixed line.
        // We emit one so downstream code can branch on schema_version
        // before parsing column headers.
        lines.append("# splynek_sovereignty_csv_schema=\(csvSchemaVersion)")
        lines.append(csvColumns.joined(separator: ","))

        let timestamp = csvISO8601(scannedAt)

        for app in installedApps {
            guard let entry = SovereigntyCatalog.alternatives(for: app.id)
            else { continue }
            for alt in entry.alternatives {
                let row = [
                    entry.targetBundleID,
                    entry.targetDisplayName,
                    entry.targetOrigin.rawValue,
                    alt.name,
                    alt.origin.rawValue,
                    alt.homepage.absoluteString,
                    alt.note,
                    alt.downloadURL != nil ? "true" : "false",
                    alt.downloadURL?.absoluteString ?? "",
                    timestamp,
                ]
                lines.append(row.map(csvEscape).joined(separator: ","))
            }
        }

        // Trailing `\n` so the file ends cleanly (RFC 4180 §2.2 says
        // last record may or may not have a newline; line-by-line
        // tools are happier with a terminator).
        return lines.joined(separator: "\n") + "\n"
    }

    /// RFC 4180 field escaping:
    /// - Wrap in double quotes if the field contains `,`, `"`, `\n`,
    ///   or `\r`.
    /// - Inside a quoted field, double up any embedded `"` (so `a"b`
    ///   becomes `"a""b"`).
    /// - Plain fields pass through unchanged.
    static func csvEscape(_ field: String) -> String {
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        if !needsQuoting { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static let csvISO8601Formatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func csvISO8601(_ date: Date) -> String {
        csvISO8601Formatter.string(from: date)
    }
}
