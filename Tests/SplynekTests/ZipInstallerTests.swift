import Foundation
@testable import SplynekCore

/// v1.8.1: ZipInstaller invariants.  Each test builds a small fake
/// .app bundle, zips it via /usr/bin/ditto, then drives ZipInstaller
/// against the resulting archive.  All work is in /tmp, so the
/// tests are sandbox-friendly and don't touch /Applications.
enum ZipInstallerTests {

    static func run() {
        TestHarness.suite("ZipInstaller") {

            TestHarness.test("Extract + install round-trip succeeds") {
                let env = makeEnv()
                defer { env.cleanup() }

                let archive = try makeArchive(
                    appName: "Foo.app",
                    bundleID: "test.foo",
                    version: "1.0.0",
                    in: env.workdir
                )

                let outcome = try await ZipInstaller.install(
                    archive: archive,
                    destinationDirectory: env.dest
                )

                let exists = FileManager.default.fileExists(atPath: outcome.installedAt.path)
                try expect(exists, "Installed app should exist at \(outcome.installedAt.path)")
                try expect(outcome.installedAt.lastPathComponent == "Foo.app")
                try expect(outcome.bundleID == "test.foo")
                try expect(outcome.displayVersion == "1.0.0")
            }

            TestHarness.test("Archive without .app throws noAppFound") {
                let env = makeEnv()
                defer { env.cleanup() }

                // Create a zip containing a plain text file but no .app.
                let payload = env.workdir.appendingPathComponent("payload.txt")
                try Data("hello".utf8).write(to: payload)

                let archive = env.workdir.appendingPathComponent("archive.zip")
                let r = ZipInstaller.runDittoSync([
                    "-c", "-k", payload.path, archive.path
                ])
                try expect(r.exitCode == 0, "ditto compress failed")

                var threw = false
                do {
                    _ = try await ZipInstaller.install(
                        archive: archive,
                        destinationDirectory: env.dest
                    )
                } catch ZipInstaller.Failure.noAppFound {
                    threw = true
                } catch {
                    try expect(false, "Wrong error type: \(error)")
                }
                try expect(threw, "Should have thrown noAppFound")
            }

            TestHarness.test("Staging directory is cleaned up after install") {
                let env = makeEnv()
                defer { env.cleanup() }

                let archive = try makeArchive(
                    appName: "Bar.app",
                    bundleID: "test.bar",
                    version: "0.1",
                    in: env.workdir
                )
                _ = try await ZipInstaller.install(
                    archive: archive,
                    destinationDirectory: env.dest
                )

                // No splynek-install-zip-* directory should remain in /tmp.
                let tmp = FileManager.default.temporaryDirectory
                if let entries = try? FileManager.default.contentsOfDirectory(
                    atPath: tmp.path
                ) {
                    let leaks = entries.filter { $0.hasPrefix("splynek-install-zip-") }
                    try expect(
                        leaks.isEmpty,
                        "Staging dirs leaked into /tmp: \(leaks)"
                    )
                }
            }

            TestHarness.test("Missing archive surfaces extractFailed") {
                let env = makeEnv()
                defer { env.cleanup() }

                let bogus = env.workdir.appendingPathComponent("does-not-exist.zip")
                var threw = false
                do {
                    _ = try await ZipInstaller.install(
                        archive: bogus,
                        destinationDirectory: env.dest
                    )
                } catch ZipInstaller.Failure.extractFailed {
                    threw = true
                } catch {
                    try expect(false, "Wrong error type: \(error)")
                }
                try expect(threw, "Should have thrown extractFailed")
            }
        }
    }

    // MARK: - Fixture builder

    struct Env {
        let workdir: URL
        let dest: URL
        let cleanup: () -> Void
    }

    static func makeEnv() -> Env {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("splynek-zipinstaller-\(UUID())")
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        let dest = root.appendingPathComponent("destination")
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)
        return Env(
            workdir: root,
            dest: dest,
            cleanup: { try? fm.removeItem(at: root) }
        )
    }

    /// Build a minimal .app bundle on disk and zip it via ditto.
    /// Mirrors AppMoverTests' fixture.
    static func makeArchive(
        appName: String,
        bundleID: String,
        version: String,
        in workdir: URL
    ) throws -> URL {
        let fm = FileManager.default
        let app = workdir.appendingPathComponent(appName)
        let contents = app.appendingPathComponent("Contents")
        try fm.createDirectory(at: contents, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": bundleID,
            "CFBundleShortVersionString": version,
            "CFBundleName": (appName as NSString).deletingPathExtension,
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))

        let archive = workdir.appendingPathComponent("\(appName).zip")
        let result = ZipInstaller.runDittoSync([
            "-c", "-k", "--keepParent", app.path, archive.path
        ])
        try expect(result.exitCode == 0, "ditto compress failed: \(result.stderr)")
        return archive
    }
}
