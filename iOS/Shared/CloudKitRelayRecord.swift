// Copyright © 2026 Splynek. MIT.
//
// CloudKitRelayRecord — the typed payload shared between iOS
// (writer) and macOS (reader) for over-cellular URL submission.
//
// When the iOS Splynek Companion's Share Extension can't reach
// the paired Mac over LAN (phone is on cellular, on a hotel Wi-Fi,
// or the Mac is asleep on a different network), it falls back to
// writing a CKRecord to the user's *private* CloudKit database.
// The Mac polls its private database every 60s while running and
// ingests any pending records targeting its uuid.
//
// Schema (CKRecord type "SplynekRelayJob"):
//
//   url            String       — the URL to download
//   submittedAt    Date         — sender's clock at write time
//   senderDevice   String       — e.g. "Paulo's iPhone"
//   targetMacUUID  String       — receiver Mac's TXT-record uuid;
//                                 empty = "any of my paired Macs"
//                                 (we never use empty in practice —
//                                 the iOS UI always picks a target)
//   status         String       — "pending" | "consumed"
//
// All fields are user-private — CloudKit's private database is
// scoped to the user's iCloud account, encrypted in transit + at
// rest by Apple.  Splynek never sees the data; we only define
// the schema.

import Foundation
#if canImport(CloudKit)
import CloudKit
#endif

public struct CloudKitRelayRecord: Equatable, Hashable, Sendable, Codable {
    /// CKRecord.ID name (when available) or a UUID stamp on
    /// fresh, unsaved records.  Used by Mac-side `markConsumed`
    /// to match the right record back to CloudKit.
    public var id: String

    public var url: String
    public var submittedAt: Date
    public var senderDevice: String
    public var targetMacUUID: String
    public var status: Status

    public enum Status: String, Codable, Sendable {
        case pending
        case consumed
    }

    public init(id: String = UUID().uuidString,
                url: String,
                submittedAt: Date = Date(),
                senderDevice: String,
                targetMacUUID: String,
                status: Status = .pending) {
        self.id = id
        self.url = url
        self.submittedAt = submittedAt
        self.senderDevice = senderDevice
        self.targetMacUUID = targetMacUUID
        self.status = status
    }
}

// MARK: - CKRecord conversion (gated on CloudKit availability)
//
// `canImport(CloudKit)` returns true on both iOS + macOS, so this
// compiles in both targets.  We don't gate on `os(iOS)` here.

#if canImport(CloudKit)
public extension CloudKitRelayRecord {

    /// Canonical CloudKit record-type string.  Mac side filters
    /// subscriptions/queries on this exact value.
    static let recordType: CKRecord.RecordType = "SplynekRelayJob"

    /// Encode → fresh `CKRecord` ready to save.  When `id` was
    /// auto-generated (UUID), the CKRecord.ID adopts it so future
    /// `markConsumed` operations can find this record by name.
    func toCKRecord() -> CKRecord {
        let recordID = CKRecord.ID(recordName: self.id)
        let r = CKRecord(recordType: Self.recordType, recordID: recordID)
        r["url"]           = self.url            as CKRecordValue
        r["submittedAt"]   = self.submittedAt    as CKRecordValue
        r["senderDevice"]  = self.senderDevice   as CKRecordValue
        r["targetMacUUID"] = self.targetMacUUID  as CKRecordValue
        r["status"]        = self.status.rawValue as CKRecordValue
        return r
    }

    /// Decode ← CKRecord.  Returns nil when any required field is
    /// missing or wrong-typed (CloudKit schema drift, partial-fetch
    /// from a paginated query, etc.) — the caller treats the record
    /// as malformed and skips it rather than crashing the relay
    /// pipeline.
    static func from(ckRecord r: CKRecord) -> CloudKitRelayRecord? {
        guard
            let url = r["url"] as? String, !url.isEmpty,
            let submittedAt = r["submittedAt"] as? Date,
            let senderDevice = r["senderDevice"] as? String,
            let targetMacUUID = r["targetMacUUID"] as? String,
            let statusRaw = r["status"] as? String,
            let status = Status(rawValue: statusRaw)
        else { return nil }
        return CloudKitRelayRecord(
            id: r.recordID.recordName,
            url: url,
            submittedAt: submittedAt,
            senderDevice: senderDevice,
            targetMacUUID: targetMacUUID,
            status: status
        )
    }
}
#endif
