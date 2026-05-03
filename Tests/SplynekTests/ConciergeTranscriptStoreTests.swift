import Foundation
@testable import SplynekCore

/// v1.7.x: persistence invariants for ConciergeTranscriptStore.
/// Tests use a per-test temporary URL — no Application Support
/// dependency, no cross-test bleed.
enum ConciergeTranscriptStoreTests {

    static func run() {
        TestHarness.suite("ConciergeTranscriptStore — round-trip") {

            TestHarness.test("Saved messages round-trip through load") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                let store = ConciergeTranscriptStore(url: url)

                let original = sampleMessages(count: 3)
                store.save(original)
                let loaded = store.load()

                try expectEqual(loaded.count, 3)
                try expectEqual(loaded, original, "Round-trip preserves all fields including UUID")
            }

            TestHarness.test("Empty array round-trips as empty") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                let store = ConciergeTranscriptStore(url: url)

                store.save([])
                try expect(store.load().isEmpty, "Empty save → empty load")
            }

            TestHarness.test("Optional fields preserve nil") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                let store = ConciergeTranscriptStore(url: url)

                let m = ConciergeTranscriptStore.PersistedMessage(
                    id: UUID(),
                    role: "user",
                    text: "hi",
                    action: nil,
                    toolID: nil
                )
                store.save([m])
                let loaded = store.load()
                try expectEqual(loaded.count, 1)
                try expect(loaded[0].action == nil, "action stays nil")
                try expect(loaded[0].toolID == nil, "toolID stays nil")
            }
        }

        TestHarness.suite("ConciergeTranscriptStore — failure modes") {

            TestHarness.test("Missing file returns empty array") {
                let url = makeTmpURL()  // never written
                let store = ConciergeTranscriptStore(url: url)
                try expect(store.load().isEmpty, "Missing file → empty load (no crash)")
            }

            TestHarness.test("Corrupted JSON returns empty array") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                try? Data("{ this is not valid json".utf8).write(to: url)

                let store = ConciergeTranscriptStore(url: url)
                try expect(store.load().isEmpty, "Bad JSON → empty load (no crash)")
            }

            TestHarness.test("Schema version mismatch returns empty array") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                // Write a future schema version; current loader should reject.
                let futureSchema = """
                { "version": 999, "messages": [] }
                """
                try? Data(futureSchema.utf8).write(to: url)

                let store = ConciergeTranscriptStore(url: url)
                try expect(store.load().isEmpty, "Unknown schema → empty load")
            }

            TestHarness.test("Nil URL is a no-op store") {
                let store = ConciergeTranscriptStore(url: nil)
                store.save(sampleMessages(count: 5))      // no-op
                try expect(store.load().isEmpty, "Nil URL → no persistence")
                store.clear()                              // no-op, no crash
            }
        }

        TestHarness.suite("ConciergeTranscriptStore — retention + clear") {

            TestHarness.test("Save caps to last maxMessages entries") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                let store = ConciergeTranscriptStore(url: url)

                let cap = ConciergeTranscriptStore.maxMessages
                let oversize = sampleMessages(count: cap + 50)
                store.save(oversize)

                let loaded = store.load()
                try expectEqual(loaded.count, cap, "Saved at the cap")
                // Last `cap` were kept — first surviving id matches index 50.
                try expectEqual(loaded.first?.id, oversize[50].id, "Suffix wins, prefix dropped")
                try expectEqual(loaded.last?.id, oversize.last?.id, "Most-recent message preserved")
            }

            TestHarness.test("Clear removes the file") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                let store = ConciergeTranscriptStore(url: url)

                store.save(sampleMessages(count: 3))
                try expect(FileManager.default.fileExists(atPath: url.path), "File written")

                store.clear()
                try expect(!FileManager.default.fileExists(atPath: url.path), "File removed by clear()")
                try expect(store.load().isEmpty, "Post-clear load is empty")
            }

            TestHarness.test("Save → clear → save round-trips cleanly") {
                let url = makeTmpURL()
                defer { try? FileManager.default.removeItem(at: url) }
                let store = ConciergeTranscriptStore(url: url)

                store.save(sampleMessages(count: 5))
                store.clear()
                let fresh = sampleMessages(count: 2)
                store.save(fresh)

                try expectEqual(store.load(), fresh, "Post-clear save replaces, not appends")
            }
        }

        TestHarness.suite("ConciergeState — persistence integration") {

            // ConciergeState is @MainActor.  The harness runs sync test
            // bodies on the main thread, so MainActor.assumeIsolated
            // gives us the isolation without the await-on-semaphore
            // deadlock the async-test helper would cause (see the
            // comment at the top of EngineExternalIngestTests for the
            // mitigation history).

            TestHarness.test("Mutating chat persists; new state reads it back") {
                try MainActor.assumeIsolated {
                    let url = makeTmpURL()
                    defer { try? FileManager.default.removeItem(at: url) }
                    let store = ConciergeTranscriptStore(url: url)

                    let s1 = SplynekViewModel.ConciergeState(store: store)
                    try expect(s1.chat.isEmpty, "Empty disk → empty initial state")

                    s1.chat.append(.init(role: .user, text: "hello", action: nil))
                    s1.chat.append(.init(role: .assistant, text: "Top 5 space-takers under Downloads:", action: nil, card: nil, toolID: "disk_usage"))

                    let s2 = SplynekViewModel.ConciergeState(store: store)
                    try expectEqual(s2.chat.count, 2, "Persisted across reconstruction")
                    try expectEqual(s2.chat[0].text, "hello")
                    try expectEqual(s2.chat[1].toolID, "disk_usage", "toolID survives the round-trip")
                    try expect(s2.chat[1].card == nil, "Card is intentionally dropped on restore")
                    try expectEqual(s2.chat[0].id, s1.chat[0].id, "UUID identity survives restart")
                }
            }

            TestHarness.test("Setting chat = [] clears persisted file") {
                try MainActor.assumeIsolated {
                    let url = makeTmpURL()
                    defer { try? FileManager.default.removeItem(at: url) }
                    let store = ConciergeTranscriptStore(url: url)

                    let s1 = SplynekViewModel.ConciergeState(store: store)
                    s1.chat.append(.init(role: .user, text: "x", action: nil))
                    s1.chat = []  // models conciergeReset()

                    let s2 = SplynekViewModel.ConciergeState(store: store)
                    try expect(s2.chat.isEmpty, "Reset clears the disk-backed transcript")
                }
            }
        }
    }

    // MARK: - Fixtures

    private static func makeTmpURL() -> URL {
        let dir = FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("concierge-transcript-\(UUID().uuidString).json")
    }

    private static func sampleMessages(count: Int) -> [ConciergeTranscriptStore.PersistedMessage] {
        (0..<count).map { i in
            ConciergeTranscriptStore.PersistedMessage(
                id: UUID(),
                role: i % 2 == 0 ? "user" : "assistant",
                text: "message \(i)",
                action: i == 0 ? "act" : nil,
                toolID: i == 1 ? "search_history" : nil
            )
        }
    }
}
