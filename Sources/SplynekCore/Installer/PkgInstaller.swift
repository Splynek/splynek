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
        case adminDeclined
        case ioError(String)

        var errorDescription: String? {
            switch self {
            case .installerFailed(let code, let stderr):
                return "installer(8) exited with status \(code): \(stderr)"
            case .requiresAdmin(let stderr):
                return "This package needs administrator access (\(stderr.prefix(120))). Pass `requireAdmin: true` to install via osascript-elevated installer(8) — Splynek will prompt for your admin password."
            case .adminDeclined:
                return "Administrator authorization was declined or the prompt was cancelled."
            case .ioError(let s):
                return "I/O error: \(s)"
            }
        }
    }

    /// Run installer(8) against a .pkg in user domain.  Returns void
    /// — pkg installs don't have a single "where did the .app land"
    /// answer (a pkg can deploy multiple files, scripts, plist
    /// settings).  The post-install registry record uses the .pkg's
    /// metadata as a coarse breadcrumb; a future revision can parse
    /// the .pkg's receipt for a more precise mapping.
    ///
    /// `target` defaults to "CurrentUserHomeDirectory" — the user
    /// domain (no admin prompt).  Pass "LocalSystem" or "/" for
    /// admin-domain installs (kexts, /Library/LaunchDaemons,
    /// /Library/PrivilegedHelperTools); admin-domain currently
    /// requires `requireAdmin: true` so the caller opts in.
    ///
    /// **v1.8.1 admin-domain (`requireAdmin: true`).**  Spawns
    /// /usr/bin/osascript with `do shell script ... with administrator
    /// privileges`, which surfaces macOS's standard authorization
    /// dialog (Touch ID / password).  No SMJobBless helper-tool;
    /// install is a one-shot privileged spawn.  When the user
    /// declines or cancels, throws `.adminDeclined`.
    ///
    /// MAS-review note: AppleScript-driven elevation is the path
    /// most third-party installers use.  The alternative
    /// (SMJobBless + privileged helper bundle) is the long-term
    /// "right" answer but requires app re-architecture; deferring
    /// to v1.8.2.  Documented in MAS-2.5.2-COMPLIANCE.md.
    static func install(
        pkg: URL,
        target: String = "CurrentUserHomeDirectory",
        requireAdmin: Bool = false
    ) async throws {
        guard FileManager.default.fileExists(atPath: pkg.path) else {
            throw Failure.ioError("Package not found: \(pkg.path)")
        }

        // Admin-domain path — osascript-elevated installer(8).
        if requireAdmin {
            try await installWithAdminPrompt(pkg: pkg, target: target)
            return
        }

        guard target == "CurrentUserHomeDirectory" else {
            throw Failure.requiresAdmin(
                stderr: "Non-user-domain target '\(target)' rejected; pass requireAdmin: true to elevate."
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

    /// v1.8.1: admin-domain install via osascript-elevated installer(8).
    ///
    /// Spawns `/usr/bin/osascript` with the AppleScript fragment:
    ///
    ///   do shell script "/usr/sbin/installer -pkg <quoted-path> -target /"
    ///   with administrator privileges
    ///
    /// macOS surfaces its standard authorization dialog.  When the
    /// user authorises, installer(8) runs as root and the install
    /// completes.  When the user cancels, osascript exits with code
    /// -128 (errAEEventNotHandled) — we surface that as
    /// `.adminDeclined`.
    ///
    /// Path quoting: AppleScript's `quoted form of` would normally
    /// handle this, but we precompute the quoted form in Swift so
    /// the AppleScript command is a fixed shape (no AppleScript
    /// string concatenation that could be confused by an attacker-
    /// controlled path).  The file path is from `pkg.path`, which
    /// the user has already picked via NSOpenPanel + the verifier
    /// pipeline has SHA-256-checked + Gatekeeper-cleared by the
    /// time we reach this method.
    private static func installWithAdminPrompt(pkg: URL, target: String) async throws {
        let quotedPath = pkg.path
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        let cmdline = "/usr/sbin/installer -pkg \"\(quotedPath)\" -target \(shellQuote(target))"
        let appleScript = "do shell script \"\(cmdline)\" with administrator privileges"

        let result = await runOsascript([
            "-e", appleScript,
        ])
        if result.exitCode == 0 { return }

        // osascript returns -128 when the user clicks Cancel on the
        // authorization dialog.
        if result.exitCode == -128
            || result.stderr.contains("(-128)")
            || result.stderr.lowercased().contains("user canceled") {
            throw Failure.adminDeclined
        }
        throw Failure.installerFailed(
            exitCode: result.exitCode,
            stderr: result.stderr.isEmpty ? result.stdout : result.stderr
        )
    }

    /// Shell-quote a string for embedding inside an AppleScript-
    /// driven `do shell script` command.  Conservative: wraps in
    /// single quotes after escaping any embedded single quotes.
    /// `target` is normally a fixed string ("/", "LocalSystem"),
    /// but quoting here keeps the call site uniform for future
    /// callers that might pass a custom value.
    private static func shellQuote(_ s: String) -> String {
        let escaped = s.replacingOccurrences(of: "'", with: "'\\''")
        return "'\(escaped)'"
    }

    /// Async wrapper around osascript.  Same shape as runInstaller
    /// — the admin path can take 5–60s if the user takes time on
    /// the auth dialog, so we yield to the runtime.
    static func runOsascript(_ args: [String]) async -> ProcessResult {
        await Task.detached { runOsascriptSync(args) }.value
    }

    /// Synchronous spawn of /usr/bin/osascript.  Hard-coded path —
    /// osascript is at the same well-known location on every
    /// macOS shipped since 10.0.
    static func runOsascriptSync(_ args: [String]) -> ProcessResult {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
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
                stderr: "Failed to launch osascript: \(error.localizedDescription)"
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
