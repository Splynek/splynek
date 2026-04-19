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

SplynekBootstrap.run()
