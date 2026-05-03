import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// This file is the entry point of the Splynek privileged helper
// bundle (target: SplynekHelper, bundle ID:
// app.splynek.Splynek.helper).  It is shipped INSIDE Splynek.app/
// Contents/Library/LaunchServices/ and registered with launchd via
// SMAppService.daemon.register() at first install need.
//
// What this binary can do:
//   * Listen on a single Mach service (`SplynekHelperMachServiceName`)
//   * Accept connections only from clients matching the
//     SMAuthorizedClients string in Info.plist (the app's signing
//     requirement, anchored to the Apple Developer Team ID
//     58C6YC5GB5)
//   * Serve the methods declared in SplynekHelperProtocol
//
// What this binary CANNOT do:
//   * Run arbitrary code passed by the client — every method on the
//     protocol takes typed arguments only
//   * Be invoked by anything other than a properly-signed Splynek.app
//     (NSXPCConnection enforces SMAuthorizedClients)
//   * Persist state across launches (helper is stateless; launchd
//     re-spawns on demand, exits when idle)
//
// =====================================================================

// SwiftPM doesn't compile this target — see project.yml's
// `SplynekHelper` target for the XcodeGen wiring.  The file lives in
// the source tree so reviewers + future maintainers can find it; the
// daemon binary is built only when the maintainer runs xcodegen +
// xcodebuild against the SplynekHelper scheme.

// Bring up the listener.  `SplynekHelperMachServiceName` is shared
// with the app via `Sources/SplynekCore/SplynekHelperProtocol.swift`.
let listener = NSXPCListener(machServiceName: SplynekHelperMachServiceName)

// Wire the service-delegate that accepts new connections + exports
// the protocol.
let delegate = HelperListenerDelegate()
listener.delegate = delegate

// `resume()` blocks for the lifetime of the daemon; launchd
// auto-terminates the process when the connection is idle.
listener.resume()
RunLoop.main.run()
