import Foundation
@testable import SplynekCore

/// v1.7.x: contract tests for `AtomicFlag` — the resettable
/// boolean primitive `DownloadEngine` uses to signal "interface
/// set flipped, exit `runWorkers` cleanly so we can re-spawn
/// fresh lanes."  Distinct from `CancelFlag` (one-shot, with
/// handler registry); the engine needs `set` / `clear` /
/// `isSet` repeatedly across path-flip restarts.
enum AtomicFlagTests {

    static func run() {
        TestHarness.suite("AtomicFlag — single-thread") {

            TestHarness.test("Initial state is cleared") {
                let f = AtomicFlag()
                try expect(!f.isSet)
            }

            TestHarness.test("set() flips to true") {
                let f = AtomicFlag()
                f.set()
                try expect(f.isSet)
            }

            TestHarness.test("clear() resets to false") {
                let f = AtomicFlag()
                f.set()
                f.clear()
                try expect(!f.isSet)
            }

            TestHarness.test("set + clear cycle is repeatable") {
                let f = AtomicFlag()
                for _ in 0..<5 {
                    f.set()
                    try expect(f.isSet)
                    f.clear()
                    try expect(!f.isSet)
                }
            }

            TestHarness.test("Idempotent set + idempotent clear") {
                let f = AtomicFlag()
                f.set(); f.set(); f.set()
                try expect(f.isSet)
                f.clear(); f.clear()
                try expect(!f.isSet)
            }
        }

        TestHarness.suite("AtomicFlag — concurrent set/clear") {

            TestHarness.test("Many concurrent setters + observers don't crash") {
                // Coarse smoke test: spawn 32 setters + 32 clearers
                // racing against each other while a reader polls.
                // We're not asserting on a final value (race), only
                // that the lock path doesn't deadlock or crash.
                let f = AtomicFlag()
                let g = DispatchGroup()
                let q = DispatchQueue(label: "atomic-flag-test", attributes: .concurrent)
                for _ in 0..<32 {
                    g.enter()
                    q.async { for _ in 0..<100 { f.set() }; g.leave() }
                    g.enter()
                    q.async { for _ in 0..<100 { f.clear() }; g.leave() }
                    g.enter()
                    q.async { for _ in 0..<100 { _ = f.isSet }; g.leave() }
                }
                let timeout = g.wait(timeout: .now() + 5)
                try expect(timeout == .success,
                    "Concurrent set/clear/read locked up — likely a missing unlock")
            }
        }
    }
}
