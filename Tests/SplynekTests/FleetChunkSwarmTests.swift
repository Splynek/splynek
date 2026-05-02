import Foundation
@testable import SplynekCore

/// v1.9: wire-format invariants for the chunk-swarm protocol.  Tests
/// the pure scheduling logic + Codable round-trip without spinning up
/// any real network listener.
enum FleetChunkSwarmTests {

    static func run() {
        TestHarness.suite("FleetChunkSwarm — wire types") {

            TestHarness.test("Announce round-trips through Codable") {
                let original = FleetChunkSwarm.Announce(
                    protocolVersion: FleetChunkSwarm.protocolVersion,
                    jobID: UUID(),
                    contentDigest: String(repeating: "a", count: 64),
                    totalBytes: 1_000_000_000,
                    manifestURL: URL(string: "http://10.0.0.5:8080/fleet/swarm/123/manifest")!,
                    token: "deadbeef"
                )
                let data = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(FleetChunkSwarm.Announce.self, from: data)
                try expect(decoded == original, "Round-trip mismatch")
            }

            TestHarness.test("Manifest round-trips through Codable") {
                let original = FleetChunkSwarm.Manifest(
                    protocolVersion: FleetChunkSwarm.protocolVersion,
                    jobID: UUID(),
                    chunkSize: 1_048_576,
                    chunks: [
                        FleetChunkSwarm.ChunkRef(index: 0, offset: 0, length: 1_048_576, digest: "00"),
                        FleetChunkSwarm.ChunkRef(index: 1, offset: 1_048_576, length: 1_048_576, digest: "11"),
                    ],
                    seederCompleted: [0]
                )
                let data = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(FleetChunkSwarm.Manifest.self, from: data)
                try expect(decoded == original)
            }

            TestHarness.test("Protocol version is stable") {
                try expect(FleetChunkSwarm.protocolVersion == 1, "Bump deliberate? update tests")
            }
        }

        TestHarness.suite("FleetChunkSwarm — scheduler") {

            TestHarness.test("nextSeederWorkItem prefers exclusive work") {
                // 4 chunks; peer A has offered to fetch chunk 1, peer B
                // already holds chunk 2. Seeder should pick chunk 0
                // (no peer contention) before chunks 1 or 2.
                let manifest = FleetChunkSwarm.Manifest(
                    protocolVersion: 1,
                    jobID: UUID(),
                    chunkSize: 100,
                    chunks: (0..<4).map {
                        FleetChunkSwarm.ChunkRef(index: $0, offset: Int64($0 * 100), length: 100, digest: "x")
                    },
                    seederCompleted: []
                )
                let state = FleetChunkSwarm.State(
                    jobID: manifest.jobID,
                    manifest: manifest,
                    contributions: ["peerA": [1]],
                    peerHoldings: ["peerB": [2]]
                )
                let next = state.nextSeederWorkItem()
                try expect(next == 0, "Seeder should pick chunk 0 (exclusive work), got \(String(describing: next))")
            }

            TestHarness.test("nextSeederWorkItem falls back when nothing is exclusive") {
                let manifest = FleetChunkSwarm.Manifest(
                    protocolVersion: 1,
                    jobID: UUID(),
                    chunkSize: 100,
                    chunks: (0..<2).map {
                        FleetChunkSwarm.ChunkRef(index: $0, offset: Int64($0 * 100), length: 100, digest: "x")
                    },
                    seederCompleted: []
                )
                let state = FleetChunkSwarm.State(
                    jobID: manifest.jobID,
                    manifest: manifest,
                    contributions: ["peer1": [0, 1]],
                    peerHoldings: [:]
                )
                let next = state.nextSeederWorkItem()
                // Both chunks are claimed by a peer; fall back to picking any
                // incomplete chunk.
                try expect(next == 0 || next == 1, "Fallback should still return a chunk, got \(String(describing: next))")
            }

            TestHarness.test("nextSeederWorkItem returns nil when seeder is done") {
                let manifest = FleetChunkSwarm.Manifest(
                    protocolVersion: 1,
                    jobID: UUID(),
                    chunkSize: 100,
                    chunks: (0..<3).map {
                        FleetChunkSwarm.ChunkRef(index: $0, offset: Int64($0 * 100), length: 100, digest: "x")
                    },
                    seederCompleted: [0, 1, 2]
                )
                let state = FleetChunkSwarm.State(
                    jobID: manifest.jobID,
                    manifest: manifest,
                    contributions: [:],
                    peerHoldings: [:]
                )
                try expect(state.nextSeederWorkItem() == nil)
            }
        }
    }
}
