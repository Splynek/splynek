import Foundation
@testable import SplynekCompanionCore

/// Tests for `TrustWatchAlertRecord` + the pure
/// `TrustWatchAlertNotification.notification(for:)` builder used
/// by both Mac (CloudKit publisher) and iPhone (push subscriber).
///
/// Sprint 1 PRO-PLUS-IPHONE (2026-05-09).
enum TrustWatchAlertRecordTests {

    static func run() {
        TestHarness.suite("Trust Watcher CloudKit record + notification") {

            TestHarness.test("Record id defaults to alertID") {
                let r = TrustWatchAlertRecord(
                    alertID: "test.app|privacyPolicy|2026-05-09T00:00:00Z",
                    sourceMacUUID: "mac-uuid",
                    targetAppName: "Test App",
                    policyKind: "Privacy Policy",
                    severity: "info",
                    pageURL: "https://example.invalid/p"
                )
                try expect(r.id == r.alertID,
                           "default id should equal alertID for CloudKit upsert idempotency")
            }

            TestHarness.test("Custom id overrides default") {
                let r = TrustWatchAlertRecord(
                    id: "custom-rec-id",
                    alertID: "alert-id",
                    sourceMacUUID: "mac",
                    targetAppName: "Test",
                    policyKind: "ToS",
                    severity: "info",
                    pageURL: "https://example.invalid/"
                )
                try expect(r.id == "custom-rec-id", "custom id was overwritten")
            }

            TestHarness.test("Notification title contains app + kind") {
                let r = TrustWatchAlertRecord(
                    alertID: "x", sourceMacUUID: "mac",
                    targetAppName: "Spotify",
                    policyKind: "Privacy Policy",
                    severity: "notice",
                    pageURL: "https://example.invalid/"
                )
                let n = TrustWatchAlertNotification.notification(for: r)
                try expect(n.title.contains("Spotify"),
                           "title missing app: '\(n.title)'")
                try expect(n.title.contains("Privacy Policy"),
                           "title missing kind: '\(n.title)'")
                try expect(n.title.lowercased().contains("changed"),
                           "title missing 'changed': '\(n.title)'")
            }

            TestHarness.test("Notification body escalates with severity") {
                let base = (alertID: "x", mac: "mac", app: "App",
                            kind: "ToS", url: "https://example.invalid/")
                let materialRec = TrustWatchAlertRecord(
                    alertID: base.alertID, sourceMacUUID: base.mac,
                    targetAppName: base.app, policyKind: base.kind,
                    severity: "material",
                    pageURL: base.url
                )
                let infoRec = TrustWatchAlertRecord(
                    alertID: base.alertID, sourceMacUUID: base.mac,
                    targetAppName: base.app, policyKind: base.kind,
                    severity: "info",
                    pageURL: base.url
                )
                let m = TrustWatchAlertNotification.notification(for: materialRec)
                let i = TrustWatchAlertNotification.notification(for: infoRec)
                try expect(m.body != i.body,
                           "material + info bodies should differ")
                try expect(m.body.lowercased().contains("material"),
                           "material body missing 'material': '\(m.body)'")
            }

            TestHarness.test("Codable round-trip preserves every field") {
                let original = TrustWatchAlertRecord(
                    id: "id-123",
                    alertID: "alert-id-9",
                    sourceMacUUID: "mac-abc",
                    targetAppName: "Adobe",
                    policyKind: "Privacy Policy",
                    severity: "material",
                    pageURL: "https://www.adobe.com/privacy/policy.html",
                    observedAt: Date(timeIntervalSince1970: 1_750_000_000),
                    acknowledged: true
                )
                let encoded = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(
                    TrustWatchAlertRecord.self, from: encoded
                )
                try expect(decoded == original,
                           "round-trip lost data: \(decoded) vs \(original)")
            }
        }
    }
}
