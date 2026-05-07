import Foundation
import SplynekCompanionCore
#if canImport(CloudKit)
import CloudKit
#endif

/// S4 phase 3 (2026-05-07): tests for `CloudKitRelayRecord` —
/// the typed payload that carries iOS-submitted URLs across the
/// CloudKit relay.  Round-trips between Codable form and CKRecord
/// form are the load-bearing invariant.
enum CompanionCloudKitRecordTests {

    static func run() {
        TestHarness.suite("CloudKitRelayRecord — pure init + Codable") {

            TestHarness.test("Auto-generated id is a non-empty UUID") {
                let r = CloudKitRelayRecord(
                    url: "https://example.com/foo.dmg",
                    senderDevice: "iPhone",
                    targetMacUUID: "uuid-1")
                try expect(!r.id.isEmpty)
                // UUIDs are 36 chars (8-4-4-4-12 hex with hyphens).
                try expect(r.id.count == 36)
            }

            TestHarness.test("Default status is pending") {
                let r = CloudKitRelayRecord(
                    url: "u", senderDevice: "d", targetMacUUID: "m")
                try expect(r.status == .pending)
            }

            TestHarness.test("Codable round-trip preserves every field") {
                let original = CloudKitRelayRecord(
                    id: "rec-1",
                    url: "https://example.com",
                    submittedAt: Date(timeIntervalSince1970: 1_700_000_000),
                    senderDevice: "Paulo's iPhone",
                    targetMacUUID: "macbook-uuid",
                    status: .pending)
                let data = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(
                    CloudKitRelayRecord.self, from: data)
                try expect(decoded == original)
            }
        }

        #if canImport(CloudKit)
        TestHarness.suite("CloudKitRelayRecord — CKRecord round-trip") {

            TestHarness.test("toCKRecord populates all fields") {
                let r = CloudKitRelayRecord(
                    id: "rec-2",
                    url: "https://example.com/x",
                    submittedAt: Date(timeIntervalSince1970: 1_700_000_500),
                    senderDevice: "iPhone",
                    targetMacUUID: "mac-uuid",
                    status: .pending)
                let ck = r.toCKRecord()
                try expect(ck.recordType == CloudKitRelayRecord.recordType)
                try expect(ck.recordID.recordName == "rec-2")
                try expect((ck["url"] as? String) == "https://example.com/x")
                try expect((ck["senderDevice"] as? String) == "iPhone")
                try expect((ck["targetMacUUID"] as? String) == "mac-uuid")
                try expect((ck["status"] as? String) == "pending")
                try expect((ck["submittedAt"] as? Date) ==
                           Date(timeIntervalSince1970: 1_700_000_500))
            }

            TestHarness.test("CKRecord → Record round-trips identically") {
                let original = CloudKitRelayRecord(
                    id: "rec-3",
                    url: "https://example.com/dl.zip",
                    submittedAt: Date(timeIntervalSince1970: 1_700_001_000),
                    senderDevice: "iPad Pro",
                    targetMacUUID: "studio-mac",
                    status: .consumed)
                let ck = original.toCKRecord()
                let decoded = CloudKitRelayRecord.from(ckRecord: ck)
                try expect(decoded == original)
            }

            TestHarness.test("Missing required field → from(ckRecord:) returns nil") {
                let ck = CKRecord(
                    recordType: CloudKitRelayRecord.recordType,
                    recordID: CKRecord.ID(recordName: "rec-4"))
                ck["url"] = "https://example.com" as CKRecordValue
                ck["status"] = "pending" as CKRecordValue
                // missing submittedAt, senderDevice, targetMacUUID
                try expect(CloudKitRelayRecord.from(ckRecord: ck) == nil)
            }

            TestHarness.test("Unknown status string → nil (schema drift defence)") {
                let original = CloudKitRelayRecord(
                    id: "rec-5", url: "u", senderDevice: "d", targetMacUUID: "m")
                let ck = original.toCKRecord()
                ck["status"] = "made-up-state" as CKRecordValue
                try expect(CloudKitRelayRecord.from(ckRecord: ck) == nil)
            }

            TestHarness.test("Empty url → nil") {
                let original = CloudKitRelayRecord(
                    id: "rec-6", url: "u", senderDevice: "d", targetMacUUID: "m")
                let ck = original.toCKRecord()
                ck["url"] = "" as CKRecordValue
                try expect(CloudKitRelayRecord.from(ckRecord: ck) == nil)
            }
        }
        #endif

        TestHarness.suite("CloudKitRelayRecord — equality + hashing") {

            TestHarness.test("Two records with same fields are Equatable-equal") {
                let a = CloudKitRelayRecord(
                    id: "x", url: "u", submittedAt: Date(timeIntervalSince1970: 0),
                    senderDevice: "d", targetMacUUID: "m", status: .pending)
                let b = CloudKitRelayRecord(
                    id: "x", url: "u", submittedAt: Date(timeIntervalSince1970: 0),
                    senderDevice: "d", targetMacUUID: "m", status: .pending)
                try expect(a == b)
                try expect(a.hashValue == b.hashValue)
            }

            TestHarness.test("Different status → not equal") {
                let a = CloudKitRelayRecord(
                    id: "x", url: "u", senderDevice: "d", targetMacUUID: "m",
                    status: .pending)
                let b = CloudKitRelayRecord(
                    id: "x", url: "u", submittedAt: a.submittedAt,
                    senderDevice: "d", targetMacUUID: "m",
                    status: .consumed)
                try expect(a != b)
            }
        }
    }
}
