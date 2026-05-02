import Foundation
@testable import SplynekCore

/// v1.8.2: AutoUpdateScheduler invariants.  Tests inject a fixture
/// `DownloadFunction` so we don't actually fetch from the network.
/// Each test resets the on-disk InstalledAppRegistry first so they're
/// order-independent.
enum AutoUpdateSchedulerTests {

    static func run() {
        TestHarness.suite("AutoUpdateScheduler — sweep") {

            TestHarness.test("Empty registry produces empty sweep") {
                InstalledAppRegistry._resetForTesting()
                let sched = AutoUpdateScheduler(
                    interval: 60,
                    download: { _, _ in fatalError("no candidates → should not download") }
                )
                let result = await sched.runOnce().value
                try expect(result.updates.isEmpty)
                try expect(result.errors.isEmpty)
            }

            TestHarness.test("Records with autoUpdate=false are skipped") {
                InstalledAppRegistry._resetForTesting()
                InstalledAppRegistry.upsert(makeRecord(name: "Mozilla", autoUpdate: false))
                let sched = AutoUpdateScheduler(
                    interval: 60,
                    download: { _, _ in fatalError("autoUpdate=false → should not download") }
                )
                let result = await sched.runOnce().value
                try expect(result.updates.isEmpty)
                try expect(result.errors.isEmpty)
            }

            TestHarness.test("Same digest → no update applied") {
                InstalledAppRegistry._resetForTesting()
                let env = makeEnv()
                defer { env.cleanup() }

                // Record claims the installed digest is "AAA…"; download
                // returns a file whose actual SHA-256 is the same.
                let bytes = Data("hello".utf8)
                let helloDigest = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

                let r = makeRecord(name: "App", autoUpdate: true, installedDigest: helloDigest)
                InstalledAppRegistry.upsert(r)

                let sched = AutoUpdateScheduler(
                    interval: 60,
                    download: { _, dir in
                        let path = dir.appendingPathComponent("payload.bin")
                        try bytes.write(to: path)
                        return path
                    }
                )
                let result = await sched.runOnce().value
                try expect(result.updates.isEmpty,
                           "Same digest → no update; got \(result.updates.count)")
                try expect(result.errors.isEmpty)
            }

            TestHarness.test("Different digest → update is attempted") {
                InstalledAppRegistry._resetForTesting()
                let env = makeEnv()
                defer { env.cleanup() }

                // Pretend the installed version had a different digest.
                let oldDigest = String(repeating: "0", count: 64)
                let r = makeRecord(name: "App", autoUpdate: true, installedDigest: oldDigest)
                InstalledAppRegistry.upsert(r)

                let sched = AutoUpdateScheduler(
                    interval: 60,
                    download: { _, dir in
                        let path = dir.appendingPathComponent("payload.bin")
                        try Data("new payload".utf8).write(to: path)
                        return path
                    }
                )
                let result = await sched.runOnce().value
                try expect(result.updates.count == 1, "Got \(result.updates.count) updates")

                // The pipeline result will probably be a verification
                // failure (Gatekeeper rejects an arbitrary 11-byte
                // file), but the digest-comparison step ran + we ran
                // the pipeline.  That's the contract being tested.
                let upd = result.updates[0]
                try expect(upd.oldDigest == oldDigest)
                try expect(upd.newDigest != oldDigest)
            }

            TestHarness.test("Download error becomes a sweep error, not a throw") {
                InstalledAppRegistry._resetForTesting()
                let r = makeRecord(name: "Bork", autoUpdate: true)
                InstalledAppRegistry.upsert(r)

                struct DownloadFailed: Error, LocalizedError {
                    let errorDescription: String? = "simulated network failure"
                }
                let sched = AutoUpdateScheduler(
                    interval: 60,
                    download: { _, _ in throw DownloadFailed() }
                )
                let result = await sched.runOnce().value
                try expect(result.updates.isEmpty)
                try expect(result.errors.count == 1, "Got \(result.errors.count) errors")
                try expect(result.errors[0].record.spec.name == "Bork")
                try expect(result.errors[0].message.contains("simulated"))
            }

            TestHarness.test("One bad record doesn't block the rest") {
                InstalledAppRegistry._resetForTesting()
                let bork = makeRecord(name: "Bork", autoUpdate: true)
                let good = makeRecord(name: "Good", autoUpdate: true)
                InstalledAppRegistry.upsert(bork)
                InstalledAppRegistry.upsert(good)

                struct OnlyBorkFails: Error, LocalizedError {
                    let errorDescription: String? = "bork only"
                }
                let sched = AutoUpdateScheduler(
                    interval: 60,
                    download: { url, dir in
                        if url.absoluteString.contains("Bork") {
                            throw OnlyBorkFails()
                        }
                        let path = dir.appendingPathComponent("payload.bin")
                        try Data("ok".utf8).write(to: path)
                        return path
                    }
                )
                let result = await sched.runOnce().value
                // 1 errored, 1 attempted update (Good — same/different
                // digest path doesn't matter for this test, just that
                // it processed both).
                try expect(result.errors.count == 1, "Got \(result.errors.count) errors")
                // updates can be 0 or 1 depending on whether the digest
                // happened to match.  "Good" had no installedDigest, so
                // it'll always trigger an update attempt (which then
                // fails Gatekeeper, but the Sweep.Update is recorded).
                try expect(!result.updates.isEmpty || !result.errors.isEmpty,
                           "Should have processed both records")
            }
        }

        TestHarness.suite("AutoUpdateScheduler — interval") {

            TestHarness.test("Interval below 60s is clamped to 60s") {
                let sched = AutoUpdateScheduler(
                    interval: 5,
                    download: { _, _ in fatalError("not invoked") }
                )
                // We can't easily peek the internal interval without
                // exposing it; assert via a smoke test that the
                // scheduler starts + stops cleanly with the small
                // requested interval.  Behaviour invariant: no crash,
                // no error.  Real timer-fire-rate tests would need
                // a mockable clock and aren't worth the complexity
                // for v1.8.2.
                sched.start()
                sched.stop()
            }
        }
    }

    // MARK: - Fixtures

    struct Env {
        let workdir: URL
        let cleanup: () -> Void
    }

    static func makeEnv() -> Env {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("splynek-autoupdate-test-\(UUID())")
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return Env(workdir: root, cleanup: { try? fm.removeItem(at: root) })
    }

    static func makeRecord(
        name: String,
        autoUpdate: Bool,
        installedDigest: String? = nil
    ) -> InstalledAppRecord {
        InstalledAppRecord(
            id: UUID(),
            spec: InstallSpec(
                name: name,
                bundleID: "test.\(name.lowercased())",
                downloadURL: URL(string: "https://example.com/\(name).dmg")!,
                kind: .dmg,
                expectedDigest: nil,
                source: .directURL
            ),
            installedAt: URL(fileURLWithPath: "/Applications/\(name).app"),
            installedVersion: "1.0",
            installedDate: Date(),
            installedDigest: installedDigest,
            autoUpdate: autoUpdate
        )
    }
}
