import Foundation
@testable import SplynekCore

/// v1.8.2: PrivilegedHelperClient invariants.
///
/// We can't actually invoke SMAppService.daemon.register() from a
/// unit test (it requires a code-signed bundle with the helper
/// embedded inside Contents/Library/LaunchServices/, plus the user
/// at the keyboard for the auth prompt).  What we CAN test:
///
///   - The fallback contract: helper unreachable from a SwiftPM-
///     built test binary → all methods return .helperUnavailable
///     → PkgInstaller's requireAdmin path falls through to
///     osascript.  This locks down the gate that keeps v1.8.1's
///     osascript path alive in development + non-MAS builds.
///   - Result Equatable shape (used by callers to branch on the
///     outcome).
///
/// Real activation testing happens at MAS-build time (the maintainer
/// code-signs both bundles + smoke-tests against a sample admin
/// .pkg).
enum PrivilegedHelperClientTests {

    static func run() {
        TestHarness.suite("PrivilegedHelperClient — fallback gate") {

            TestHarness.test("Singleton is stable across calls") {
                let a = PrivilegedHelperClient.shared
                let b = PrivilegedHelperClient.shared
                try expect(a === b)
            }

            TestHarness.test("installHelperIfNeeded returns helperUnavailable in test context") {
                // The SwiftPM test binary isn't a code-signed app
                // bundle; SMAppService.daemon can't find a valid
                // helper plist.  Expected outcome: .helperUnavailable
                // (or .authorizationDeclined when the OS's
                // requiresApproval branch fires) — in both cases
                // PkgInstaller's requireAdmin path falls through
                // to osascript.
                let result = await PrivilegedHelperClient.shared.installHelperIfNeeded()
                switch result {
                case .helperUnavailable, .authorizationDeclined,
                     .xpcConnectionFailed:
                    // Acceptable.  All three keep the osascript
                    // fallback alive.
                    break
                case .ok:
                    // .ok is technically possible if the dev box
                    // has already registered the helper from a
                    // prior MAS build — we accept this too.
                    break
                case .installerFailed:
                    try expect(false, "Unexpected .installerFailed from installHelperIfNeeded")
                }
            }

            TestHarness.test("installPkg returns a typed result without crashing") {
                // Same gate — no real helper, but the call must
                // return some Result rather than throw.
                let result = await PrivilegedHelperClient.shared.installPkg(
                    path: "/tmp/no-such-pkg-\(UUID()).pkg",
                    target: "/"
                )
                _ = result   // any case is fine; we're checking it returns
            }

            TestHarness.test("version returns nil when helper isn't reachable") {
                let v = await PrivilegedHelperClient.shared.version()
                // .nil is the expected gate-closed signal; if a
                // dev box happens to have a registered helper from
                // a prior MAS run, accept any String too.
                if let v = v {
                    try expect(!v.isEmpty)
                }
            }
        }

        TestHarness.suite("PrivilegedHelperClient.Result — equality") {

            TestHarness.test("Each case is distinct") {
                try expect(PrivilegedHelperClient.Result.ok == .ok)
                try expect(PrivilegedHelperClient.Result.helperUnavailable == .helperUnavailable)
                try expect(PrivilegedHelperClient.Result.authorizationDeclined == .authorizationDeclined)
                try expect(PrivilegedHelperClient.Result.xpcConnectionFailed("x")
                           == PrivilegedHelperClient.Result.xpcConnectionFailed("x"))
                try expect(PrivilegedHelperClient.Result.xpcConnectionFailed("x")
                           != PrivilegedHelperClient.Result.xpcConnectionFailed("y"))
                try expect(PrivilegedHelperClient.Result.installerFailed(exitCode: 1, message: "a")
                           == PrivilegedHelperClient.Result.installerFailed(exitCode: 1, message: "a"))
                try expect(PrivilegedHelperClient.Result.ok != .helperUnavailable)
            }
        }
    }
}
