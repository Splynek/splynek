import Foundation

enum Sanitize {

    /// Return a safe filename for writing under a user-chosen directory.
    ///
    /// A `Content-Disposition` filename comes from the server and must be
    /// treated as untrusted:
    ///   - `/` and `\` are stripped so the server can't direct us outside
    ///     the chosen output directory (path-traversal defence).
    ///   - Null bytes and C0 control characters are removed.
    ///   - Leading dots are collapsed so the result isn't hidden on macOS.
    ///   - Length is capped at 200 bytes while preserving the extension.
    ///   - An empty result falls back to `download.bin`.
    static func filename(_ raw: String) -> String {
        // `lastPathComponent` strips any `/`-delimited parents the server
        // might have inserted (e.g. `../../../etc/evil`).
        var name = (raw as NSString).lastPathComponent

        // Back-slash isn't a macOS path separator, but some senders (and
        // zip archives) use it — strip defensively.
        name = name.replacingOccurrences(of: "\\", with: "_")
        name = name.replacingOccurrences(of: "/", with: "_")

        // Drop null bytes and C0 / DEL control characters.
        name = String(name.unicodeScalars.filter {
            $0.value >= 0x20 && $0.value != 0x7F
        })

        // Strip leading dots (prevents `.bashrc`-style hidden writes).
        while name.hasPrefix(".") { name.removeFirst() }

        name = name.trimmingCharacters(in: .whitespaces)

        if name.utf8.count > 200 {
            let ext = (name as NSString).pathExtension
            let base = (name as NSString).deletingPathExtension
            let maxBase = max(8, 200 - ext.utf8.count - 1)
            let truncated = String(base.prefix(maxBase))
            name = ext.isEmpty ? truncated : "\(truncated).\(ext)"
        }

        return name.isEmpty ? "download.bin" : name
    }
}
