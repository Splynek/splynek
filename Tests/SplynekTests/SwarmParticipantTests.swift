import Foundation
@testable import SplynekCore

/// v1.9.3: SwarmParticipant pure-logic invariants.  The wire-call
/// integration (full pull-flow against a real seeder) needs a
/// URLProtocol mock or a localhost-listener fixture; that's the
/// v1.9.4 work.  These tests cover the deterministic surface:
/// SHA-256 verification, URL construction, default-picker logic,
/// peer-token uniqueness.
enum SwarmParticipantTests {

    static func run() {
        TestHarness.suite("SwarmParticipant — verify") {

            TestHarness.test("Bytes matching expected digest verify ok") {
                let bytes = Data("hello".utf8)
                // SHA-256("hello") = 2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824
                let digest = "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
                try expect(SwarmParticipant.verify(bytes: bytes, expectedDigest: digest))
            }

            TestHarness.test("Mismatch returns false") {
                let bytes = Data("hello".utf8)
                let wrong = String(repeating: "0", count: 64)
                try expect(!SwarmParticipant.verify(bytes: bytes, expectedDigest: wrong))
            }

            TestHarness.test("Verification is case-insensitive on the expected digest") {
                let bytes = Data("hello".utf8)
                let digest = "2CF24DBA5FB0A30E26E83B2AC5B9E29E1B161E5C1FA7425E73043362938B9824"
                try expect(SwarmParticipant.verify(bytes: bytes, expectedDigest: digest))
            }

            TestHarness.test("Empty bytes match the empty-input SHA-256") {
                let empty = Data()
                let digest = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
                try expect(SwarmParticipant.verify(bytes: empty, expectedDigest: digest))
            }
        }

        TestHarness.suite("SwarmParticipant — URL construction") {

            TestHarness.test("endpointBase strips path + query from manifestURL") {
                let manifest = URL(string: "http://10.0.0.5:8080/splynek/v1/swarm/abc/manifest?t=tok")!
                let p = SwarmParticipant(manifestURL: manifest, token: "tok")
                try expect(p.endpointBase.absoluteString == "http://10.0.0.5:8080",
                           "Got endpointBase=\(p.endpointBase.absoluteString)")
            }

            TestHarness.test("Token is preserved separately from manifest URL's t= param") {
                let manifest = URL(string: "http://x.local:9090/manifest?t=overridden")!
                let p = SwarmParticipant(manifestURL: manifest, token: "real-token")
                try expect(p.token == "real-token")
            }

            TestHarness.test("peerToken defaults to a unique random string") {
                let manifest = URL(string: "http://x.local/manifest")!
                let a = SwarmParticipant(manifestURL: manifest, token: "tok")
                let b = SwarmParticipant(manifestURL: manifest, token: "tok")
                try expect(a.peerToken != b.peerToken,
                           "Got duplicate peer tokens: \(a.peerToken) / \(b.peerToken)")
                try expect(a.peerToken.hasPrefix("peer-"))
            }

            TestHarness.test("peerToken can be overridden for testability") {
                let manifest = URL(string: "http://x.local/manifest")!
                let p = SwarmParticipant(
                    manifestURL: manifest,
                    token: "tok",
                    peerToken: "deterministic"
                )
                try expect(p.peerToken == "deterministic")
            }
        }

        TestHarness.suite("SwarmParticipant — default picker") {

            TestHarness.test("Default picker returns chunks the seeder has minus alreadyHave") {
                let manifest = makeManifest(
                    chunks: 5,
                    seederHas: [0, 1, 2, 3]
                )
                let picked = SwarmParticipant.defaultPicker(manifest, [1, 3])
                try expect(picked == [0, 2], "Got \(picked)")
            }

            TestHarness.test("Default picker returns empty when alreadyHave covers seeder set") {
                let manifest = makeManifest(chunks: 3, seederHas: [0, 1])
                let picked = SwarmParticipant.defaultPicker(manifest, [0, 1])
                try expect(picked.isEmpty)
            }

            TestHarness.test("Default picker returns sorted indices") {
                let manifest = makeManifest(chunks: 6, seederHas: [5, 0, 3, 1])
                let picked = SwarmParticipant.defaultPicker(manifest, [])
                try expect(picked == [0, 1, 3, 5], "Got \(picked)")
            }
        }

        TestHarness.suite("SwarmParticipant — error reporting") {

            TestHarness.test("Pulling against an unreachable endpoint returns fatalError") {
                // Use a port we're sure isn't listening.  URLSession will
                // refuse the connection within the 10s manifest timeout.
                let manifest = URL(string: "http://127.0.0.1:1/manifest")!
                let p = SwarmParticipant(
                    manifestURL: manifest,
                    token: "tok"
                )
                let summary = await p.pull(jobID: UUID(), sink: { _, _, _ in true })
                try expect(summary.fatalError != nil,
                           "Expected a fatalError on unreachable endpoint; got summary=\(summary)")
                try expect(summary.delivered.isEmpty)
            }
        }
    }

    // MARK: - Fixtures

    static func makeManifest(
        chunks: Int,
        seederHas: Set<Int>
    ) -> FleetChunkSwarm.Manifest {
        let refs = (0..<chunks).map { i in
            FleetChunkSwarm.ChunkRef(
                index: i,
                offset: Int64(i * 100),
                length: 100,
                digest: String(repeating: "0", count: 64)
            )
        }
        return FleetChunkSwarm.Manifest(
            protocolVersion: 1,
            jobID: UUID(),
            chunkSize: 100,
            chunks: refs,
            seederCompleted: seederHas
        )
    }
}
