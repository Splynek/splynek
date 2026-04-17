import Foundation

/// Generate an equivalent `curl` invocation for a given download, so a user
/// can reproduce the request in CI or share it in a bug report.
///
/// Note: `curl --interface` takes an interface name or source IP; this
/// produces one command *per interface*, since curl itself doesn't
/// aggregate across interfaces the way Splynek does.
enum CurlExport {

    struct Options {
        var urls: [URL]
        var outputFilename: String
        var interfaces: [String]  // BSD names
        var sha256: String?
    }

    static func generate(_ opts: Options) -> String {
        var lines: [String] = ["#!/usr/bin/env bash", "set -euo pipefail", ""]
        lines.append("# Equivalent single-interface downloads.")
        lines.append("# Splynek aggregates across interfaces in parallel; curl does not,")
        lines.append("# so this script reproduces the request N times, once per interface.")
        lines.append("")
        for (i, iface) in opts.interfaces.enumerated() {
            let outputPath = "\"\(opts.outputFilename).lane-\(iface)\""
            let url = opts.urls[i % opts.urls.count].absoluteString
            lines.append(
                "curl -fL --interface \(shell(iface)) -o \(outputPath) \(shell(url))"
            )
        }
        if let want = opts.sha256 {
            lines.append("")
            lines.append("expected=\(shell(want))")
            lines.append("got=\"$(shasum -a 256 \(shell(opts.outputFilename)) | awk '{print $1}')\"")
            lines.append("[ \"$got\" = \"$expected\" ] || { echo 'sha-256 mismatch' >&2; exit 1; }")
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private static func shell(_ s: String) -> String {
        // Safe single-quoting: close, escape, reopen.
        "'\(s.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
