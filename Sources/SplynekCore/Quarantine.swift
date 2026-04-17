import Foundation
import Darwin

/// Apply macOS Launch Services' `com.apple.quarantine` extended attribute to
/// a newly-downloaded file.
///
/// Safari, Chrome, curl-with-LaunchServices-integration, etc. all set this
/// xattr on downloaded content so that Gatekeeper / XProtect will evaluate
/// an executable the first time the user tries to open it. Without this,
/// downloaded `.app` / `.pkg` / `.dmg` files silently bypass Gatekeeper.
///
/// Format (from Apple's Launch Services QIT):
///   `<flags>;<hex unix timestamp>;<agent name>;<uuid>`
/// where flags are a 4-hex-digit bitfield; `0081` means "downloaded" with
/// "Gatekeeper check required on first open".
enum Quarantine {

    static func mark(_ url: URL, agent: String = "Splynek") {
        let uuid = UUID().uuidString
        let ts = String(Int(Date().timeIntervalSince1970), radix: 16)
        let safeAgent = agent.replacingOccurrences(of: ";", with: "_")
        let value = "0081;\(ts);\(safeAgent);\(uuid)"

        url.withUnsafeFileSystemRepresentation { pathPtr in
            guard let pathPtr else { return }
            value.withCString { vPtr in
                _ = setxattr(pathPtr, "com.apple.quarantine", vPtr, strlen(vPtr), 0, 0)
            }
        }
    }
}
