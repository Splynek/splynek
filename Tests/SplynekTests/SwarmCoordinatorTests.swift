import Foundation
@testable import SplynekCore

/// v1.9: REST-handler invariants for SwarmCoordinator.  Tests bypass
/// the network layer entirely — they call `handle(path:method:body:
/// token:)` directly and inspect the typed `Response` value.  Pure
/// + deterministic.
enum SwarmCoordinatorTests {

    static func run() {
        TestHarness.suite("SwarmCoordinator — auth + routing") {

            TestHarness.test("Wrong token returns 401") {
                let coord = makeCoordinator()
                let r = coord.handle(
                    path: "/splynek/v1/swarm/announce?t=nope",
                    method: "POST",
                    body: Data(),
                    token: "nope"
                )
                if case .unauthorized = r { /* expected */ }
                else { try expect(false, "Expected unauthorized, got \(r)") }
            }

            TestHarness.test("Path outside the swarm prefix returns 404") {
                let coord = makeCoordinator()
                let r = coord.handle(
                    path: "/somewhere/else",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .notFound = r { /* expected */ }
                else { try expect(false, "Expected notFound, got \(r)") }
            }

            TestHarness.test("Garbled jobID returns 404") {
                let coord = makeCoordinator()
                let r = coord.handle(
                    path: "/splynek/v1/swarm/not-a-uuid/manifest",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .notFound = r { /* expected */ }
                else { try expect(false, "Expected notFound, got \(r)") }
            }
        }

        TestHarness.suite("SwarmCoordinator — household token (v1.9.7)") {

            TestHarness.test("Secondary token initially nil → only primary accepted") {
                let coord = makeCoordinator()
                let jid = UUID()
                coord.register(
                    jobID: jid,
                    chunks: makeChunks(count: 1),
                    chunkSize: 100,
                    seederCompleted: [0]
                )
                // primary OK
                let r1 = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: testToken
                )
                if case .ok = r1 { /* expected */ }
                else { try expect(false, "Primary token should pass, got \(r1)") }
                // anything else fails
                let r2 = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: "household-x"
                )
                if case .unauthorized = r2 { /* expected */ }
                else { try expect(false, "Other token should 401, got \(r2)") }
            }

            TestHarness.test("After setSecondaryToken, both pass") {
                let coord = makeCoordinator()
                coord.setSecondaryToken("household-x")
                let jid = UUID()
                coord.register(
                    jobID: jid,
                    chunks: makeChunks(count: 1),
                    chunkSize: 100,
                    seederCompleted: [0]
                )
                let r1 = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: testToken
                )
                let r2 = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: "household-x"
                )
                if case .ok = r1 { /* expected */ }
                else { try expect(false, "Primary should pass, got \(r1)") }
                if case .ok = r2 { /* expected */ }
                else { try expect(false, "Secondary should pass, got \(r2)") }
            }

            TestHarness.test("Wrong household token still 401s") {
                let coord = makeCoordinator()
                coord.setSecondaryToken("household-x")
                let jid = UUID()
                coord.register(
                    jobID: jid, chunks: makeChunks(count: 1),
                    chunkSize: 100, seederCompleted: [0]
                )
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: "wrong-household"
                )
                if case .unauthorized = r { /* expected */ }
                else { try expect(false, "Wrong household token should 401, got \(r)") }
            }

            TestHarness.test("Setting empty / nil clears the secondary") {
                let coord = makeCoordinator()
                coord.setSecondaryToken("household-x")
                coord.setSecondaryToken(nil)
                let jid = UUID()
                coord.register(
                    jobID: jid, chunks: makeChunks(count: 1),
                    chunkSize: 100, seederCompleted: [0]
                )
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: "household-x"
                )
                if case .unauthorized = r { /* expected */ }
                else { try expect(false, "Cleared secondary token must 401, got \(r)") }
            }

            TestHarness.test("Empty string is treated as cleared") {
                let coord = makeCoordinator()
                coord.setSecondaryToken("")
                let jid = UUID()
                coord.register(
                    jobID: jid, chunks: makeChunks(count: 1),
                    chunkSize: 100, seederCompleted: [0]
                )
                // An empty presented token must NOT match an empty
                // stored secondary — defensive against accidental
                // "no auth at all" passing through.
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jid)/manifest",
                    method: "GET", body: Data(), token: ""
                )
                if case .unauthorized = r { /* expected */ }
                else { try expect(false, "Empty token + cleared secondary must 401, got \(r)") }
            }

            TestHarness.test("/list still no-auth even with secondary configured") {
                let coord = makeCoordinator()
                coord.setSecondaryToken("household-x")
                let r = coord.handle(
                    path: "/splynek/v1/swarm/list",
                    method: "GET", body: Data(), token: "anything"
                )
                if case .ok = r { /* expected */ }
                else { try expect(false, "/list must remain no-auth, got \(r)") }
            }
        }

        TestHarness.suite("SwarmCoordinator — announce") {

            TestHarness.test("Valid announce body is acknowledged") {
                let coord = makeCoordinator()
                let announce = FleetChunkSwarm.Announce(
                    protocolVersion: 1,
                    jobID: UUID(),
                    contentDigest: String(repeating: "a", count: 64),
                    totalBytes: 1_000_000,
                    manifestURL: URL(string: "http://10.0.0.5:8080/m")!,
                    token: testToken
                )
                let body = try JSONEncoder().encode(announce)
                let r = coord.handle(
                    path: "/splynek/v1/swarm/announce",
                    method: "POST",
                    body: body,
                    token: testToken
                )
                if case .ok = r { /* expected */ }
                else { try expect(false, "Expected ok, got \(r)") }
            }

            TestHarness.test("Garbled announce body returns 400") {
                let coord = makeCoordinator()
                let r = coord.handle(
                    path: "/splynek/v1/swarm/announce",
                    method: "POST",
                    body: Data("not json".utf8),
                    token: testToken
                )
                if case .badRequest = r { /* expected */ }
                else { try expect(false, "Expected badRequest, got \(r)") }
            }

            TestHarness.test("GET on announce is method-not-allowed") {
                let coord = makeCoordinator()
                let r = coord.handle(
                    path: "/splynek/v1/swarm/announce",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .methodNotAllowed = r { /* expected */ }
                else { try expect(false, "Expected methodNotAllowed, got \(r)") }
            }
        }

        TestHarness.suite("SwarmCoordinator — manifest + chunks + contribute") {

            TestHarness.test("Manifest GET on unregistered job returns 404") {
                let coord = makeCoordinator()
                let unknown = UUID()
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(unknown)/manifest",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .notFound = r { /* expected */ }
                else { try expect(false, "Expected notFound, got \(r)") }
            }

            TestHarness.test("Register + manifest GET returns the manifest") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 4),
                    chunkSize: 100,
                    seederCompleted: [0]
                )
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/manifest",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                guard case .ok(let bodyData, let ct) = r else {
                    try expect(false, "Expected ok, got \(r)")
                    return
                }
                try expect(ct == "application/json")
                let manifest = try JSONDecoder().decode(
                    FleetChunkSwarm.Manifest.self, from: bodyData
                )
                try expect(manifest.jobID == jobID)
                try expect(manifest.chunks.count == 4)
                try expect(manifest.seederCompleted == [0])
            }

            TestHarness.test("Out-of-range chunk index returns 404") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 2),
                    chunkSize: 100,
                    seederCompleted: [0, 1]
                )
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/chunks/99",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .notFound = r { /* expected */ }
                else { try expect(false, "Expected notFound, got \(r)") }
            }

            TestHarness.test("Chunk fetch on incomplete index returns 404 (peer retries elsewhere)") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 4),
                    chunkSize: 100,
                    seederCompleted: []  // seeder hasn't pulled anything yet
                )
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/chunks/0",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .notFound = r { /* expected */ }
                else { try expect(false, "Expected notFound, got \(r)") }
            }

            TestHarness.test("Contribute records peer's claimed chunks") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 8),
                    chunkSize: 100,
                    seederCompleted: []
                )
                let offer = FleetChunkSwarm.ContributionOffer(
                    protocolVersion: 1,
                    jobID: jobID,
                    peerToken: "peer-A",
                    chunks: [3, 4, 5]
                )
                let body = try JSONEncoder().encode(offer)
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/contribute",
                    method: "POST",
                    body: body,
                    token: testToken
                )
                if case .ok = r { /* expected */ }
                else { try expect(false, "Expected ok, got \(r)") }

                // Verify the next-work-item logic now skips the offered chunks.
                let snapshot = coord.snapshot()
                try expect(snapshot.count == 1)
                let next = snapshot[0].nextSeederWorkItem()
                // Chunks 0/1/2/6/7 are still seeder-exclusive; 3/4/5 are claimed.
                try expect(next != 3 && next != 4 && next != 5,
                           "Should pick a non-claimed chunk; got \(String(describing: next))")
            }

            TestHarness.test("Mismatched offer jobID returns 400") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 2),
                    chunkSize: 100,
                    seederCompleted: []
                )
                let offer = FleetChunkSwarm.ContributionOffer(
                    protocolVersion: 1,
                    jobID: UUID(),                       // wrong UUID
                    peerToken: "peer",
                    chunks: [0]
                )
                let body = try JSONEncoder().encode(offer)
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/contribute",
                    method: "POST",
                    body: body,
                    token: testToken
                )
                if case .badRequest = r { /* expected */ }
                else { try expect(false, "Expected badRequest, got \(r)") }
            }

            TestHarness.test("Leave drops the peer's claimed chunks") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 4),
                    chunkSize: 100,
                    seederCompleted: []
                )
                // First contribute, then leave.
                let offer = FleetChunkSwarm.ContributionOffer(
                    protocolVersion: 1,
                    jobID: jobID,
                    peerToken: "X",
                    chunks: [0, 1]
                )
                _ = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/contribute",
                    method: "POST",
                    body: try JSONEncoder().encode(offer),
                    token: testToken
                )
                let leave = #"{"peerToken":"X"}"#
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/leave",
                    method: "POST",
                    body: Data(leave.utf8),
                    token: testToken
                )
                if case .ok = r { /* expected */ }
                else { try expect(false, "Expected ok, got \(r)") }

                // Snapshot should show no contributions remaining.
                let snapshot = coord.snapshot()
                try expect(snapshot[0].contributions.isEmpty)
            }

            TestHarness.test("Unregister removes the job") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 1),
                    chunkSize: 100,
                    seederCompleted: [0]
                )
                coord.unregister(jobID: jobID)
                let r = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/manifest",
                    method: "GET",
                    body: Data(),
                    token: testToken
                )
                if case .notFound = r { /* expected */ }
                else { try expect(false, "Expected notFound after unregister, got \(r)") }
            }

            TestHarness.test("markSeederCompleted updates manifest visibility") {
                let coord = makeCoordinator()
                let jobID = UUID()
                coord.register(
                    jobID: jobID,
                    chunks: makeChunks(count: 3),
                    chunkSize: 100,
                    seederCompleted: []
                )
                coord.markSeederCompleted(jobID: jobID, chunkIndex: 1)
                guard case .ok(let bodyData, _) = coord.handle(
                    path: "/splynek/v1/swarm/\(jobID)/manifest",
                    method: "GET",
                    body: Data(),
                    token: testToken
                ) else {
                    try expect(false, "Expected ok manifest")
                    return
                }
                let manifest = try JSONDecoder().decode(
                    FleetChunkSwarm.Manifest.self, from: bodyData
                )
                try expect(manifest.seederCompleted == [1])
            }
        }
    }

    // MARK: - Fixtures

    static let testToken = "test-token-deadbeef"

    static func makeCoordinator() -> SwarmCoordinator {
        SwarmCoordinator(
            token: testToken,
            payloadResolver: { _ in nil }
        )
    }

    static func makeChunks(count: Int) -> [FleetChunkSwarm.ChunkRef] {
        (0..<count).map { i in
            FleetChunkSwarm.ChunkRef(
                index: i,
                offset: Int64(i * 100),
                length: 100,
                digest: String(repeating: "0", count: 64)
            )
        }
    }
}
