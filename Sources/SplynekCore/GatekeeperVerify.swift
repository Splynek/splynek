import Foundation

/// Richer Gatekeeper evaluation result used by the History detail
/// sheet's Signature panel (v0.39+). The summary `GatekeeperVerdict`
/// still drives the completion-phase pill; this struct unpacks the
/// per-field information the user wants when they click in for
/// details: who signed it, which team, is it notarized, is the
/// notarization stapled, what's the code-directory hash.
///
/// Populated by merging three tool outputs:
///   - `spctl -a -vv -t execute` — accepted/rejected + source/origin
///   - `codesign -dv --verbose=4` — authority chain + team ID + CDHash
///   - `stapler validate`        — is the notarization ticket stapled
///
/// Parsing lives in a pure static function so tests can pin the
/// field extraction against recorded tool outputs.
struct GatekeeperDetail: Equatable, Sendable {
    var accepted: Bool
    /// `source=...` line from spctl. "Notarized Developer ID" is the
    /// golden path; "Unnotarized Developer ID" / "Unsigned" / etc.
    /// fall through to here verbatim.
    var source: String?
    /// `origin=...` line from spctl, typically the full subject of
    /// the Developer ID certificate.
    var origin: String?
    /// Authority chain from codesign, outermost cert first.
    var authorities: [String]
    /// Team identifier (10-char string) from `TeamIdentifier=`.
    var teamID: String?
    /// SHA-256 code-directory hash, if codesign reported it.
    var cdHashSHA256: String?
    /// True iff `stapler validate` succeeded, false if it
    /// explicitly failed, nil if the tool wasn't run / was
    /// inconclusive (e.g., offline + Apple ticket server unreachable).
    var notarizationStapled: Bool?
    /// Concatenation of the three tool stderr/stdout streams, for
    /// the diagnostic "Show raw" disclosure.
    var raw: String

    /// Human-readable one-line summary suitable for a pill /
    /// accessory: "Developer ID · notarized & stapled".
    var headline: String {
        var parts: [String] = []
        if accepted { parts.append("Accepted") } else { parts.append("Rejected") }
        if let s = source, !s.isEmpty { parts.append(s) }
        if notarizationStapled == true { parts.append("stapled") }
        if notarizationStapled == false { parts.append("not stapled") }
        return parts.joined(separator: " · ")
    }
}

/// Run `spctl -a` against a completed download to surface Gatekeeper's
/// verdict *before* the user double-clicks. Only evaluates file types
/// Gatekeeper actually cares about (.app / .pkg / .dmg).
enum GatekeeperVerify {

    static func evaluate(_ url: URL) async -> GatekeeperVerdict {
        let ext = url.pathExtension.lowercased()
        guard ["app", "pkg", "dmg", "mpkg"].contains(ext) else {
            return .notApplicable
        }

        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let proc = Process()
                proc.launchPath = "/usr/sbin/spctl"
                proc.arguments = ["-a", "-vv", "-t", "execute", url.path]
                let errPipe = Pipe()
                proc.standardOutput = Pipe()
                proc.standardError = errPipe
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: errData, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    if proc.terminationStatus == 0 {
                        cont.resume(returning: .accepted(summarize(output)))
                    } else {
                        cont.resume(returning: .rejected(summarize(output)))
                    }
                } catch {
                    cont.resume(returning: .unavailable(error.localizedDescription))
                }
            }
        }
    }

    /// Keep just the most informative lines. spctl's stderr is noisy.
    private static func summarize(_ raw: String) -> String {
        let interesting = raw.split(separator: "\n").filter {
            $0.contains("accepted") || $0.contains("rejected") ||
            $0.contains("source=") || $0.contains("origin=")
        }
        return interesting.joined(separator: " · ")
    }

    // MARK: - Detail evaluation (v0.39)

    /// Run the three signature tools against a bundle / pkg / dmg
    /// and merge their outputs. Returns nil when the file type isn't
    /// in the Gatekeeper-evaluable set — the caller should skip the
    /// Signature card in that case rather than show an empty one.
    static func evaluateDetail(_ url: URL) async -> GatekeeperDetail? {
        let ext = url.pathExtension.lowercased()
        guard ["app", "pkg", "dmg", "mpkg"].contains(ext) else { return nil }

        return await withCheckedContinuation { cont in
            DispatchQueue.global(qos: .userInitiated).async {
                let spctl = runTool(
                    path: "/usr/sbin/spctl",
                    arguments: ["-a", "-vv", "-t", "execute", url.path]
                )
                let codesign = runTool(
                    path: "/usr/bin/codesign",
                    arguments: ["-dv", "--verbose=4", url.path]
                )
                let stapler = runTool(
                    path: "/usr/bin/xcrun",
                    arguments: ["stapler", "validate", url.path]
                )
                let detail = parseDetail(
                    spctlOutput: spctl.combined,
                    spctlAccepted: spctl.exitCode == 0,
                    codesignOutput: codesign.combined,
                    staplerOutput: stapler.combined,
                    staplerExit: stapler.exitCode
                )
                cont.resume(returning: detail)
            }
        }
    }

    /// Pure parser — exposed internal for test access. Takes the
    /// merged stdout+stderr blob from each tool plus spctl's exit
    /// code, returns the structured detail.
    static func parseDetail(
        spctlOutput: String,
        spctlAccepted: Bool,
        codesignOutput: String,
        staplerOutput: String,
        staplerExit: Int32
    ) -> GatekeeperDetail {
        let source = matchSingle(prefix: "source=", in: spctlOutput)
        let origin = matchSingle(prefix: "origin=", in: spctlOutput)
        let authorities = codesignOutput
            .split(separator: "\n")
            .compactMap { line -> String? in
                let t = line.trimmingCharacters(in: .whitespaces)
                guard t.hasPrefix("Authority=") else { return nil }
                return String(t.dropFirst("Authority=".count))
            }
        let teamID = matchSingle(prefix: "TeamIdentifier=", in: codesignOutput)
            .flatMap { $0 == "not set" ? nil : $0 }
        let cdHash = codesignOutput
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { $0.hasPrefix("CDHash=") }
            .map { String($0.dropFirst("CDHash=".count)) }

        // stapler's output is human-prose; key off its exit code for
        // the authoritative answer, then look for the sentinel
        // message to distinguish "not stapled" from "tool missing."
        let notarizationStapled: Bool?
        let stapLower = staplerOutput.lowercased()
        if staplerExit == 0, stapLower.contains("the validate action worked") {
            notarizationStapled = true
        } else if stapLower.contains("does not have a ticket")
                    || stapLower.contains("could not validate ticket")
                    || stapLower.contains("cloudkit query") {
            notarizationStapled = false
        } else {
            notarizationStapled = nil
        }

        let raw = [
            "---- spctl ----", spctlOutput,
            "---- codesign ----", codesignOutput,
            "---- stapler ----", staplerOutput
        ].joined(separator: "\n")

        return GatekeeperDetail(
            accepted: spctlAccepted,
            source: source,
            origin: origin,
            authorities: authorities,
            teamID: teamID,
            cdHashSHA256: cdHash,
            notarizationStapled: notarizationStapled,
            raw: raw
        )
    }

    // MARK: - Helpers

    private struct ToolResult {
        let exitCode: Int32
        let combined: String
    }

    private static func runTool(path: String, arguments: [String]) -> ToolResult {
        guard FileManager.default.fileExists(atPath: path) else {
            return ToolResult(exitCode: -1, combined: "")
        }
        let proc = Process()
        proc.launchPath = path
        proc.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err
        do {
            try proc.run()
            proc.waitUntilExit()
            let o = String(data: out.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            let e = String(data: err.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return ToolResult(exitCode: proc.terminationStatus, combined: o + e)
        } catch {
            return ToolResult(exitCode: -1, combined: "")
        }
    }

    /// Find the first line starting with `prefix` and return the
    /// remainder (trimmed). Returns nil if no such line.
    private static func matchSingle(prefix: String, in text: String) -> String? {
        for raw in text.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix(prefix) {
                return String(line.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }
}
