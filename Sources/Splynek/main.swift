// Splynek's executable target is a three-line shim. All of the code
// lives in the SplynekCore library target so the XCTest target can
// @testable import it; this file exists only because SPM needs a
// reachable `main` to produce a `.app`-shaped binary.
//
// `canImport` guard: under SPM, SplynekCore is a separate module and
// must be imported. Under the Xcode project (Splynek.xcodeproj), both
// Sources/Splynek and Sources/SplynekCore compile into a single app
// module — SplynekCore-the-module doesn't exist, and `canImport`
// returns false so the directive is skipped. One main.swift, two
// build systems.
#if canImport(SplynekCore)
import SplynekCore
#endif

// 2026-06 direct-sale launch: instantiate the Sparkle singleton
// BEFORE SwiftUI's App.main() takes over.  The SPUStandardUpdaterController
// constructor runs the auto-check timer immediately, so referencing
// the singleton here kicks it off.  See Sources/Splynek/SparkleBridge.swift
// for the bridge + the maintainer prerequisites (SUFeedURL + SUPublicEDKey
// in Resources/Info.plist).
//
// A "Check for Updates…" menu item lives in SparkleBridge but is
// surfaced via NSMenu hooks rather than SwiftUI .commands — the
// SwiftUI .commands wiring lives in SplynekCore which intentionally
// doesn't import Sparkle (to keep the test target lean).  v1.0 ships
// with the auto-prompt timer only; manual "Check for Updates…"
// surfaces in v1.0.1 via the menu-bar bridge.
_ = SparkleBridge.shared

SplynekBootstrap.run()
