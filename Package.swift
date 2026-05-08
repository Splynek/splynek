// swift-tools-version:5.9
import PackageDescription

// Splynek ships as a single .app, but the code lives in a library target
// so the `splynek-test` executable can `@testable import SplynekCore`.
//
// We don't use XCTest / Swift Testing: Command Line Tools doesn't ship
// a working `swift test` runner without Xcode installed, and this
// project's invariant is "Xcode-optional." Tests live in a plain
// executable target and call a tiny assertion harness; `swift run
// splynek-test` builds + runs + exits non-zero on failure — the same
// contract any CI needs.
let package = Package(
    name: "Splynek",
    // v1.4: Sovereignty tab strings localised to FR/DE/ES/IT.  SPM
    // requires `defaultLocalization` whenever a target declares
    // localizable resources (the `.xcstrings` under SplynekCore).
    defaultLocalization: "en",
    platforms: [.macOS(.v13)],
    products: [
        // Library product — linked by the Xcode App target for MAS
        // distribution. Xcode requires an explicit library product
        // declaration; SPM alone auto-exports library targets but
        // Xcode's package integration doesn't.
        .library(name: "SplynekCore", targets: ["SplynekCore"]),
        // S4 iOS Companion (2026-05-07) — the shared core that the
        // iOS app + Share Extension both compile.  Built here as a
        // platform-portable library so `splynek-test` can exercise
        // PairedMacClient / PairedMacStore / ShareExtractor / Bonjour
        // TXT decoding from the same Mac toolchain that runs the
        // rest of the test suite.  iOS-only types (UIKit / SwiftUI
        // views) are NOT in this library — they live under
        // iOS/SplynekCompanion + iOS/SplynekShareExtension and are
        // compiled by the Xcode iOS targets only.
        .library(name: "SplynekCompanionCore", targets: ["SplynekCompanionCore"]),
    ],
    targets: [
        .target(
            name: "SplynekCore",
            // S4 phase 3 (2026-05-07): SplynekCore depends on
            // SplynekCompanionCore so CloudKitRelayReceiver can use
            // the same `CloudKitRelayRecord` type the iOS Companion's
            // Share Extension writes to CloudKit.  Single source of
            // truth for the schema across iOS + macOS.
            dependencies: ["SplynekCompanionCore"],
            path: "Sources/SplynekCore",
            resources: [
                .process("Localizable.xcstrings"),
                .process("Resources/cask-hints.json"),
            ]
        ),
        .target(
            name: "SplynekCompanionCore",
            path: "iOS/Shared"
        ),
        .executableTarget(
            name: "Splynek",
            dependencies: ["SplynekCore"],
            path: "Sources/Splynek"
        ),
        .executableTarget(
            name: "splynek-cli",
            dependencies: ["SplynekCore"],
            path: "Sources/splynek-cli"
        ),
        .executableTarget(
            name: "splynek-test",
            dependencies: ["SplynekCore", "SplynekCompanionCore"],
            path: "Tests/SplynekTests"
        ),
    ]
)
