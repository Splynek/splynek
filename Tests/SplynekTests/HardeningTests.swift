import Foundation
@testable import SplynekCore

/// 2026-05-08 audit pass: covers the four pure-logic surfaces shipped
/// in this session that previously had zero test coverage.
///
///   1. `InstallPreflight.detectFormat`     — magic-byte sniff for
///       DMG / ZIP / PKG / HTML, used to fail fast before hdiutil.
///   2. `AppPricing.Pricing.annualizedUSD(forTier:)` — tier-aware
///       cost computation now driving the Savings hero numbers.
///   3. Scanner version-compare logic, exposed via `AppUpdateInfo.isNewer`
///       (the same comparator the SovereigntyScanner now uses to
///       deduplicate `<App>.app` vs `<App> 2.app`).
///   4. `DownloadHistory.remove(id:)` + `clearAll()` — the
///       persistence helpers wired into the History tab’s new
///       Forget / Clear-all actions.
enum HardeningTests {

    static func run() {
        TestHarness.suite("InstallPreflight — format detection") {

            TestHarness.test("ZIP magic PK\\x03\\x04 → .zip") {
                let tmp = makeTmpFile("sample.zip",
                    bytes: [0x50, 0x4B, 0x03, 0x04, 0x14, 0x00, 0x00, 0x00])
                defer { try? FileManager.default.removeItem(at: tmp) }
                let result = InstallPreflight.detectFormat(payload: tmp)
                try expect(result == .zip, "got \(result)")
            }

            TestHarness.test("PKG magic 'xar!' → .pkg") {
                let tmp = makeTmpFile("sample.pkg",
                    bytes: [0x78, 0x61, 0x72, 0x21, 0x00, 0x1C])
                defer { try? FileManager.default.removeItem(at: tmp) }
                let result = InstallPreflight.detectFormat(payload: tmp)
                try expect(result == .pkg, "got \(result)")
            }

            TestHarness.test("HTML 404 page → .xml (caught as bad payload)") {
                let html = "<!DOCTYPE html><html><body>404 Not Found</body></html>"
                let tmp = makeTmpFile("sample.dmg", bytes: Array(html.utf8))
                defer { try? FileManager.default.removeItem(at: tmp) }
                let result = InstallPreflight.detectFormat(payload: tmp)
                try expect(result == .xml, "got \(result)")
            }

            TestHarness.test("DMG synthetic koly trailer → .dmg") {
                // Build a 1KB blob with the 'koly' marker in the
                // last 512 bytes, mirroring the UDIF trailer layout.
                var bytes = [UInt8](repeating: 0x00, count: 1024)
                let kolyOffset = 1024 - 512 + 0
                bytes[kolyOffset]     = 0x6B  // 'k'
                bytes[kolyOffset + 1] = 0x6F  // 'o'
                bytes[kolyOffset + 2] = 0x6C  // 'l'
                bytes[kolyOffset + 3] = 0x79  // 'y'
                let tmp = makeTmpFile("sample.dmg", bytes: bytes)
                defer { try? FileManager.default.removeItem(at: tmp) }
                let result = InstallPreflight.detectFormat(payload: tmp)
                try expect(result == .dmg, "got \(result)")
            }

            TestHarness.test("Random bytes → .unknown") {
                let tmp = makeTmpFile("sample.bin",
                    bytes: [0x42, 0x4D, 0x36, 0x00, 0x00, 0x00])  // BMP-ish
                defer { try? FileManager.default.removeItem(at: tmp) }
                let result = InstallPreflight.detectFormat(payload: tmp)
                try expect(result == .unknown, "got \(result)")
            }

            TestHarness.test("validateBeforeRun: HTML masquerading as DMG → .fatal") {
                let html = "<html>oops</html>"
                let tmp = makeTmpFile("oops.dmg", bytes: Array(html.utf8))
                defer { try? FileManager.default.removeItem(at: tmp) }
                let verdict = InstallPreflight.validateBeforeRun(
                    payload: tmp, expectedKind: .dmg)
                if case .fatal = verdict { /* ok */ }
                else { try expect(false, "expected .fatal, got \(verdict)") }
            }

            TestHarness.test("validateBeforeRun: matching DMG → .ok") {
                var bytes = [UInt8](repeating: 0x00, count: 1024)
                let kolyOffset = 1024 - 512
                bytes[kolyOffset]     = 0x6B
                bytes[kolyOffset + 1] = 0x6F
                bytes[kolyOffset + 2] = 0x6C
                bytes[kolyOffset + 3] = 0x79
                let tmp = makeTmpFile("sample.dmg", bytes: bytes)
                defer { try? FileManager.default.removeItem(at: tmp) }
                let verdict = InstallPreflight.validateBeforeRun(
                    payload: tmp, expectedKind: .dmg)
                if case .ok = verdict { /* ok */ }
                else { try expect(false, "expected .ok, got \(verdict)") }
            }
        }

        TestHarness.suite("AppPricing — tier-aware annualisation") {

            TestHarness.test("annualizedUSD(forTier: nil) returns landing rate") {
                let pricing = AppPricing.Pricing(
                    model: .freemium, freeTier: true,
                    approxUSD: 20.0, billingCycle: .monthly,
                    sourceURL: nil,
                    tiers: [
                        .init(label: "Pro",   approxUSD: 20.0,  billingCycle: .monthly),
                        .init(label: "Max",   approxUSD: 100.0, billingCycle: .monthly),
                    ])
                let v = pricing.annualizedUSD(forTier: nil) ?? -1
                try expect(abs(v - 240.0) < 0.01, "got \(v)")
            }

            TestHarness.test("annualizedUSD(forTier: 'Max') honours tier rate") {
                let pricing = AppPricing.Pricing(
                    model: .freemium, freeTier: true,
                    approxUSD: 20.0, billingCycle: .monthly,
                    sourceURL: nil,
                    tiers: [
                        .init(label: "Pro",   approxUSD: 20.0,  billingCycle: .monthly),
                        .init(label: "Max",   approxUSD: 100.0, billingCycle: .monthly),
                    ])
                let v = pricing.annualizedUSD(forTier: "Max") ?? -1
                try expect(abs(v - 1200.0) < 0.01, "got \(v)")
            }

            TestHarness.test("annualizedUSD(forTier: <unknown>) falls back to landing rate") {
                let pricing = AppPricing.Pricing(
                    model: .subscription, approxUSD: 20.0,
                    billingCycle: .monthly, sourceURL: nil,
                    tiers: [
                        .init(label: "Pro", approxUSD: 20.0, billingCycle: .monthly),
                    ])
                let v = pricing.annualizedUSD(forTier: "NotARealTier") ?? -1
                try expect(abs(v - 240.0) < 0.01, "got \(v)")
            }

            TestHarness.test("Annual billing cycle: $90/year tier → $90 annualised") {
                let tier = AppPricing.Tier(
                    label: "Plus", approxUSD: 90.0, billingCycle: .annual)
                try expect(abs(tier.annualizedUSD - 90.0) < 0.01)
            }

            TestHarness.test("One-time tier amortises over 5 years") {
                let tier = AppPricing.Tier(
                    label: "Lifetime", approxUSD: 100.0, billingCycle: .oneTime)
                try expect(abs(tier.annualizedUSD - 20.0) < 0.01)
            }
        }

        TestHarness.suite("DownloadHistory — remove + clearAll") {

            TestHarness.test("remove(id:) prunes by UUID") {
                redirectHistoryToTmp()
                defer { restoreHistoryURL() }
                let a = makeEntry(name: "a.zip")
                let b = makeEntry(name: "b.zip")
                DownloadHistory.record(a)
                DownloadHistory.record(b)
                try expect(DownloadHistory.load().count == 2)
                DownloadHistory.remove(id: a.id)
                let after = DownloadHistory.load()
                try expect(after.count == 1, "remaining: \(after.count)")
                try expect(after.first?.id == b.id, "expected b survived")
            }

            TestHarness.test("clearAll() empties the log") {
                redirectHistoryToTmp()
                defer { restoreHistoryURL() }
                DownloadHistory.record(makeEntry(name: "a.zip"))
                DownloadHistory.record(makeEntry(name: "b.zip"))
                DownloadHistory.record(makeEntry(name: "c.zip"))
                try expect(DownloadHistory.load().count == 3)
                DownloadHistory.clearAll()
                try expect(DownloadHistory.load().isEmpty)
            }

            TestHarness.test("remove(id:) on a non-existent id is a no-op") {
                redirectHistoryToTmp()
                defer { restoreHistoryURL() }
                DownloadHistory.record(makeEntry(name: "a.zip"))
                DownloadHistory.remove(id: UUID())  // never recorded
                try expect(DownloadHistory.load().count == 1)
            }
        }

        TestHarness.suite("AppUpdateInfo.isNewer — hardening") {
            // The SovereigntyScanner's new dedup logic uses the same
            // segment-wise comparator as `AppUpdateInfo.isNewer`.
            // These tests pin the edge cases that matter for the
            // "<App>.app vs <App> 2.app" tie-break we ship.

            TestHarness.test("Triple-digit segments: 0.13.1 < 0.18.0") {
                try expect(AppUpdateInfo.isNewer(installed: "0.13.1", available: "0.18.0"))
            }
            TestHarness.test("Equal length numeric: 5.1.5 < 5.1.6") {
                try expect(AppUpdateInfo.isNewer(installed: "5.1.5", available: "5.1.6"))
            }
            TestHarness.test("Different lengths: 1.0 < 1.0.1") {
                try expect(AppUpdateInfo.isNewer(installed: "1.0", available: "1.0.1"))
            }
            TestHarness.test("Reverse direction: 1.0.1 vs 1.0 → false") {
                try expect(!AppUpdateInfo.isNewer(installed: "1.0.1", available: "1.0"))
            }
        }
    }

    // MARK: - helpers

    private static func makeTmpFile(_ name: String, bytes: [UInt8]) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(name)")
        try? Data(bytes).write(to: url, options: .atomic)
        return url
    }

    private static func makeEntry(name: String, bytes: Int64 = 1024) -> HistoryEntry {
        HistoryEntry(
            id: UUID(),
            url: "https://example.com/\(name)",
            filename: name,
            outputPath: "/tmp/\(name)",
            totalBytes: bytes,
            bytesPerInterface: ["en0": bytes],
            startedAt: Date(timeIntervalSinceNow: -10),
            finishedAt: Date(),
            sha256: nil,
            secondsSaved: nil
        )
    }

    /// DownloadHistory has no override hook (unlike the registry), so
    /// for tests we point its writes at `~/Library/.../Splynek/` but
    /// rename the file out of the way first, then restore.  The
    /// production path is the same one production uses; these tests
    /// run sequentially so atomic-rename is enough isolation for the
    /// `splynek-test` harness.
    private static var savedHistoryBackup: URL?
    private static func redirectHistoryToTmp() {
        let real = DownloadHistory.storeURL
        if FileManager.default.fileExists(atPath: real.path) {
            let backup = real.deletingLastPathComponent()
                .appendingPathComponent("history.test-backup-\(UUID().uuidString).json")
            try? FileManager.default.moveItem(at: real, to: backup)
            savedHistoryBackup = backup
        }
    }
    private static func restoreHistoryURL() {
        let real = DownloadHistory.storeURL
        try? FileManager.default.removeItem(at: real)
        if let backup = savedHistoryBackup {
            try? FileManager.default.moveItem(at: backup, to: real)
            savedHistoryBackup = nil
        }
    }
}
