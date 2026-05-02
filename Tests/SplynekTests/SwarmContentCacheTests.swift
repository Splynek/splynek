import Foundation
@testable import SplynekCore

/// v1.9.2: SwarmContentCache invariants.  Tests build temp files +
/// inject HistoryEntry fixtures so we don't touch the real
/// `~/Library/Application Support/Splynek/history.json`.
enum SwarmContentCacheTests {

    static func run() {
        TestHarness.suite("SwarmContentCache") {

            TestHarness.test("Empty refresh produces empty cache") {
                let cache = SwarmContentCache()
                cache.refresh(history: [])
                try expect(cache.count == 0)
            }

            TestHarness.test("Refresh indexes entries with sha256 + existing file") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url1 = env.makeFile(name: "a.bin", bytes: 100)
                let url2 = env.makeFile(name: "b.bin", bytes: 200)
                let entries = [
                    fixture(url: url1, sha256: "AAAA"),
                    fixture(url: url2, sha256: "BBBB"),
                ]
                let cache = SwarmContentCache()
                cache.refresh(history: entries)
                try expect(cache.count == 2)
                try expect(cache.url(forDigest: "aaaa") == url1)
                try expect(cache.url(forDigest: "BBBB") == url2)
            }

            TestHarness.test("Refresh skips entries without sha256") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "x.bin", bytes: 50)
                let cache = SwarmContentCache()
                cache.refresh(history: [fixture(url: url, sha256: nil)])
                try expect(cache.count == 0)
            }

            TestHarness.test("Refresh skips entries whose file is gone") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "stale.bin", bytes: 50)
                let entries = [fixture(url: url, sha256: "DEADBEEF")]
                try? FileManager.default.removeItem(at: url)

                let cache = SwarmContentCache()
                cache.refresh(history: entries)
                try expect(cache.count == 0)
            }

            TestHarness.test("Lookup re-checks file presence + evicts stale") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "ephemeral.bin", bytes: 50)
                let cache = SwarmContentCache()
                cache.refresh(history: [fixture(url: url, sha256: "CAFE")])
                try expect(cache.url(forDigest: "cafe") == url)

                // User deletes the file mid-session.
                try? FileManager.default.removeItem(at: url)
                try expect(cache.url(forDigest: "cafe") == nil)
                try expect(cache.count == 0, "Stale entry should have been evicted")
            }

            TestHarness.test("Record adds without full refresh") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "fresh.bin", bytes: 100)
                let cache = SwarmContentCache()
                cache.record(fixture(url: url, sha256: "BEEF"))
                try expect(cache.count == 1)
                try expect(cache.url(forDigest: "beef") == url)
            }

            TestHarness.test("Record skips entries without sha256") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "no-digest.bin", bytes: 100)
                let cache = SwarmContentCache()
                cache.record(fixture(url: url, sha256: nil))
                try expect(cache.count == 0)
            }

            TestHarness.test("Remove drops a digest") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "a.bin", bytes: 100)
                let cache = SwarmContentCache()
                cache.record(fixture(url: url, sha256: "AAAA"))
                cache.remove(digest: "AAAA")
                try expect(cache.url(forDigest: "aaaa") == nil)
                try expect(cache.count == 0)
            }

            TestHarness.test("Digest lookup is case-insensitive") {
                let env = makeEnv()
                defer { env.cleanup() }

                let url = env.makeFile(name: "a.bin", bytes: 100)
                let cache = SwarmContentCache()
                cache.record(fixture(url: url, sha256: "MixedCase1234"))
                try expect(cache.url(forDigest: "mixedcase1234") != nil)
                try expect(cache.url(forDigest: "MIXEDCASE1234") != nil)
                try expect(cache.url(forDigest: "MixedCase1234") != nil)
            }
        }

        TestHarness.suite("SwarmCoordinator — content cache fallback") {

            TestHarness.test("Chunk fetch falls back to cache when activeJob resolver returns nil") {
                let env = SwarmContentCacheTests.makeEnv()
                defer { env.cleanup() }

                // Build a file with predictable bytes so we can verify the
                // chunk slice came back correctly.
                let url = env.workdir.appendingPathComponent("payload.bin")
                let data = Data((0..<1000).map { UInt8($0 & 0xFF) })
                try data.write(to: url)
                let digest = "feedface"

                let cache = SwarmContentCache()
                cache.record(fixture(url: url, sha256: digest))

                let coord = SwarmCoordinator(
                    token: "tok",
                    payloadResolver: { _ in nil }  // active-job resolver always misses
                )
                coord.setContentCache(cache)

                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: [FleetChunkSwarm.ChunkRef(
                        index: 0, offset: 100, length: 50,
                        digest: String(repeating: "0", count: 64)
                    )],
                    chunkSize: 50,
                    seederCompleted: [0],
                    contentDigest: digest
                )

                let response = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/chunks/0",
                    method: "GET",
                    body: Data(),
                    token: "tok"
                )
                guard case .ok(let bytes, _) = response else {
                    try expect(false, "Expected ok, got \(response)")
                    return
                }
                try expect(bytes.count == 50, "Got \(bytes.count) bytes; expected 50")
                // The chunk we asked for is offset 100, length 50 → bytes [100..150).
                let expectedFirst = UInt8(100 & 0xFF)
                try expect(bytes.first == expectedFirst, "Wrong byte at offset 100")
            }
        }
    }

    // MARK: - Fixtures

    struct Env {
        let workdir: URL
        let cleanup: () -> Void
        func makeFile(name: String, bytes: Int) -> URL {
            let url = workdir.appendingPathComponent(name)
            try? Data(repeating: 0xAB, count: bytes).write(to: url)
            return url
        }
    }

    static func makeEnv() -> Env {
        let fm = FileManager.default
        let root = fm.temporaryDirectory
            .appendingPathComponent("splynek-swarm-cache-\(UUID())")
        try? fm.createDirectory(at: root, withIntermediateDirectories: true)
        return Env(workdir: root, cleanup: { try? fm.removeItem(at: root) })
    }

    static func fixture(url: URL, sha256: String?) -> HistoryEntry {
        let bytes = (try? Data(contentsOf: url).count) ?? 0
        return HistoryEntry(
            id: UUID(),
            url: "https://example.com/file",
            filename: url.lastPathComponent,
            outputPath: url.path,
            totalBytes: Int64(bytes),
            bytesPerInterface: ["en0": Int64(bytes)],
            startedAt: Date().addingTimeInterval(-60),
            finishedAt: Date(),
            sha256: sha256,
            secondsSaved: nil
        )
    }
}
