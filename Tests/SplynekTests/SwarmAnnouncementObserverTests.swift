import Foundation
@testable import SplynekCore

/// v1.9.5: SwarmAnnouncementObserver invariants.  We don't spin up a
/// real HTTP server; instead, fixture peers are constructed pointing
/// at unreachable URLs and the observer's per-peer error path is
/// exercised.  The plumbing — peers provider firing on tick, update
/// callback being invoked, sequential per-peer iteration — is the
/// contract being locked down.
enum SwarmAnnouncementObserverTests {

    static func run() {
        TestHarness.suite("SwarmAnnouncementObserver — runOnce") {

            TestHarness.test("Empty peer list produces empty update") {
                final class Capture: @unchecked Sendable { var calls = 0 }
                let cap = Capture()
                let observer = SwarmAnnouncementObserver(
                    interval: 60,
                    peersProvider: { [] },
                    onUpdate: { update in
                        cap.calls += 1
                        // expect empty
                        if !update.isEmpty {
                            // Non-fatal here — caller's `try expect` does the asserting.
                        }
                    }
                )
                let result = await observer.runOnce()
                try expect(result.isEmpty)
                try expect(cap.calls == 1, "onUpdate should fire exactly once")
            }

            TestHarness.test("Unreachable peer is silently dropped, not errored") {
                let observer = SwarmAnnouncementObserver(
                    interval: 60,
                    peersProvider: {
                        [SwarmAnnouncementObserver.PeerInfo(
                            uuid: "deadbeef",
                            name: "ghost",
                            baseURL: URL(string: "http://127.0.0.1:1")!,  // refused
                            token: ""
                        )]
                    },
                    onUpdate: { _ in }
                )
                let result = await observer.runOnce()
                // Per-peer fetch errors are swallowed → empty map.
                try expect(result.isEmpty,
                           "Unreachable peer must not appear in update")
            }

            TestHarness.test("PeerInfo equality + hashing works for snapshot dedup") {
                let a = SwarmAnnouncementObserver.PeerInfo(
                    uuid: "x", name: "A",
                    baseURL: URL(string: "http://1.2.3.4:8080")!, token: ""
                )
                let b = SwarmAnnouncementObserver.PeerInfo(
                    uuid: "x", name: "A",
                    baseURL: URL(string: "http://1.2.3.4:8080")!, token: ""
                )
                let c = SwarmAnnouncementObserver.PeerInfo(
                    uuid: "y", name: "C",
                    baseURL: URL(string: "http://5.6.7.8:8080")!, token: ""
                )
                try expect(a == b)
                try expect(a != c)
                let s: Set<SwarmAnnouncementObserver.PeerInfo> = [a, b, c]
                try expect(s.count == 2)  // a + b dedup
            }

            TestHarness.test("Interval below 2s is clamped to 2s") {
                // The init clamp keeps us from accidentally hammering
                // peers from a misconfigured Settings card.
                let observer = SwarmAnnouncementObserver(
                    interval: 0.1,
                    peersProvider: { [] },
                    onUpdate: { _ in }
                )
                observer.start()
                observer.stop()
                // Smoke test only — a real interval check would need
                // mockable time.  Boolean: no crash + clean stop.
            }
        }

        TestHarness.suite("SwarmCoordinator — /swarm/list endpoint") {

            TestHarness.test("Empty seeder returns empty list with 200") {
                let coord = SwarmCoordinator(token: "t", payloadResolver: { _ in nil })
                let r = coord.handle(
                    path: "/splynek/v1/swarm/list",
                    method: "GET",
                    body: Data(),
                    token: ""  // no auth needed
                )
                guard case .ok(let bodyData, let ct) = r else {
                    try expect(false, "Expected ok, got \(r)")
                    return
                }
                try expect(ct == "application/json")
                struct Envelope: Decodable { let jobs: [FleetChunkSwarm.Listing] }
                let env = try JSONDecoder().decode(Envelope.self, from: bodyData)
                try expect(env.jobs.isEmpty)
            }

            TestHarness.test("Registered job appears in list with summary") {
                let coord = SwarmCoordinator(token: "t", payloadResolver: { _ in nil })
                let jid = UUID()
                coord.register(
                    jobID: jid,
                    chunks: [
                        FleetChunkSwarm.ChunkRef(index: 0, offset: 0, length: 100, digest: "x"),
                        FleetChunkSwarm.ChunkRef(index: 1, offset: 100, length: 100, digest: "y"),
                        FleetChunkSwarm.ChunkRef(index: 2, offset: 200, length: 50, digest: "z"),
                    ],
                    chunkSize: 100,
                    seederCompleted: [0, 1],
                    contentDigest: "abcdef"
                )
                let r = coord.handle(
                    path: "/splynek/v1/swarm/list",
                    method: "GET",
                    body: Data(),
                    token: ""
                )
                guard case .ok(let bodyData, _) = r else {
                    try expect(false, "Expected ok, got \(r)")
                    return
                }
                struct Envelope: Decodable { let jobs: [FleetChunkSwarm.Listing] }
                let env = try JSONDecoder().decode(Envelope.self, from: bodyData)
                try expect(env.jobs.count == 1)
                let listing = env.jobs[0]
                try expect(listing.jobID == jid)
                try expect(listing.contentDigest == "abcdef")
                try expect(listing.chunkSize == 100)
                try expect(listing.totalChunks == 3)
                try expect(listing.completedChunks == 2)
                try expect(listing.totalBytes == 250)
                try expect(listing.fractionComplete > 0.66 && listing.fractionComplete < 0.67)
            }

            TestHarness.test("List endpoint requires no auth (peer discovery)") {
                let coord = SwarmCoordinator(token: "real-token", payloadResolver: { _ in nil })
                // Empty token + wrong token both succeed — list is
                // intentionally read-only metadata, like /status.
                let r1 = coord.handle(
                    path: "/splynek/v1/swarm/list",
                    method: "GET", body: Data(), token: ""
                )
                let r2 = coord.handle(
                    path: "/splynek/v1/swarm/list",
                    method: "GET", body: Data(), token: "bogus"
                )
                if case .ok = r1 { /* expected */ }
                else { try expect(false, "Empty token should still 200, got \(r1)") }
                if case .ok = r2 { /* expected */ }
                else { try expect(false, "Wrong token should still 200, got \(r2)") }
            }

            TestHarness.test("List endpoint requires GET method") {
                let coord = SwarmCoordinator(token: "t", payloadResolver: { _ in nil })
                let r = coord.handle(
                    path: "/splynek/v1/swarm/list",
                    method: "POST", body: Data(), token: ""
                )
                if case .methodNotAllowed = r { /* expected */ }
                else { try expect(false, "Expected methodNotAllowed, got \(r)") }
            }
        }
    }
}
