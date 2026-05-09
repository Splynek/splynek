// Copyright © 2026 Splynek. MIT.
//
// TrustWatchAlertRecord — CloudKit schema for delivering Trust
// Watcher alerts from the user's Pro Mac to their iPhone(s).
//
// Sprint 1 PRO-PLUS-IPHONE (2026-05-09).
//
// **Direction is reversed from CloudKitRelayRecord:**
//   • Mac (writer)    — TrustWatchCloudKitNotifier publishes a
//                        record to the user's *private* CloudKit
//                        database when a new alert is detected.
//   • iPhone (reader) — A CKQuerySubscription delivers a
//                        UNNotification when a new record matching
//                        the iPhone's pairedMacUUID arrives.
//
// Why CloudKit instead of APNs:
//   • Zero infrastructure on our end.  We never ship a push
//     server, never hold device tokens, never see the alert
//     content.  All keys + payload encrypted by Apple, scoped
//     to the user's iCloud account.
//   • Works automatically across the user's iPhone + iPad +
//     future Watch — every device subscribed to the same
//     private DB sees the alert.
//
// Schema (CKRecord type "SplynekTrustWatchAlert"):
//
//   alertID        String  — TrustWatchStore alert id (deduplication)
//   sourceMacUUID  String  — FleetCoordinator.deviceUUID of writer
//   targetAppName  String  — "Spotify", "Adobe Photoshop", etc.
//   policyKind     String  — "Privacy Policy" / "Terms of Service" / etc.
//   severity       String  — "info" | "notice" | "material"
//   pageURL        String  — the policy URL to open in Safari
//   observedAt     Date    — when the diff fired
//   acknowledged   Int64   — 0 = pending, 1 = user acknowledged
//
// All fields are user-private.  We never log content; the iPhone
// notification just shows "Spotify Privacy Policy changed (notable)".

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

public struct TrustWatchAlertRecord: Equatable, Hashable, Sendable, Codable {
    public var id: String        // CKRecord.ID name (== alertID)
    public var alertID: String
    public var sourceMacUUID: String
    public var targetAppName: String
    public var policyKind: String
    public var severity: String
    public var pageURL: String
    public var observedAt: Date
    public var acknowledged: Bool

    /// CKRecord type used for round-trip with CloudKit.  Stays in
    /// sync between iOS reader + Mac writer; renaming would
    /// require a CloudKit Dashboard schema migration.
    public static let recordType = "SplynekTrustWatchAlert"

    public init(id: String? = nil,
                alertID: String,
                sourceMacUUID: String,
                targetAppName: String,
                policyKind: String,
                severity: String,
                pageURL: String,
                observedAt: Date = Date(),
                acknowledged: Bool = false) {
        // Use alertID as record name so a re-publish of the same
        // alert is idempotent on CloudKit's side (CKRecord upsert).
        self.id = id ?? alertID
        self.alertID = alertID
        self.sourceMacUUID = sourceMacUUID
        self.targetAppName = targetAppName
        self.policyKind = policyKind
        self.severity = severity
        self.pageURL = pageURL
        self.observedAt = observedAt
        self.acknowledged = acknowledged
    }
}

#if canImport(CloudKit)
public extension TrustWatchAlertRecord {
    /// CKRecord round-trip out.  Sets every field; pulled by the
    /// iOS subscriber's `from(_:)`.
    func toCKRecord() -> CKRecord {
        let rid = CKRecord.ID(recordName: id)
        let rec = CKRecord(recordType: Self.recordType, recordID: rid)
        rec["alertID"] = alertID as NSString
        rec["sourceMacUUID"] = sourceMacUUID as NSString
        rec["targetAppName"] = targetAppName as NSString
        rec["policyKind"] = policyKind as NSString
        rec["severity"] = severity as NSString
        rec["pageURL"] = pageURL as NSString
        rec["observedAt"] = observedAt as NSDate
        rec["acknowledged"] = (acknowledged ? 1 : 0) as NSNumber
        return rec
    }

    /// Inverse — decode a CKRecord pulled from CloudKit.  Returns
    /// nil if any required field is missing.  iOS-side use.
    static func from(_ rec: CKRecord) -> TrustWatchAlertRecord? {
        guard rec.recordType == recordType,
              let alertID = rec["alertID"] as? String,
              let sourceMacUUID = rec["sourceMacUUID"] as? String,
              let targetAppName = rec["targetAppName"] as? String,
              let policyKind = rec["policyKind"] as? String,
              let severity = rec["severity"] as? String,
              let pageURL = rec["pageURL"] as? String,
              let observedAt = rec["observedAt"] as? Date
        else { return nil }
        let ackInt = (rec["acknowledged"] as? NSNumber)?.intValue ?? 0
        return TrustWatchAlertRecord(
            id: rec.recordID.recordName,
            alertID: alertID,
            sourceMacUUID: sourceMacUUID,
            targetAppName: targetAppName,
            policyKind: policyKind,
            severity: severity,
            pageURL: pageURL,
            observedAt: observedAt,
            acknowledged: ackInt != 0
        )
    }
}
#endif

/// Pure-logic helpers exercised in tests.  Decoupled from CloudKit
/// so the macOS test harness can run them without an iCloud account.
public enum TrustWatchAlertNotification {
    /// Build the `(title, body, sound)` triple for a UNNotification
    /// from a Trust Watcher alert record.  Pure function — same
    /// inputs → same output → easy to unit-test.
    public static func notification(
        for record: TrustWatchAlertRecord
    ) -> (title: String, body: String) {
        let kind = record.policyKind
        let app = record.targetAppName
        let title = "\(app) — \(kind) changed"
        let body: String
        switch record.severity {
        case "material":
            body = "Material change detected. Tap to read the updated \(kind.lowercased())."
        case "notice":
            body = "Notable change detected. Tap to read what's different."
        default:
            body = "Minor change detected."
        }
        return (title, body)
    }
}
