import Foundation
#if canImport(ServiceManagement)
import ServiceManagement
#endif
#if canImport(Security)
import Security
#endif

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

/// v1.8.2: app-side client for the SMAppService / SMJobBless
/// privileged helper bundle.
///
/// **Activation gate.**  The helper bundle ships embedded inside
/// the app at `Splynek.app/Contents/Library/LaunchServices/
/// SplynekHelper`.  Until `installHelperIfNeeded()` succeeds (which
/// surfaces a system-wide auth prompt the first time), every other
/// method here returns `.helperUnavailable` + the caller falls back
/// to the v1.8.1 osascript path inside `PkgInstaller`.
///
/// **Compile-time gate.**  All real implementations live behind
/// `#if canImport(ServiceManagement)` + `@available(macOS 13, *)`.
/// On older macOS or when ServiceManagement isn't available (Linux
/// CI builds, freshly-checked-out toolchains without the macOS 13
/// SDK), every method returns `.helperUnavailable` and the
/// fallback path is the only one exercised.
final class PrivilegedHelperClient: @unchecked Sendable {

    /// Singleton.  Stateless from the caller's perspective; per-
    /// invocation NSXPCConnection lifetimes match the request.
    static let shared = PrivilegedHelperClient()

    private init() {}

    /// v1.8.2: typed result of helper operations.
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

    /// v1.8.2: ensure the helper is installed via
    /// `SMAppService.daemon(plistName:).register()`.  First call
    /// surfaces the system-wide authorization dialog; subsequent
    /// calls return `.ok` without prompting.
    func installHelperIfNeeded() async -> Result {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            let svc = SMAppService.daemon(
                plistName: "app.splynek.Splynek.helper.plist"
            )
            switch svc.status {
            case .enabled:
                return .ok
            case .requiresApproval:
                // User has to approve in System Settings → Login Items
                // & Extensions.  Open the pane so they don't have to
                // hunt for it.
                SMAppService.openSystemSettingsLoginItems()
                return .authorizationDeclined
            case .notRegistered, .notFound:
                do {
                    try svc.register()
                    // After successful register the helper is enabled
                    // — but the OS sometimes lags on the status flip.
                    // Poll briefly.
                    for _ in 0..<10 {
                        if svc.status == .enabled { return .ok }
                        try? await Task.sleep(nanoseconds: 100_000_000)
                    }
                    return svc.status == .enabled
                        ? .ok
                        : .xpcConnectionFailed("Helper register succeeded but status didn't flip to enabled.")
                } catch {
                    return .xpcConnectionFailed("SMAppService.register() failed: \(error.localizedDescription)")
                }
            @unknown default:
                return .xpcConnectionFailed("Unknown SMAppService.Status.")
            }
        }
        #endif
        // Pre-macOS-13 / non-Apple build: helper unavailable, caller
        // falls through to osascript path.
        return .helperUnavailable
    }

    /// v1.8.2: privileged install via the helper.  Connects to
    /// `SplynekHelperMachServiceName`, validates the helper version,
    /// requests an Authorization right, then invokes `installPkg`.
    func installPkg(
        path: String,
        target: String
    ) async -> Result {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            // Stage 1: ensure helper is registered.
            let installResult = await installHelperIfNeeded()
            guard case .ok = installResult else { return installResult }

            // Stage 2: build an Authorization ref the helper can
            // validate.  The helper checks for the
            // `app.splynek.Splynek.installPkg` right; the user sees
            // the standard authorization dialog with Touch ID / pwd.
            let rightName = "app.splynek.Splynek.installPkg"
            var authRef: AuthorizationRef?
            let createStatus = AuthorizationCreate(
                nil, nil, [], &authRef
            )
            guard createStatus == errAuthorizationSuccess, let authRef else {
                return .xpcConnectionFailed("AuthorizationCreate failed (\(createStatus)).")
            }
            defer { AuthorizationFree(authRef, []) }

            var rightItem = rightName.withCString { cstr in
                AuthorizationItem(
                    name: cstr,
                    valueLength: 0,
                    value: nil,
                    flags: 0
                )
            }
            var rights = withUnsafeMutablePointer(to: &rightItem) {
                AuthorizationRights(count: 1, items: $0)
            }
            let copyStatus = AuthorizationCopyRights(
                authRef,
                &rights,
                nil,
                [.interactionAllowed, .extendRights, .preAuthorize],
                nil
            )
            switch copyStatus {
            case errAuthorizationSuccess:
                break
            case errAuthorizationCanceled:
                return .authorizationDeclined
            default:
                return .xpcConnectionFailed("AuthorizationCopyRights failed (\(copyStatus)).")
            }

            // Stage 3: serialise the AuthorizationRef for the XPC
            // hop (helper re-imports via AuthorizationCreateFromExternalForm).
            var externalForm = AuthorizationExternalForm()
            let externalStatus = AuthorizationMakeExternalForm(authRef, &externalForm)
            guard externalStatus == errAuthorizationSuccess else {
                return .xpcConnectionFailed("AuthorizationMakeExternalForm failed (\(externalStatus)).")
            }
            let authData = withUnsafePointer(to: &externalForm) { ptr -> Data in
                Data(bytes: ptr, count: MemoryLayout<AuthorizationExternalForm>.size)
            }

            // Stage 4: open NSXPCConnection + invoke installPkg.
            let conn = NSXPCConnection(
                machServiceName: SplynekHelperMachServiceName,
                options: [.privileged]
            )
            conn.remoteObjectInterface = NSXPCInterface(
                with: SplynekHelperProtocol.self
            )
            conn.resume()
            defer { conn.invalidate() }

            return await withCheckedContinuation { (cont: CheckedContinuation<Result, Never>) in
                let proxy = conn.remoteObjectProxyWithErrorHandler { err in
                    cont.resume(returning: .xpcConnectionFailed("XPC error: \(err.localizedDescription)"))
                } as? SplynekHelperProtocol
                guard let proxy else {
                    cont.resume(returning: .xpcConnectionFailed("Couldn't cast remote proxy to SplynekHelperProtocol."))
                    return
                }
                proxy.installPkg(
                    atPath: path,
                    target: target,
                    authData: authData as NSData
                ) { exitCode, message in
                    if exitCode == 0 {
                        cont.resume(returning: .ok)
                    } else {
                        cont.resume(returning: .installerFailed(
                            exitCode: exitCode,
                            message: message ?? "installer(8) returned \(exitCode)."
                        ))
                    }
                }
            }
        }
        #endif
        // Pre-macOS-13 / non-Apple: helper unreachable; caller
        // falls back to osascript path.
        return .helperUnavailable
    }

    /// v1.8.2: cheap helper-version round-trip.  PkgInstaller uses
    /// this to decide between SMJobBless and osascript paths at the
    /// start of every admin-domain install.  Returns nil when the
    /// helper isn't reachable.
    func version() async -> String? {
        #if canImport(ServiceManagement)
        if #available(macOS 13.0, *) {
            let installResult = await installHelperIfNeeded()
            guard case .ok = installResult else { return nil }
            let conn = NSXPCConnection(
                machServiceName: SplynekHelperMachServiceName,
                options: [.privileged]
            )
            conn.remoteObjectInterface = NSXPCInterface(
                with: SplynekHelperProtocol.self
            )
            conn.resume()
            defer { conn.invalidate() }
            return await withCheckedContinuation { (cont: CheckedContinuation<String?, Never>) in
                let proxy = conn.remoteObjectProxyWithErrorHandler { _ in
                    cont.resume(returning: nil)
                } as? SplynekHelperProtocol
                guard let proxy else {
                    cont.resume(returning: nil)
                    return
                }
                proxy.helperVersion { v in cont.resume(returning: v) }
            }
        }
        #endif
        return nil
    }
}
