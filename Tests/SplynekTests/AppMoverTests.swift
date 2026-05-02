import Foundation
@testable import SplynekCore

/// v1.8: AppMover invariants.  We can't actually install into
/// /Applications under test, so each test creates a temp tree as the
/// "destination directory" and a fake .app bundle as the source.
enum AppMoverTests {

    static func run() {
        TestHarness.suite("AppMover") {

            TestHarness.test("Successfully copies a fake .app into destination") {
                let env = makeEnv()
                defer { env.cleanup() }
                let result = try AppMover.install(
                    source: env.fakeApp,
                    destinationDirectory: env.dest
                )
                let installedExists = FileManager.default.fileExists(atPath: result.installedAt.path)
                try expect(installedExists, "Installed .app should exist at \(result.installedAt.path)")
                try expect(result.installedAt.lastPathComponent == "Foo.app")
            }

            TestHarness.test("Reads bundle ID + version from Info.plist") {
                let env = makeEnv()
                defer { env.cleanup() }
                let result = try AppMover.install(
                    source: env.fakeApp,
                    destinationDirectory: env.dest
                )
                try expect(result.bundleID == "test.foo")
                try expect(result.displayVersion == "1.2.3")
            }

            TestHarness.test("Suffix-renames when destination already exists") {
                let env = makeEnv()
                defer { env.cleanup() }
                _ = try AppMover.install(source: env.fakeApp, destinationDirectory: env.dest)
                let second = try AppMover.install(source: env.fakeApp, destinationDirectory: env.dest)
                try expect(
                    second.installedAt.lastPathComponent == "Foo 2.app",
                    "Got \(second.installedAt.lastPathComponent)"
                )
            }

            TestHarness.test("Throws .sourceNotFound for missing source") {
                let env = makeEnv()
                defer { env.cleanup() }
                let bogus = env.dir.appendingPathComponent("does-not-exist.app")
                var threw = false
                do {
                    _ = try AppMover.install(source: bogus, destinationDirectory: env.dest)
                } catch AppMover.Failure.sourceNotFound {
                    threw = true
                } catch {
                    try expect(false, "Wrong error type: \(error)")
                }
                try expect(threw, "Should have thrown sourceNotFound")
            }

            TestHarness.test("readBundleMetadata returns nils for non-bundle path") {
                let env = makeEnv()
                defer { env.cleanup() }
                let plain = env.dir.appendingPathComponent("plain.txt")
                try Data("hello".utf8).write(to: plain)
                let (bid, ver) = AppMover.readBundleMetadata(at: plain)
                try expect(bid == nil)
                try expect(ver == nil)
            }
        }
    }

    // MARK: - Fixture builder

    struct Env {
        let dir: URL
        let dest: URL
        let fakeApp: URL
        let cleanup: () -> Void
    }

    static func makeEnv() -> Env {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("splynek-appmover-\(UUID())")
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)

        let dest = root.appendingPathComponent("destination")
        try? fm.createDirectory(at: dest, withIntermediateDirectories: true)

        let app = root.appendingPathComponent("Foo.app")
        let contents = app.appendingPathComponent("Contents")
        try? fm.createDirectory(at: contents, withIntermediateDirectories: true)
        let plist: [String: Any] = [
            "CFBundleIdentifier": "test.foo",
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleName": "Foo",
        ]
        if let data = try? PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0) {
            try? data.write(to: contents.appendingPathComponent("Info.plist"))
        }

        return Env(
            dir: root,
            dest: dest,
            fakeApp: app,
            cleanup: { try? fm.removeItem(at: root) }
        )
    }
}
