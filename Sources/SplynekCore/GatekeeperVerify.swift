import Foundation

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
}
