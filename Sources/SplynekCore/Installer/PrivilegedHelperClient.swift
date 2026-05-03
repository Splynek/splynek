import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// PrivilegedHelperClient connects to a separately-signed
// `app.splynek.Splynek.helper` bundle via NSXPCConnection.  The
// connection is bounded by the SplynekHelperProtocol contract; only
// the methods declared in that protocol can be invoked.  The helper
// bundle's launchd plist + Authorization right requirements gate
// every privileged operation independently of the app — the app
// cannot escalate its own privilege via this client; only the
// helper can do privileged things, only the helper's installPkg
// method can run installer(8), and Authorization framework
// validates each call.
// =====================================================================

/// v1.8.2 (planned): app-side client for the SMJobBless / SMAppService
/// privileged helper bundle.
///
/// **Status: stub for v1.8.1.**  The osascript-elevated installer(8)
/// path in `PkgInstaller.installWithAdminPrompt` is the active admin-
/// domain mechanism today.  This stub:
///
///   1. Documents the v1.8.2 SMJobBless API surface.
///   2. Returns `.helperUnavailable` from every method so callers
///      can already integrate the fallback decision (try helper →
///      on failure, fall back to osascript).
///
/// When v1.8.2 ships, the helper bundle's actual XPC implementation
/// fills in the methods + this stub becomes the production client.
/// See `docs/SMJOB-BLESS-DESIGN.md` for the full design.
final class PrivilegedHelperClient: @unchecked Sendable {

    /// Singleton.  Exists from app launch even if the helper isn't
    /// installed; `version()` is the smoke test that detects
    /// helper presence.
    static let shared = PrivilegedHelperClient()

    private init() {}

    /// v1.8.2 (planned): typed result of helper operations.
    enum Result: Sendable, Equatable {
        case ok
        /// Helper bundle isn't installed yet (SMAppService.daemon not
        /// yet `register()`-ed for this app's run).  Caller should
        /// either prompt the user via `installHelperIfNeeded()` or
        /// fall back to the osascript path.
        case helperUnavailable
        /// User declined the SMAppService.register() authorization
        /// dialog.  Caller should surface "you cancelled the auth
        /// prompt" and let them retry.
        case authorizationDeclined
        /// Helper installed but XPC connection failed (helper crashed,
        /// connection invalidated, etc.).  Recovery: caller should
        /// `uninstall()` + `installHelperIfNeeded()` retry.
        case xpcConnectionFailed(String)
        /// Helper ran installer(8) but it returned non-zero.
        case installerFailed(exitCode: Int32, message: String)
    }

    /// v1.8.2 (planned): ensure the helper is installed via
    /// `SMAppService.daemon(plistName:).register()`.  First call
    /// surfaces the system-wide authorization dialog; subsequent
    /// calls are no-ops.
    func installHelperIfNeeded() async -> Result {
        // v1.8.1: stub returns .helperUnavailable so PkgInstaller's
        // requireAdmin path falls through to osascript.
        // v1.8.2 implementation:
        //
        //   guard #available(macOS 13, *) else {
        //       // Pre-13: SMJobBless flow (Apple-deprecated but works)
        //       return await installViaSMJobBless()
        //   }
        //   let svc = SMAppService.daemon(plistName: "app.splynek.Splynek.helper.plist")
        //   do { try svc.register(); return .ok }
        //   catch SMAppService.Status.requiresApproval {
        //       SMAppService.openSystemSettingsLoginItems()
        //       return .authorizationDeclined
        //   } catch { return .xpcConnectionFailed("\(error)") }
        return .helperUnavailable
    }

    /// v1.8.2 (planned): privileged install via the helper.  Connects
    /// to `SplynekHelperMachServiceName`, requests the
    /// `installPkg` operation with an Authorization ref the app has
    /// already validated.
    func installPkg(
        path: String,
        target: String
    ) async -> Result {
        // v1.8.1: stub.
        // v1.8.2 implementation:
        //
        //   let install = await installHelperIfNeeded()
        //   guard install == .ok else { return install }
        //   let conn = NSXPCConnection(machServiceName: SplynekHelperMachServiceName,
        //                              options: [.privileged])
        //   conn.remoteObjectInterface = NSXPCInterface(with: SplynekHelperProtocol.self)
        //   conn.resume()
        //   defer { conn.invalidate() }
        //   let helper = conn.remoteObjectProxyWithErrorHandler { … } as? SplynekHelperProtocol
        //   guard let helper else { return .xpcConnectionFailed("…") }
        //   let auth = try AuthorizationCopyRights(...)
        //   let authData = try AuthorizationCopyData(auth, …)
        //   return await withCheckedContinuation { cont in
        //       helper.installPkg(atPath: path, target: target, authData: authData) { code, msg in
        //           cont.resume(returning: code == 0 ? .ok
        //               : .installerFailed(exitCode: code, message: msg ?? ""))
        //       }
        //   }
        return .helperUnavailable
    }

    /// v1.8.2 (planned): cheap helper-version round-trip.  PkgInstaller
    /// uses this in v1.8.2 to decide between SMJobBless and osascript
    /// paths at the start of every admin-domain install.
    func version() async -> String? {
        // v1.8.1: always nil → caller falls through to osascript.
        return nil
    }
}
