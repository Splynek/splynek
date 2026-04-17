import Foundation
@testable import SplynekCore

/// Load-bearing claim (v0.23): don't re-download a file the user
/// already has. Wrong match logic means the duplicate banner fires on
/// unrelated URLs (UX regression) or MISSES real dupes (silent waste).
enum DuplicateTests {

    static func run() {
        TestHarness.suite("Duplicate.findMatch") {

            TestHarness.test("Returns nil on empty history") {
                let url = URL(string: "https://example.com/x")!
                try expect(Duplicate.findMatch(for: url, in: []) == nil)
            }

            TestHarness.test("Returns nil when the prior output file is gone") {
                // History references a path that doesn't exist on disk.
                let entry = HistoryEntry(
                    id: UUID(),
                    url: "https://example.com/ghost.bin",
                    filename: "ghost.bin",
                    outputPath: "/tmp/splynek-no-such-file-\(UUID()).bin",
                    totalBytes: 42,
                    bytesPerInterface: [:],
                    startedAt: Date().addingTimeInterval(-60),
                    finishedAt: Date(),
                    sha256: nil
                )
                try expect(Duplicate.findMatch(
                    for: URL(string: entry.url)!, in: [entry]
                ) == nil)
            }

            TestHarness.test("Matches a prior completion whose file still exists") {
                // Create a real tempfile so the disk check succeeds.
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("splynek-dup-\(UUID().uuidString).bin")
                try Data([0, 1, 2]).write(to: tmp)
                defer { try? FileManager.default.removeItem(at: tmp) }

                let url = URL(string: "https://example.com/real.iso")!
                let entry = HistoryEntry(
                    id: UUID(),
                    url: url.absoluteString,
                    filename: "real.iso",
                    outputPath: tmp.path,
                    totalBytes: 3,
                    bytesPerInterface: [:],
                    startedAt: Date().addingTimeInterval(-60),
                    finishedAt: Date(),
                    sha256: nil
                )
                guard let match = Duplicate.findMatch(for: url, in: [entry]) else {
                    throw Expectation(
                        message: "expected match, got nil", file: #file, line: #line
                    )
                }
                try expect(match.fileExists)
                try expectEqual(match.entry.id, entry.id)
                try expect(match.ageSeconds >= 0)
            }

            TestHarness.test("Picks the most recent match when multiple exist") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("splynek-dup2-\(UUID().uuidString).bin")
                try Data("latest".utf8).write(to: tmp)
                defer { try? FileManager.default.removeItem(at: tmp) }
                let url = URL(string: "https://example.com/multi.iso")!
                let older = HistoryEntry(
                    id: UUID(),
                    url: url.absoluteString,
                    filename: "older.iso",
                    outputPath: "/tmp/splynek-gone-\(UUID()).bin",
                    totalBytes: 10,
                    bytesPerInterface: [:],
                    startedAt: Date().addingTimeInterval(-3600),
                    finishedAt: Date().addingTimeInterval(-3000),
                    sha256: nil
                )
                let newer = HistoryEntry(
                    id: UUID(),
                    url: url.absoluteString,
                    filename: "multi.iso",
                    outputPath: tmp.path,
                    totalBytes: 6,
                    bytesPerInterface: [:],
                    startedAt: Date().addingTimeInterval(-600),
                    finishedAt: Date().addingTimeInterval(-500),
                    sha256: nil
                )
                // Duplicate.findMatch uses `history.last(where:)`, i.e. the
                // MOST RECENT entry in list order. The newer one's file
                // exists, so it should win.
                guard let match = Duplicate.findMatch(for: url, in: [older, newer]) else {
                    throw Expectation(message: "expected match", file: #file, line: #line)
                }
                try expectEqual(match.entry.id, newer.id)
            }
        }
    }
}
