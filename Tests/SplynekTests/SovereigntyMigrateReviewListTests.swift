import Foundation
@testable import SplynekCore

/// Tests for the persisted Migrate review list — Sprint 2 part-2
/// (2026-05-09).
enum SovereigntyMigrateReviewListTests {

    static func run() {
        TestHarness.suite("Migrate review list") {

            func entry(_ bundle: String, _ name: String, _ alt: String,
                       _ markedAt: String) -> SovereigntyMigrateReviewEntry {
                SovereigntyMigrateReviewEntry(
                    bundleID: bundle,
                    originalDisplayName: name,
                    alternativeName: alt,
                    alternativeHomepage: URL(string: "https://example.invalid/")!,
                    markedAt: markedAt
                )
            }

            TestHarness.test("upsert adds new entry at head") {
                var list = SovereigntyMigrateReviewList.empty
                list.upsert(entry("a.b", "A", "X", "2026-05-09T00:00:00Z"))
                try expect(list.entries.count == 1, "missing insert")
                try expect(list.entries[0].bundleID == "a.b", "wrong bundle")
            }

            TestHarness.test("upsert is idempotent on (bundle, alt)") {
                var list = SovereigntyMigrateReviewList.empty
                list.upsert(entry("a.b", "A", "X", "2026-05-09T00:00:00Z"))
                list.upsert(entry("a.b", "A", "X", "2026-05-09T01:00:00Z"))
                try expect(list.entries.count == 1,
                           "duplicate insert should dedupe by (bundle, alt)")
                try expect(list.entries[0].markedAt == "2026-05-09T01:00:00Z",
                           "second upsert should refresh markedAt")
            }

            TestHarness.test("Different alternatives keep separate entries") {
                var list = SovereigntyMigrateReviewList.empty
                list.upsert(entry("a.b", "A", "X", "2026-05-09T00:00:00Z"))
                list.upsert(entry("a.b", "A", "Y", "2026-05-09T00:00:00Z"))
                try expect(list.entries.count == 2,
                           "different alternatives should be distinct")
            }

            TestHarness.test("remove deletes by id") {
                var list = SovereigntyMigrateReviewList.empty
                list.upsert(entry("a.b", "A", "X", "2026-05-09T00:00:00Z"))
                let id = list.entries[0].id
                list.remove(id: id)
                try expect(list.entries.isEmpty, "remove failed")
            }

            TestHarness.test("entriesOlderThan filters by date") {
                var list = SovereigntyMigrateReviewList.empty
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                let now = Date()
                let weekAgo = f.string(from: now.addingTimeInterval(-7 * 86_400 - 60))
                let yesterday = f.string(from: now.addingTimeInterval(-86_400))
                list.upsert(entry("old.app", "Old", "Alt", weekAgo))
                list.upsert(entry("new.app", "New", "Alt", yesterday))
                let stale = list.entriesOlderThan(days: 7, now: now)
                try expect(stale.count == 1,
                           "expected 1 stale entry, got \(stale.count)")
                try expect(stale.first?.bundleID == "old.app",
                           "wrong stale bundle")
            }

            TestHarness.test("Disk store round-trip") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("migrate-review-test-\(UUID()).json")
                SovereigntyMigrateReviewStore._testOverrideURL = tmp
                defer {
                    try? FileManager.default.removeItem(at: tmp)
                    SovereigntyMigrateReviewStore._testOverrideURL = nil
                }
                let store = SovereigntyMigrateReviewStore()
                store.mutate { $0.upsert(entry("a.b", "A", "X", "2026-05-09T00:00:00Z")) }
                let read = store.read()
                try expect(read.entries.count == 1, "round-trip lost data")
                try expect(read.entries[0].bundleID == "a.b", "wrong bundle on read")
            }
        }
    }
}
