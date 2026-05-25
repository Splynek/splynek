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
import Foundation

#if canImport(SplynekCore)
import SplynekCore
#endif

// 2026-06 direct-sale launch: instantiate the Sparkle singleton
// BEFORE SwiftUI's App.main() takes over.  The SPUStandardUpdaterController
// constructor runs the auto-check timer immediately, so referencing
// the singleton here kicks it off.  See Sources/Splynek/SparkleBridge.swift
// for the bridge + the maintainer prerequisites (SUFeedURL + SUPublicEDKey
// in Resources/Info.plist).
_ = SparkleBridge.shared

// "Check for Updates…" menu command lives in SplynekCore's
// CommandGroup (it's a SwiftUI .commands entry, under About).  But
// SplynekCore intentionally doesn't import Sparkle (keeps the test
// target lean), so the command posts a `.splynekCheckForUpdates`
// notification + we observe it here and bridge to SparkleBridge.
//
// The observer is owned by `_ = NotificationCenter.default.addObserver…`
// — Sparkle's lifetime is the process's, so a leaked-on-exit
// observer is fine.  The closure runs on the main queue because
// SPUStandardUpdaterController.checkForUpdates(_:) requires it.
_ = NotificationCenter.default.addObserver(
    forName: .splynekCheckForUpdates, object: nil, queue: .main
) { _ in
    Task { @MainActor in
        SparkleBridge.shared.checkForUpdates()
    }
}

SplynekBootstrap.run()
