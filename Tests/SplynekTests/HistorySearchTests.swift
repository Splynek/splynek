import Foundation
@testable import SplynekCore

/// v1.7: ranking + tokenization invariants for HistorySearch.  All
/// tests are pure (no filesystem I/O — fixtures are constructed
/// inline) so they run deterministically on any host.
enum HistorySearchTests {

    static func run() {
        TestHarness.suite("HistorySearch — ranking") {
            let now = Date(timeIntervalSince1970: 1_800_000_000)  // pinned

            TestHarness.test("Empty query returns recency-only ordering") {
                let entries = [
                    fixture(id: "old",    filename: "a.iso", finishedAt: now.addingTimeInterval(-86400 * 30)),
                    fixture(id: "newest", filename: "b.iso", finishedAt: now.addingTimeInterval(-3600)),
                    fixture(id: "mid",    filename: "c.iso", finishedAt: now.addingTimeInterval(-86400 * 7)),
                ]
                let m = HistorySearch.search("", in: entries, limit: 10, now: now)
                try expect(m.count == 3, "Empty query keeps every entry, got \(m.count)")
                try expect(m[0].entry.url == "https://test/newest", "Most recent first, got \(m[0].entry.url)")
                try expect(m[2].entry.url == "https://test/old",     "Oldest last, got \(m[2].entry.url)")
            }

            TestHarness.test("Filename match outranks URL match") {
                let entries = [
                    fixture(id: "a", filename: "ubuntu-24.04.iso", url: "https://example.com/file"),
                    fixture(id: "b", filename: "release.iso",      url: "https://example.com/ubuntu"),
                ]
                let m = HistorySearch.search("ubuntu", in: entries, limit: 10, now: now)
                try expect(m.count == 2, "Both match, got \(m.count)")
                try expect(m[0].entry.id.uuidString == entries[0].id.uuidString, "Filename hit (×3) ranks above URL-only hit (×2)")
                try expect(m[0].matchedFields.contains(.filename))
                try expect(m[1].matchedFields.contains(.url))
            }

            TestHarness.test("Stopwords don't anchor matches") {
                let entries = [
                    fixture(id: "the", filename: "the-file.iso"),
                    fixture(id: "real", filename: "ubuntu.iso"),
                ]
                let m = HistorySearch.search("the latest", in: entries, limit: 10, now: now)
                // "the" + "latest" → tokenize drops "the" (stopword), "latest" doesn't appear,
                // so 0 matches expected.
                try expect(m.isEmpty, "Stopword-only query should match nothing, got \(m.count)")
            }

            TestHarness.test("Recency decays old matches against fresh ones") {
                let yearAgo = now.addingTimeInterval(-365 * 86400)
                let entries = [
                    fixture(id: "old", filename: "ubuntu.iso", finishedAt: yearAgo),
                    fixture(id: "new", filename: "ubuntu.iso", finishedAt: now.addingTimeInterval(-3600)),
                ]
                let m = HistorySearch.search("ubuntu", in: entries, limit: 10, now: now)
                try expect(m.count == 2)
                try expect(m[0].entry.id.uuidString == entries[1].id.uuidString, "Newer entry ranks first under decay")
            }

            TestHarness.test("Limit caps result count") {
                let entries = (0..<10).map { i in
                    fixture(id: "e\(i)", filename: "ubuntu-\(i).iso")
                }
                let m = HistorySearch.search("ubuntu", in: entries, limit: 3, now: now)
                try expect(m.count == 3, "Limit honoured, got \(m.count)")
            }

            TestHarness.test("Tokenizer drops punctuation + length-1 tokens + stopwords") {
                let toks = HistorySearch.tokenize("Find me ALL the macOS-26 .iso files!")
                // Filter is `count > 1` (length-1 tokens dropped) + stopword filter.
                // "find", "all", "the" are stopwords → dropped.
                // "me" passes (len 2, not in stopwords).  "macos", "26", "iso", "files" pass.
                try expect(toks == ["me", "macos", "26", "iso", "files"], "Got \(toks)")
            }

            TestHarness.test("Recency floor prevents zero-collapse on ancient entries") {
                let ancient = now.addingTimeInterval(-1000 * 365 * 86400)  // 1000 years
                let r = HistorySearch.recencyScore(ancient, now: now)
                try expect(r >= 0.05, "Floor enforced, got \(r)")
            }
        }
    }

    // MARK: - Fixtures

    static func fixture(
        id: String,
        filename: String,
        url: String? = nil,
        finishedAt: Date = Date(timeIntervalSince1970: 1_800_000_000)
    ) -> HistoryEntry {
        let computedURL = url ?? "https://test/\(id)"
        return HistoryEntry(
            id: UUID(uuidString: zeroPad(id)) ?? UUID(),
            url: computedURL,
            filename: filename,
            outputPath: "/tmp/\(filename)",
            totalBytes: 1_000_000,
            bytesPerInterface: ["en0": 1_000_000],
            startedAt: finishedAt.addingTimeInterval(-60),
            finishedAt: finishedAt,
            sha256: nil,
            secondsSaved: nil
        )
    }

    /// Deterministic-uuid helper — pads `id` so we get stable UUIDs
    /// across runs, useful for assertions that compare entry identity.
    static func zeroPad(_ s: String) -> String {
        let hex = s.unicodeScalars.map { String(format: "%02x", $0.value) }.joined()
        let padded = (hex + String(repeating: "0", count: 32)).prefix(32)
        let chars = Array(padded)
        return "\(String(chars[0..<8]))-\(String(chars[8..<12]))-\(String(chars[12..<16]))-\(String(chars[16..<20]))-\(String(chars[20..<32]))"
    }
}
