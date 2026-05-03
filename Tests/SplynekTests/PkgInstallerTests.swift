import Foundation
@testable import SplynekCore

/// v1.8.1: PkgInstaller invariants.  Tests cover the cases that DON'T
/// require an actual .pkg file or osascript prompt — input
/// validation, target-domain gating, error-shape contracts.  The
/// admin-prompt path itself isn't unit-testable (would surface a
/// real authorization dialog); it's exercised at runtime via the
/// InstallView "Install" button against a sample admin .pkg.
enum PkgInstallerTests {

    static func run() {
        TestHarness.suite("PkgInstaller — input validation") {

            TestHarness.test("Missing .pkg surfaces ioError") {
                let bogus = URL(fileURLWithPath: "/tmp/definitely-not-a-pkg-\(UUID()).pkg")
                var threw = false
                do {
                    try await PkgInstaller.install(pkg: bogus)
                } catch PkgInstaller.Failure.ioError {
                    threw = true
                } catch {
                    try expect(false, "Wrong error: \(error)")
                }
                try expect(threw, "Should have thrown ioError")
            }

            TestHarness.test("Non-user target without requireAdmin throws requiresAdmin") {
                let env = makeTempPkg()
                defer { env.cleanup() }
                var threw = false
                do {
                    try await PkgInstaller.install(
                        pkg: env.pkg,
                        target: "/",
                        requireAdmin: false
                    )
                } catch PkgInstaller.Failure.requiresAdmin {
                    threw = true
                } catch {
                    // installerFailed is also acceptable — the .pkg
                    // is empty so installer(8) may exit before
                    // hitting the target check.  But we expect the
                    // target-domain rejection FIRST.
                    try expect(false, "Wrong error type: \(error)")
                }
                try expect(threw, "Should have thrown requiresAdmin")
            }

            TestHarness.test("LocalSystem target without requireAdmin throws requiresAdmin") {
                let env = makeTempPkg()
                defer { env.cleanup() }
                var threw = false
                do {
                    try await PkgInstaller.install(
                        pkg: env.pkg,
                        target: "LocalSystem",
                        requireAdmin: false
                    )
                } catch PkgInstaller.Failure.requiresAdmin {
                    threw = true
                } catch {
                    try expect(false, "Wrong error type: \(error)")
                }
                try expect(threw)
            }
        }

        TestHarness.suite("PkgInstaller.Failure — error descriptions") {

            TestHarness.test("requiresAdmin description mentions opting in") {
                let f = PkgInstaller.Failure.requiresAdmin(stderr: "must be run as root")
                let msg = f.errorDescription ?? ""
                try expect(msg.contains("requireAdmin"),
                           "errorDescription should guide user toward requireAdmin: true; got: \(msg)")
            }

            TestHarness.test("adminDeclined description mentions cancel") {
                let f = PkgInstaller.Failure.adminDeclined
                let msg = f.errorDescription ?? ""
                try expect(msg.lowercased().contains("declined") || msg.lowercased().contains("cancel"),
                           "errorDescription should mention cancel/declined; got: \(msg)")
            }

            TestHarness.test("installerFailed surfaces exit code + stderr") {
                let f = PkgInstaller.Failure.installerFailed(exitCode: 42, stderr: "boom")
                let msg = f.errorDescription ?? ""
                try expect(msg.contains("42"), "Should mention code 42; got: \(msg)")
                try expect(msg.contains("boom"), "Should mention stderr; got: \(msg)")
            }
        }
    }

    // MARK: - Fixtures

    struct Env {
        let pkg: URL
        let cleanup: () -> Void
    }

    /// Creates a near-empty file with a .pkg extension so PkgInstaller's
    /// existence check passes.  installer(8) will then refuse it as
    /// malformed — but the path under test (target-domain rejection)
    /// runs BEFORE installer(8) is spawned.
    static func makeTempPkg() -> Env {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID()).pkg")
        try? Data("not-a-real-pkg".utf8).write(to: url)
        return Env(pkg: url, cleanup: { try? FileManager.default.removeItem(at: url) })
    }
}
