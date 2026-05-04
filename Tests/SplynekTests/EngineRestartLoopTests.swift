import Foundation
@testable import SplynekCore

/// v1.7.x: contract tests for `DownloadEngine.decideRestartLoopOutcome`,
/// the pure decision predicate the run() restart loop calls at each
/// iteration to decide between exiting (cancelled / complete / no
/// flip / max-attempts) and continuing (restart with fresh lanes).
///
/// The actual `runWorkers` integration with `pathRestartFlag` is
/// exercised at runtime when `PathMonitorObserver` reports an
/// interface-set flip; these tests cover the decision logic in
/// isolation so a refactor of the run loop's branching can't drift
/// silently from the intended semantics.
enum EngineRestartLoopTests {

    static func run() {
        TestHarness.suite("DownloadEngine.decideRestartLoopOutcome — exit predicates") {

            TestHarness.test("Cancelled wins: cancelled=true → completeOrCancelled regardless of other inputs") {
                // Cancelled is the highest-priority exit reason.
                // Every other input combination should still resolve
                // to completeOrCancelled when cancelled is true.
                let combos: [(allDone: Bool, flag: Bool, attempts: Int)] = [
                    (true, true, 0),
                    (false, false, 0),
                    (true, false, 5),
                    (false, true, 99),
                ]
                for c in combos {
                    let r = DownloadEngine.decideRestartLoopOutcome(
                        cancelled: true,
                        allDone: c.allDone,
                        pathFlagSet: c.flag,
                        completedRestarts: c.attempts
                    )
                    try expectEqual(r, .completeOrCancelled,
                        "cancelled=true should override allDone=\(c.allDone) flag=\(c.flag) attempts=\(c.attempts)")
                }
            }

            TestHarness.test("All done wins next: cancelled=false + allDone=true → completeOrCancelled") {
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: true,
                    pathFlagSet: true,  // even with flag set, completion wins
                    completedRestarts: 0
                )
                try expectEqual(r, .completeOrCancelled)
            }

            TestHarness.test("Lanes exited without a flip: not-cancelled + not-done + flag-clear → giveUp") {
                // This is the "every lane failed over" case — the
                // restart loop has no flip to act on, so it bails
                // out so the verify phase can surface the
                // SHA-mismatch / incomplete-file failure.
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: false,
                    completedRestarts: 0
                )
                try expectEqual(r, .giveUp)
            }

            TestHarness.test("Flag set + restarts under max → restart") {
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: 0
                )
                try expectEqual(r, .restart)

                // And again with non-zero (but still under max):
                let r2 = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: 3,
                    maxRestarts: 6
                )
                try expectEqual(r2, .restart)
            }

            TestHarness.test("Flap-loop guard: completedRestarts >= max → giveUp") {
                // Defensive cap against pathological flap loops where
                // the OS reports interface churn faster than chunks
                // complete.  At max, give up instead of looping forever.
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: 6,
                    maxRestarts: 6
                )
                try expectEqual(r, .giveUp,
                    "Equality is the bound — at max we stop, not keep going")

                let rOver = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: 12,  // arbitrary above-max value
                    maxRestarts: 6
                )
                try expectEqual(rOver, .giveUp)
            }

            TestHarness.test("Default maxRestarts matches DownloadEngine.maxPathFlipRestarts") {
                // Regression guard: if someone changes the default
                // separately from the constant, the helper's behaviour
                // would silently diverge.  The bound is 6 today.
                try expectEqual(DownloadEngine.maxPathFlipRestarts, 6)
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: 6
                    // No maxRestarts: argument — uses the default.
                )
                try expectEqual(r, .giveUp,
                    "Default maxRestarts must equal DownloadEngine.maxPathFlipRestarts (6)")
            }
        }

        TestHarness.suite("DownloadEngine.decideRestartLoopOutcome — typical flap sequence") {

            // Walk through a synthetic 4-restart scenario: each
            // iteration sees pathFlagSet=true (because the observer
            // raised it) and increments completedRestarts.  The
            // loop should restart 6 times then give up on the 7th
            // observation (matches maxPathFlipRestarts).

            TestHarness.test("Six restarts in a row, then guard fires") {
                var completedRestarts = 0
                for i in 0..<6 {
                    let r = DownloadEngine.decideRestartLoopOutcome(
                        cancelled: false,
                        allDone: false,
                        pathFlagSet: true,
                        completedRestarts: completedRestarts
                    )
                    try expectEqual(r, .restart,
                        "Iteration \(i): expected restart, got \(r)")
                    completedRestarts += 1
                }
                // 7th call: completedRestarts == 6 == maxPathFlipRestarts → giveUp.
                let r7 = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: completedRestarts
                )
                try expectEqual(r7, .giveUp,
                    "After 6 successful restarts, guard fires on the 7th flag observation")
            }

            TestHarness.test("Mid-sequence cancel exits cleanly") {
                // Three restarts, then user-cancel during the 4th
                // iteration's check.  Should resolve to
                // completeOrCancelled, NOT continue restarting.
                var completedRestarts = 0
                for _ in 0..<3 {
                    _ = DownloadEngine.decideRestartLoopOutcome(
                        cancelled: false, allDone: false, pathFlagSet: true,
                        completedRestarts: completedRestarts
                    )
                    completedRestarts += 1
                }
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: true,
                    allDone: false,
                    pathFlagSet: true,
                    completedRestarts: completedRestarts
                )
                try expectEqual(r, .completeOrCancelled,
                    "User cancel mid-flap-sequence still wins")
            }

            TestHarness.test("Mid-sequence completion exits cleanly") {
                // Restarted twice, then a slow chunk catches up + the
                // queue completes during the 3rd iteration's check.
                let r = DownloadEngine.decideRestartLoopOutcome(
                    cancelled: false,
                    allDone: true,
                    pathFlagSet: true,  // flag still set from the recent flip
                    completedRestarts: 2
                )
                try expectEqual(r, .completeOrCancelled,
                    "Completion wins over flag-set restart trigger")
            }
        }
    }
}
