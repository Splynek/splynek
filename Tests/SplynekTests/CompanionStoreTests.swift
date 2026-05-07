import Foundation
import SplynekCompanionCore

/// S4 iOS Companion (2026-05-07): tests for `PairedMacStore` in
/// in-memory mode (the keychain-backed mode is exercised on-device
/// only — the macOS test runner doesn't have an App Group identifier
/// that resolves to a shared keychain access group).
enum CompanionStoreTests {

    static func run() {
        TestHarness.suite("PairedMacStore — in-memory CRUD") {

            TestHarness.test("Empty store returns empty list") {
                let store = PairedMacStore.inMemory()
                try expect(store.all().isEmpty)
            }

            TestHarness.test("Upsert + get round-trips") {
                let store = PairedMacStore.inMemory()
                let mac = PairedMac(uuid: "u1", displayName: "Mac",
                                    lastKnownHost: "1.2.3.4", lastKnownPort: 18280,
                                    token: "secret", lastSeen: Date())
                _ = store.upsert(mac)
                let got = store.get(uuid: "u1")
                try expect(got?.uuid == "u1")
                try expect(got?.displayName == "Mac")
                // In-memory mode preserves the token in-memory; the
                // disk-mode keychain split is exercised only on-device.
                try expect(got?.token == "secret")
            }

            TestHarness.test("Upsert with same uuid updates rather than duplicating") {
                let store = PairedMacStore.inMemory()
                let v1 = PairedMac(uuid: "u1", displayName: "Old",
                                   lastKnownHost: "1.1.1.1", lastKnownPort: 1,
                                   token: "t1", lastSeen: Date())
                let v2 = PairedMac(uuid: "u1", displayName: "New",
                                   lastKnownHost: "2.2.2.2", lastKnownPort: 2,
                                   token: "t2", lastSeen: Date())
                _ = store.upsert(v1)
                _ = store.upsert(v2)
                try expect(store.all().count == 1)
                try expect(store.get(uuid: "u1")?.displayName == "New")
            }

            TestHarness.test("Remove deletes the record") {
                let store = PairedMacStore.inMemory()
                _ = store.upsert(PairedMac(uuid: "u1", displayName: "M",
                                           lastKnownHost: "h", lastKnownPort: 1,
                                           token: "t", lastSeen: Date()))
                store.remove(uuid: "u1")
                try expect(store.all().isEmpty)
            }

            TestHarness.test("All() returns records sorted by displayName") {
                let store = PairedMacStore.inMemory()
                _ = store.upsert(PairedMac(uuid: "u1", displayName: "Zebra",
                                           lastKnownHost: "h", lastKnownPort: 1,
                                           token: "t", lastSeen: Date()))
                _ = store.upsert(PairedMac(uuid: "u2", displayName: "Alpha",
                                           lastKnownHost: "h", lastKnownPort: 1,
                                           token: "t", lastSeen: Date()))
                let names = store.all().map { $0.displayName }
                try expect(names == ["Alpha", "Zebra"])
            }
        }

        TestHarness.suite("PairedMac.baseURL") {

            TestHarness.test("Composes http URL from host + port") {
                let mac = PairedMac(uuid: "u1", displayName: "M",
                                    lastKnownHost: "192.168.1.10",
                                    lastKnownPort: 18280,
                                    token: "t", lastSeen: Date())
                try expect(mac.baseURL?.absoluteString == "http://192.168.1.10:18280")
            }
        }
    }
}
