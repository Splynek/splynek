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
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "SplynekCore",
            path: "Sources/SplynekCore"
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
            dependencies: ["SplynekCore"],
            path: "Tests/SplynekTests"
        ),
    ]
)
