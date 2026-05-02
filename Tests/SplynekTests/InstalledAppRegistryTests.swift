import Foundation
@testable import SplynekCore

/// v1.8: persistence + upsert invariants for InstalledAppRegistry.
/// Each test resets the on-disk store first so they're order-independent.
enum InstalledAppRegistryTests {

    static func run() {
        TestHarness.suite("InstalledAppRegistry") {

            TestHarness.test("Empty store loads as empty array") {
                InstalledAppRegistry._resetForTesting()
                let records = InstalledAppRegistry.load()
                try expect(records.isEmpty, "Reset should leave empty store")
            }

            TestHarness.test("Upsert + load round-trip") {
                InstalledAppRegistry._resetForTesting()
                let r = makeRecord(name: "Firefox", bundleID: "org.mozilla.firefox")
                InstalledAppRegistry.upsert(r)

                let loaded = InstalledAppRegistry.load()
                try expect(loaded.count == 1, "Got \(loaded.count) records, expected 1")
                try expect(loaded.first?.spec.name == "Firefox")
                try expect(loaded.first?.spec.bundleID == "org.mozilla.firefox")
            }

            TestHarness.test("Upsert by bundleID replaces existing") {
                InstalledAppRegistry._resetForTesting()
                let v1 = makeRecord(name: "Firefox", bundleID: "org.mozilla.firefox", version: "120.0")
                let v2 = makeRecord(name: "Firefox", bundleID: "org.mozilla.firefox", version: "121.0")
                InstalledAppRegistry.upsert(v1)
                InstalledAppRegistry.upsert(v2)

                let loaded = InstalledAppRegistry.load()
                try expect(loaded.count == 1, "Bundle-ID dedupe failed")
                try expect(loaded.first?.installedVersion == "121.0")
            }

            TestHarness.test("Records without bundleID append (no dedupe)") {
                InstalledAppRegistry._resetForTesting()
                let r1 = makeRecord(name: "App1", bundleID: nil)
                let r2 = makeRecord(name: "App2", bundleID: nil)
                InstalledAppRegistry.upsert(r1)
                InstalledAppRegistry.upsert(r2)

                try expect(InstalledAppRegistry.load().count == 2, "Should have 2 distinct records")
            }

            TestHarness.test("Auto-update flag flip + filtered query") {
                InstalledAppRegistry._resetForTesting()
                let r = makeRecord(name: "Bitwarden", bundleID: "com.bitwarden.desktop")
                InstalledAppRegistry.upsert(r)
                try expect(InstalledAppRegistry.autoUpdateCandidates().isEmpty, "Default should be off")

                let ok = InstalledAppRegistry.setAutoUpdate(r.id, enabled: true)
                try expect(ok, "Should find + flip the record")
                try expect(InstalledAppRegistry.autoUpdateCandidates().count == 1)

                InstalledAppRegistry.setAutoUpdate(r.id, enabled: false)
                try expect(InstalledAppRegistry.autoUpdateCandidates().isEmpty)
            }

            TestHarness.test("Remove by id") {
                InstalledAppRegistry._resetForTesting()
                let r1 = makeRecord(name: "A", bundleID: "x.a")
                let r2 = makeRecord(name: "B", bundleID: "x.b")
                InstalledAppRegistry.upsert(r1)
                InstalledAppRegistry.upsert(r2)
                InstalledAppRegistry.remove(id: r1.id)

                let loaded = InstalledAppRegistry.load()
                try expect(loaded.count == 1)
                try expect(loaded.first?.spec.name == "B")
            }
        }

        TestHarness.suite("InstallerEngine — preflight") {

            TestHarness.test("trustPreflight returns nil for unknown bundle ID") {
                let spec = makeSpec(name: "Mystery", bundleID: "com.unknown.app")
                let result = InstallerEngine.trustPreflight(spec)
                try expect(result == nil, "Should return nil for unknown bundle")
            }

            TestHarness.test("kindFor heuristic maps extensions correctly") {
                let cases: [(String, InstallSpec.Kind)] = [
                    ("https://example.com/foo.pkg", .pkg),
                    ("https://example.com/foo.dmg", .dmg),
                    ("https://example.com/foo.zip", .appArchive),
                    ("https://example.com/foo.app", .appBundle),
                    ("https://example.com/foo",     .dmg),  // default
                ]
                for (urlStr, expected) in cases {
                    let url = URL(string: urlStr)!
                    let got = InstallerEngine.kindFor(url: url)
                    try expect(got == expected, "URL \(urlStr) → \(got), expected \(expected)")
                }
            }
        }
    }

    // MARK: - Fixtures

    static func makeSpec(
        name: String,
        bundleID: String?,
        kind: InstallSpec.Kind = .dmg
    ) -> InstallSpec {
        InstallSpec(
            name: name,
            bundleID: bundleID,
            downloadURL: URL(string: "https://example.com/\(name).dmg")!,
            kind: kind,
            expectedDigest: nil,
            source: .directURL
        )
    }

    static func makeRecord(
        name: String,
        bundleID: String?,
        version: String = "1.0.0"
    ) -> InstalledAppRecord {
        InstalledAppRecord(
            id: UUID(),
            spec: makeSpec(name: name, bundleID: bundleID),
            installedAt: URL(fileURLWithPath: "/Applications/\(name).app"),
            installedVersion: version,
            installedDate: Date(),
            installedDigest: nil,
            autoUpdate: false
        )
    }
}
