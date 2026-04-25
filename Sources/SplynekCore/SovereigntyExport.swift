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
}
