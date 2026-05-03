import Foundation
@testable import SplynekCore

/// v1.9.4: SwarmHooks struct invariants.  We don't run a full
/// DownloadEngine here (that requires a live HTTP server, sidecar
/// state, etc.) — instead we validate the hooks struct's contract:
///   - `.none` is constructable + all closures are nil
///   - hooks pass through arguments verbatim
///   - the struct is value-typed + Sendable so it can hop actors
///
/// The actual "engine fires hooks at lifecycle points" coverage
/// happens at integration time — this suite locks down the contract
/// the engine + VM rely on.
enum SwarmHooksTests {

    static func run() {
        TestHarness.suite("SwarmHooks") {

            TestHarness.test(".none has all nil closures") {
                let hooks = SwarmHooks.none
                try expect(hooks.register == nil)
                try expect(hooks.chunkCompleted == nil)
                try expect(hooks.finished == nil)
            }

            TestHarness.test("Register hook is invoked with verbatim arguments") {
                final class Capture: @unchecked Sendable {
                    var calls: [(UUID, [FleetChunkSwarm.ChunkRef], Int64, Set<Int>)] = []
                }
                let cap = Capture()
                let hooks = SwarmHooks(
                    register: { jid, refs, size, completed in
                        cap.calls.append((jid, refs, size, completed))
                    }
                )
                let jid = UUID()
                let refs = [
                    FleetChunkSwarm.ChunkRef(index: 0, offset: 0, length: 100, digest: "x"),
                    FleetChunkSwarm.ChunkRef(index: 1, offset: 100, length: 50, digest: "y"),
                ]
                hooks.register?(jid, refs, 100, Set([0]))
                try expect(cap.calls.count == 1)
                try expect(cap.calls[0].0 == jid)
                try expect(cap.calls[0].1.count == 2)
                try expect(cap.calls[0].2 == 100)
                try expect(cap.calls[0].3 == Set([0]))
            }

            TestHarness.test("ChunkCompleted hook fires with index") {
                final class Capture: @unchecked Sendable {
                    var indices: [Int] = []
                }
                let cap = Capture()
                let hooks = SwarmHooks(
                    chunkCompleted: { _, idx in cap.indices.append(idx) }
                )
                hooks.chunkCompleted?(UUID(), 3)
                hooks.chunkCompleted?(UUID(), 7)
                hooks.chunkCompleted?(UUID(), 0)
                try expect(cap.indices == [3, 7, 0])
            }

            TestHarness.test("Finished hook can carry digest or nil") {
                final class Capture: @unchecked Sendable {
                    var digests: [String?] = []
                }
                let cap = Capture()
                let hooks = SwarmHooks(
                    finished: { _, digest in cap.digests.append(digest) }
                )
                hooks.finished?(UUID(), "abc123")
                hooks.finished?(UUID(), nil)
                try expect(cap.digests.count == 2)
                try expect(cap.digests[0] == "abc123")
                try expect(cap.digests[1] == nil)
            }
        }

        // NOTE: integration tests against DownloadEngine + DownloadJob
        // are deliberately omitted from this suite.  Both types' inits
        // are @MainActor, and the harness's async-test helper blocks
        // the main thread on a DispatchSemaphore — so any
        // `await MainActor.run { … }` body deadlocks.  The struct
        // contract above is what the engine + job depend on; the
        // wiring is exercised at runtime.
    }
}
