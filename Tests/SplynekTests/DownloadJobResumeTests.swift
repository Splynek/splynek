import Foundation
@testable import SplynekCore

/// Regression tests for `DownloadJob.resume()` — the resume button
/// path.  The original guard read `guard !lifecycle.isActive else
/// return`, but `Lifecycle.isActive` is true for both `.running` AND
/// `.paused`, so the guard silently no-op'd on the exact state the
/// method is supposed to handle.  The bug had been there since v0.31
/// (initial public commit) — UI resume button never worked, and S2's
/// auto-resume on Wi-Fi-back-online hit the same wall.
///
/// These tests are synchronous + use `MainActor.assumeIsolated`
/// because DownloadJob's init + lifecycle are @MainActor.  See
/// `EngineExternalIngestTests` and `ConciergeTranscriptStoreTests`
/// for the same mitigation around the harness's main-thread
/// DispatchSemaphore wait.
enum DownloadJobResumeTests {

    static func run() {
        TestHarness.suite("DownloadJob.resume — guard contract") {

            TestHarness.test("Paused job → resume flips lifecycle to .running") {
                try MainActor.assumeIsolated {
                    let job = makeJob()
                    job.lifecycle = .paused
                    job.resume { _ in }
                    try expectEqual(job.lifecycle, .running,
                        "Resume must transition .paused → .running synchronously")
                    job.cancel()  // tear down the spawned engine task
                }
            }

            TestHarness.test("Failed job → resume flips lifecycle to .running") {
                // The resume button shows "Retry" for .failed; same path.
                try MainActor.assumeIsolated {
                    let job = makeJob()
                    job.lifecycle = .failed
                    job.resume { _ in }
                    try expectEqual(job.lifecycle, .running,
                        "Resume from .failed (Retry) must also transition to .running")
                    job.cancel()
                }
            }

            TestHarness.test("Running job → resume is a no-op (guards against double-start)") {
                try MainActor.assumeIsolated {
                    let job = makeJob()
                    job.lifecycle = .running
                    job.resume { _ in }
                    try expectEqual(job.lifecycle, .running,
                        "Resume on already-running job must not re-enter start()")
                }
            }

            TestHarness.test("Completed / cancelled / pending → resume is a no-op") {
                // The resume button isn't shown for these states (see
                // DownloadView.actionButtons), but the resume() method
                // is also called from VM.handlePathEvent on Wi-Fi
                // restore — defensively ignore states that aren't the
                // explicit resume targets.
                try MainActor.assumeIsolated {
                    for state: DownloadJob.Lifecycle in [.completed, .cancelled, .pending] {
                        let job = makeJob()
                        job.lifecycle = state
                        job.resume { _ in }
                        try expectEqual(job.lifecycle, state,
                            "Resume must not change lifecycle from \(state)")
                    }
                }
            }
        }
    }

    @MainActor
    private static func makeJob() -> DownloadJob {
        DownloadJob(
            url: URL(string: "https://example.invalid/file.iso")!,
            outputURL: URL(fileURLWithPath: "/tmp/splynek-test-resume.iso"),
            interfaces: [],
            sha256Expected: nil,
            connectionsPerInterface: 1,
            useDoH: false,
            merkleManifest: nil,
            extraHeaders: [:]
        )
    }
}
