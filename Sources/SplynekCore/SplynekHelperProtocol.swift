import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// SplynekHelperProtocol declares the XPC interface between the
// Splynek app and its privileged helper bundle.  Every method takes
// typed arguments (no Data blobs, no closures, no untyped dictionaries)
// so the privileged side can validate every call.  Nothing in this
// protocol grants ad-hoc code execution; the only privileged
// operation is `installPkg`, which spawns Apple's signed
// /usr/sbin/installer with hard-coded arguments.
//
// **This file is currently UNREACHED by the SwiftPM build.**  The
// helper bundle is an XcodeGen-defined target (see project.yml +
// docs/SMJOB-BLESS-DESIGN.md) that ships in v1.8.2.  The protocol
// + skeleton live in main now so the app-side wiring can compile-
// against the same declarations the helper-side will use, and so
// reviewers can see the v1.8.2 architecture without spelunking.
// =====================================================================

/// v1.8.2 (planned): XPC protocol exposed by the privileged helper
/// bundle.  See `docs/SMJOB-BLESS-DESIGN.md` for the full design
/// + step-by-step implementation plan.
///
/// **Status: declaration only.**  v1.8.1 ships an osascript-elevated
/// installer(8) path inside `Sources/SplynekCore/Installer/PkgInstaller
/// .swift`.  The SMJobBless path lights up when the helper bundle
/// target is added to `project.yml` (XcodeGen-only — SwiftPM doesn't
/// support helper-bundle compilation).
///
/// Why declared in the public repo today:
///   - The app-side `PrivilegedHelperClient` (also in this commit)
///     uses this protocol to type its NSXPCConnection.  Compiling
///     the client requires the protocol to exist.
///   - Reviewers reading the codebase see the v1.8.2 architecture
///     without having to hunt through XcodeGen's generated project.
///   - When v1.8.2 actually ships, the helper bundle's
///     SplynekHelperService implements this protocol verbatim.
@objc public protocol SplynekHelperProtocol {

    /// Privileged installer(8) spawn.  Helper runs as root via
    /// launchd; this method is the ONLY privileged operation the
    /// app can request.
    ///
    /// - Parameters:
    ///   - path: absolute path to a .pkg file the user picked +
    ///     the v1.8 InstallerEngine SHA-256 + Gatekeeper verified.
    ///   - target: installer(8) `-target` value ("/", "LocalSystem",
    ///     "CurrentUserHomeDirectory").  Helper validates this is
    ///     one of the documented installer(8) targets — refuses
    ///     anything else.
    ///   - authData: AuthorizationCopyData() of an authorization
    ///     ref the app obtained via AuthorizationCopyRights for
    ///     the right `app.splynek.Splynek.installPkg`.  Helper
    ///     re-validates via AuthorizationCopyRights(...,
    ///     .kAuthorizationFlagExtendRights) before spawning.
    ///   - reply: (exitCode, errorMessage)
    func installPkg(
        atPath path: String,
        target: String,
        authData: NSData,
        reply: @escaping (Int32, String?) -> Void
    )

    /// Smoke-test endpoint.  App calls this on first connect to
    /// confirm helper version compatibility before sending real
    /// install requests.  No privilege required; helper spawns no
    /// processes for this.
    func helperVersion(
        reply: @escaping (String) -> Void
    )

    /// Future-proof: the helper protocol stays stable across v1.8.x
    /// even as we add privileged operations.  v1.8.2 implements
    /// only `installPkg`; future ops (kext-load, /Library/LaunchDaemons
    /// rotate, …) get their own typed methods here.
}

/// v1.8.2: the Mach-service name the helper publishes via
/// NSXPCListener + the app uses to connect via NSXPCConnection.
/// Must match the `MachServices` key in the helper's launchd plist.
public let SplynekHelperMachServiceName = "app.splynek.Splynek.helper"
