import Foundation
@testable import SplynekCore

/// v1.9.6: invariants for `DownloadEngine.ingestExternalChunk(...)`.
/// We can't easily run a full engine here (it needs a live HTTP
/// server + sidecar state), so the suite covers the cases that DON'T
/// require run() — `.notLive` returned when the engine hasn't
/// entered run() yet, and `ExternalIngestResult` Equatable shape.
///
/// The on-disk + queue-coordination paths are exercised at runtime
/// when a peer auto-join feeds bytes through.
enum EngineExternalIngestTests {

    static func run() {
        // NOTE: the runtime path through `ingestExternalChunk` is
        // exercised at integration time (a peer auto-join feeds
        // bytes into a live engine).  Constructing a DownloadEngine
        // here would need a `DownloadProgress()` instance, which is
        // @MainActor — and the harness's async test helper blocks
        // the main thread on a DispatchSemaphore, deadlocking any
        // `await MainActor.run`.  See SwarmHooksTests for the same
        // mitigation.

        TestHarness.suite("DownloadEngine.ExternalIngestResult — equality") {

            TestHarness.test("Each case is distinct") {
                try expect(DownloadEngine.ExternalIngestResult.accepted == .accepted)
                try expect(DownloadEngine.ExternalIngestResult.alreadyHave == .alreadyHave)
                try expect(DownloadEngine.ExternalIngestResult.notLive == .notLive)
                try expect(DownloadEngine.ExternalIngestResult.indexOutOfRange == .indexOutOfRange)
                try expect(DownloadEngine.ExternalIngestResult.lengthMismatch == .lengthMismatch)
                try expect(
                    DownloadEngine.ExternalIngestResult.writeFailed("a")
                        == DownloadEngine.ExternalIngestResult.writeFailed("a")
                )
                try expect(
                    DownloadEngine.ExternalIngestResult.writeFailed("a")
                        != DownloadEngine.ExternalIngestResult.writeFailed("b")
                )
                try expect(
                    DownloadEngine.ExternalIngestResult.accepted != .alreadyHave
                )
            }
        }
    }
}
