import Foundation
import Security

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// HelperService is the privileged side of the SplynekHelperProtocol.
// Every method:
//   1. Validates the caller's Authorization right (defence-in-depth
//      beyond NSXPCConnection's SMAuthorizedClients check).
//   2. Validates the typed arguments — refuses anything outside the
//      documented set.
//   3. Spawns Apple-signed system tooling (/usr/sbin/installer)
//      with hard-coded arguments.
// The helper does NOT interpret arbitrary strings as code, does NOT
// load downloaded executables, and does NOT expose a generic
// shell-out interface.  Adding a new privileged operation requires
// adding a typed method to SplynekHelperProtocol + recompiling the
// helper bundle + a fresh SMAppService.register() prompt to the
// user.
// =====================================================================

/// v1.8.2: privileged installer + future-proof verb table.
/// Implements `SplynekHelperProtocol`; lives behind NSXPCConnection.
final class HelperService: NSObject, SplynekHelperProtocol {

    /// `app.splynek.Splynek.installPkg` — the Authorization right
    /// the app must hold before the helper will spawn installer(8).
    /// First-use registers the right via AuthorizationRightSet.
    private let installPkgRight = "app.splynek.Splynek.installPkg"

    // MARK: - SplynekHelperProtocol

    func installPkg(
        atPath path: String,
        target: String,
        authData: NSData,
        reply: @escaping (Int32, String?) -> Void
    ) {
        // 1. Validate the target is one of the documented installer(8)
        //    targets.  Refuse anything else.
        let allowedTargets: Set<String> = [
            "/", "LocalSystem", "CurrentUserHomeDirectory",
        ]
        guard allowedTargets.contains(target) else {
            reply(-1, "Refused target '\(target)' — must be one of \(allowedTargets.sorted()).")
            return
        }

        // 2. Validate the .pkg path exists + is a regular file.
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir),
              !isDir.boolValue
        else {
            reply(-1, "Package path doesn't exist or is a directory: \(path)")
            return
        }

        // 3. Verify the AuthorizationRef the app obtained is still
        //    valid + grants the installPkgRight.  The helper runs as
        //    root, but we still run this check so a buggy app can't
        //    silently escalate without the user's recent consent.
        let externalForm = authData.bytes.assumingMemoryBound(to: AuthorizationExternalForm.self)
        var authRef: AuthorizationRef?
        let importStatus = AuthorizationCreateFromExternalForm(externalForm, &authRef)
        guard importStatus == errAuthorizationSuccess, let authRef else {
            reply(-1, "Couldn't import authorization (\(importStatus)).")
            return
        }
        defer { AuthorizationFree(authRef, []) }

        var rightItem = installPkgRight.withCString { cstr in
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
            [.extendRights],
            nil
        )
        guard copyStatus == errAuthorizationSuccess else {
            reply(-1, "Authorization right denied (\(copyStatus)).")
            return
        }

        // 4. Spawn /usr/sbin/installer with hard-coded arguments.
        //    Helper runs as root via launchd; no further escalation.
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/sbin/installer")
        proc.arguments = ["-pkg", path, "-target", target]
        let outPipe = Pipe()
        let errPipe = Pipe()
        proc.standardOutput = outPipe
        proc.standardError = errPipe
        do {
            try proc.run()
            proc.waitUntilExit()
        } catch {
            reply(-1, "Failed to launch installer(8): \(error.localizedDescription)")
            return
        }
        let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
        let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
        let combined = (String(data: errData, encoding: .utf8) ?? "")
            + "\n"
            + (String(data: outData, encoding: .utf8) ?? "")
        reply(proc.terminationStatus, combined.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    func helperVersion(reply: @escaping (String) -> Void) {
        // Helper version mirrors the app's MARKETING_VERSION at build
        // time — set via Info.plist's CFBundleShortVersionString.
        let info = Bundle.main.infoDictionary ?? [:]
        let v = info["CFBundleShortVersionString"] as? String ?? "unknown"
        reply(v)
    }
}
