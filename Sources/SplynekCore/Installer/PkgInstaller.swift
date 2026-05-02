import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// PkgInstaller spawns Apple's signed /usr/sbin/installer with hard-
// coded arguments (-pkg <user-supplied path> -target <user-domain>).
// installer(8) is signed system tooling; it verifies the .pkg's own
// signature before deploying any payload, refuses unsigned packages
// by default, and follows the rules baked into the .pkg's
// PackageInfo.  Splynek does not ship pre-install or post-install
// scripts, never auto-launches the deployed binaries, and never
// passes user-controlled flags to installer(8).
//
// v1.8.0 ships USER-DOMAIN ONLY (no admin auth).  Many .pkg
// installers — particularly publisher-distributed app updates — only
// need user-domain access to deploy a single .app to /Applications
// when the user owns that directory.  System-domain installs (kexts,
// drivers, /Library/LaunchDaemons) require Authorization-framework
// admin auth and land in v1.8.1.  When the .pkg requires
// elevation, installer(8) returns a clear "must be run as root"
// error which we surface verbatim with a "needs admin — run
// /usr/sbin/installer manually for now" hint.
// =====================================================================

/// v1.8.0: install handler for `.pkg` (Apple Installer) payloads.
///
/// User-domain only.  Spawns:
///
///     /usr/sbin/installer -pkg <pkg-path> -target CurrentUserHomeDirectory
///
/// `CurrentUserHomeDirectory` is Apple's well-known target name for
/// the per-user install domain (`~`).  Packages that need
/// `LocalSystem` or `LocalDomain` will fail with a clear error
/// message — the v1.8.1 admin-auth flow handles those.
///
/// **Why not a custom .pkg payload reader?**  Because installer(8)
/// has 25 years of edge-case handling for `.pkg`'s many internal
/// formats (flat, distribution, bundle).  Re-implementing that is a
/// 2.5.2 risk and a maintenance burden.  Letting Apple's tool do
/// its job is the right answer.
enum PkgInstaller {

    enum Failure: Error, LocalizedError, Sendable {
        case installerFailed(exitCode: Int32, stderr: String)
        case requiresAdmin(stderr: String)
        case ioError(String)

        var errorDescription: String? {
            switch self {
            case .installerFailed(let code, let stderr):
                return "installer(8) exited with status \(code): \(stderr)"
            case .requiresAdmin(let stderr):
                return "This package needs administrator access (\(stderr.prefix(120))). Splynek's v1.8.0 ships user-domain installs only — admin-domain support lands in v1.8.1. For now, run /usr/sbin/installer manually with sudo."
            case .ioError(let s):
                return "I/O error: \(s)"
            }
        }
    }

    /// Run installer(8) against a .pkg in user domain.  Returns void
    /// — pkg installs don't have a single "where did the .app land"
    /// answer (a pkg can deploy multiple files, scripts, plist
    /// settings).  The post-install registry record uses the .pkg's
    /// metadata as a coarse breadcrumb; v1.8.1 will parse the .pkg's
    /// receipt for a more precise mapping.
    ///
    /// `target` defaults to "CurrentUserHomeDirectory" — the user
    /// domain.  Passing "LocalSystem" or "/" forces system-domain
    /// install which today is rejected (v1.8.1 admin-auth work).
    static func install(
        pkg: URL,
        target: String = "CurrentUserHomeDirectory"
    ) async throws {
        guard FileManager.default.fileExists(atPath: pkg.path) else {
            throw Failure.ioError("Package not found: \(pkg.path)")
        }
        guard target == "CurrentUserHomeDirectory" else {
            throw Failure.requiresAdmin(
                stderr: "Splynek refused a non-user-domain target ('\(target)') in v1.8.0."
            )
        }

        let result = await runInstaller([
            "-pkg", pkg.path,
            "-target", target,
        ])
        if result.exitCode == 0 { return }

        // installer(8) emits a few canonical error strings.  Detect
        // the admin-needed case so the error message can guide the
        // user.
        let combined = (result.stderr + "\n" + result.stdout).lowercased()
        let adminMarkers = [
            "must be run as root",
            "permission denied",
            "you must be authenticated",
            "operation not permitted",
            "requires administrator",
        ]
        if adminMarkers.contains(where: { combined.contains($0) }) {
            throw Failure.requiresAdmin(stderr: result.stderr.isEmpty ? result.stdout : result.stderr)
        }
        throw Failure.installerFailed(
            exitCode: result.exitCode,
            stderr: result.stderr.isEmpty ? result.stdout : result.stderr
        )
    }

    // MARK: - Process plumbing

    struct ProcessResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    /// Async wrapper around installer — installer can take 5–60 s
    /// on a large package, so we yield to the runtime.
    static func runInstaller(_ args: [String]) async -> ProcessResult {
        await Task.detached { runInstallerSync(args) }.value
    }

    /// Synchronous spawn of /usr/sbin/installer.  Hard-coded path —
    /// installer(8) is at the same well-known location on every
    /// macOS shipped since 10.5.
    static func runInstallerSync(_ args: [String]) -> ProcessResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/installer")
        proc.arguments = args
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            return ProcessResult(
                exitCode: -1,
                stdout: "",
                stderr: "Failed to launch installer(8): \(error.localizedDescription)"
            )
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        return ProcessResult(
            exitCode: proc.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
