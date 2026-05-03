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

        TestHarness.suite("Duplicate — digest-based + warmCacheLookup (v1.9.x)") {

            TestHarness.test("findMatch(forDigest:) returns nil for empty digest") {
                let m = Duplicate.findMatch(forDigest: "", in: [])
                try expect(m == nil)
            }

            TestHarness.test("findMatch(forDigest:) returns nil for unknown digest") {
                let m = Duplicate.findMatch(forDigest: "deadbeef", in: [])
                try expect(m == nil)
            }

            TestHarness.test("findMatch(forDigest:) returns hit when digest matches existing file") {
                let env = makeEnv()
                defer { env.cleanup() }
                let url = env.makeFile(name: "match.bin")
                let entry = makeEntry(
                    url: "https://example.com/different/url",
                    outputPath: url.path,
                    sha256: "ABCDEF"
                )
                guard let m = Duplicate.findMatch(forDigest: "abcdef", in: [entry]) else {
                    throw Expectation(message: "expected digest match", file: #file, line: #line)
                }
                try expectEqual(m.entry.id, entry.id)
            }

            TestHarness.test("findMatch(forDigest:) is case-insensitive on the digest") {
                let env = makeEnv()
                defer { env.cleanup() }
                let url = env.makeFile(name: "match.bin")
                let entry = makeEntry(
                    url: "https://example.com/x",
                    outputPath: url.path,
                    sha256: "AbCdEf"
                )
                let lower = Duplicate.findMatch(forDigest: "abcdef", in: [entry])
                let upper = Duplicate.findMatch(forDigest: "ABCDEF", in: [entry])
                let mixed = Duplicate.findMatch(forDigest: "AbCdEf", in: [entry])
                try expect(lower != nil)
                try expect(upper != nil)
                try expect(mixed != nil)
            }

            TestHarness.test("findMatch(forDigest:) returns nil when file is gone") {
                let env = makeEnv()
                defer { env.cleanup() }
                let url = env.makeFile(name: "missing.bin")
                let entry = makeEntry(
                    url: "https://example.com/x",
                    outputPath: url.path,
                    sha256: "feed"
                )
                try? FileManager.default.removeItem(at: url)
                let m = Duplicate.findMatch(forDigest: "feed", in: [entry])
                try expect(m == nil)
            }

            TestHarness.test("warmCacheLookup prefers digest match over URL match") {
                let env = makeEnv()
                defer { env.cleanup() }
                let urlEntryFile = env.makeFile(name: "url-entry.bin")
                let digestEntryFile = env.makeFile(name: "digest-entry.bin")

                let urlEntry = makeEntry(
                    url: "https://example.com/x",
                    outputPath: urlEntryFile.path,
                    sha256: "uuuu"
                )
                let digestEntry = makeEntry(
                    url: "https://example.com/different",
                    outputPath: digestEntryFile.path,
                    sha256: "DDDD"
                )
                let request = URL(string: "https://example.com/x")!
                guard let m = Duplicate.warmCacheLookup(
                    url: request, digest: "dddd",
                    in: [urlEntry, digestEntry]
                ) else {
                    throw Expectation(message: "expected match", file: #file, line: #line)
                }
                // Digest match wins — even though URL also matches a
                // different entry.
                try expectEqual(m.entry.id, digestEntry.id)
            }

            TestHarness.test("warmCacheLookup falls back to URL when digest is nil") {
                let env = makeEnv()
                defer { env.cleanup() }
                let url = env.makeFile(name: "match.bin")
                let entry = makeEntry(
                    url: "https://example.com/x",
                    outputPath: url.path,
                    sha256: nil
                )
                guard let m = Duplicate.warmCacheLookup(
                    url: URL(string: "https://example.com/x")!,
                    digest: nil,
                    in: [entry]
                ) else {
                    throw Expectation(message: "expected match", file: #file, line: #line)
                }
                try expectEqual(m.entry.id, entry.id)
            }
        }
    }

    // MARK: - Fixtures (shared with v1.9.x tests above)

    struct Env {
        let workdir: URL
        let cleanup: () -> Void
        func makeFile(name: String) -> URL {
            let url = workdir.appendingPathComponent(name)
            try? Data(repeating: 0xAB, count: 100).write(to: url)
            return url
        }
    }

    static func makeEnv() -> Env {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("splynek-dup-test-\(UUID())")
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return Env(workdir: root, cleanup: { try? fm.removeItem(at: root) })
    }

    static func makeEntry(
        url: String,
        outputPath: String,
        sha256: String?
    ) -> HistoryEntry {
        HistoryEntry(
            id: UUID(),
            url: url,
            filename: (outputPath as NSString).lastPathComponent,
            outputPath: outputPath,
            totalBytes: 100,
            bytesPerInterface: ["en0": 100],
            startedAt: Date().addingTimeInterval(-60),
            finishedAt: Date(),
            sha256: sha256,
            secondsSaved: nil
        )
    }
}
