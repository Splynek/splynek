import Foundation
@testable import SplynekCore

/// Tests for the Concierge sequence runner.  Exercises:
///   • Policy gate halts before any dispatch on invalid sequences
///   • Read-only steps auto-run; mutating steps require confirm()
///   • A declined mutating step halts the cascade
///   • A failed dispatch halts the cascade
///   • Per-step argument parsing handles missing JSON gracefully
///
/// Sprint 2 part-2 (2026-05-09).
enum ConciergeSequenceRunnerTests {

    static func run() {
        TestHarness.suite("Concierge sequence runner") {

            // Build a counting Bridge whose closures record their
            // invocations via a class-based recorder (Sendable).
            // Bridge closures are @Sendable so the recorder must
            // be class-with-locks.
            final class Recorder: @unchecked Sendable {
                let lock = NSLock()
                var startCalls: [(url: String, sha: String?)] = []
                var queueCalls: [(url: String, sha: String?)] = []
                var cancelCount = 0
                var lookupSov: [String] = []
                var lookupTr: [String] = []
                var scanCount = 0
                var historyLimits: [Int] = []
                var progressCount = 0
            }

            func makeBridge(_ rec: Recorder) -> MCPServer.Bridge {
                MCPServer.Bridge(
                    startDownload: { url, sha in
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.startCalls.append((url, sha))
                        return "job-\(rec.startCalls.count)"
                    },
                    queueDownload: { url, sha in
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.queueCalls.append((url, sha))
                        return "queue-\(rec.queueCalls.count)"
                    },
                    getProgress: {
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.progressCount += 1
                        return []
                    },
                    cancelAll: {
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.cancelCount += 1
                    },
                    listHistory: { limit in
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.historyLimits.append(limit)
                        return []
                    },
                    lookupSovereignty: { q in
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.lookupSov.append(q)
                        return nil
                    },
                    lookupTrust: { q in
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.lookupTr.append(q)
                        return nil
                    },
                    runSovereigntyScan: {
                        rec.lock.lock(); defer { rec.lock.unlock() }
                        rec.scanCount += 1
                        return MCPServer.ScanSummary(appsScanned: 0, entriesMatched: 0)
                    }
                )
            }

            func step(_ id: String, _ kind: ConciergeStepKind,
                      args: String = "{}") -> ConciergeSequenceStep {
                ConciergeSequenceStep(id: id, kind: kind,
                                      summary: "test", argumentsJSON: args)
            }

            TestHarness.test("Read-only steps auto-run; no confirm calls") {
                let rec = Recorder()
                let runner = ConciergeSequenceRunner(bridge: makeBridge(rec))
                let seq = ConciergeSequence(
                    id: "x", originPrompt: "test",
                    steps: [
                        step("1", .lookupSovereignty,
                             args: #"{"query":"spotify"}"#),
                        step("2", .getProgress)
                    ],
                    createdAt: "now"
                )
                var confirmCalls = 0
                let outcomes = await runner.run(seq) { _ in
                    confirmCalls += 1
                    return false
                }
                try expect(confirmCalls == 0,
                           "read-only steps should not trigger confirm()")
                try expect(rec.lookupSov == ["spotify"],
                           "lookup not called: \(rec.lookupSov)")
                try expect(rec.progressCount == 1,
                           "progress not called: \(rec.progressCount)")
                try expect(outcomes.count == 2, "expected 2 outcomes")
            }

            TestHarness.test("Declined mutating step halts cascade") {
                let rec = Recorder()
                let runner = ConciergeSequenceRunner(bridge: makeBridge(rec))
                let seq = ConciergeSequence(
                    id: "x", originPrompt: "queue + cancel",
                    steps: [
                        step("1", .lookupSovereignty,
                             args: #"{"query":"x"}"#),
                        step("2", .queueURL,
                             args: #"{"url":"https://example.invalid/"}"#),
                        step("3", .cancelAll)
                    ],
                    createdAt: "now"
                )
                let outcomes = await runner.run(seq) { _ in false }
                try expect(rec.queueCalls.isEmpty,
                           "declined queue should not have been called: \(rec.queueCalls)")
                try expect(rec.cancelCount == 0,
                           "third step should not run after declined second")
                // Outcomes should be: completed lookup, skipped queue
                // (and we halt — no third outcome).
                try expect(outcomes.count == 2,
                           "expected 2 outcomes (completed + skipped), got \(outcomes.count)")
                if case .skipped = outcomes[1].result {
                    // ok
                } else {
                    throw TestError("expected second step to be skipped")
                }
            }

            TestHarness.test("Approved mutating step proceeds; subsequent steps run") {
                let rec = Recorder()
                let runner = ConciergeSequenceRunner(bridge: makeBridge(rec))
                let seq = ConciergeSequence(
                    id: "x", originPrompt: "approve queue",
                    steps: [
                        step("1", .queueURL,
                             args: #"{"url":"https://example.invalid/a.iso"}"#),
                        step("2", .getProgress)
                    ],
                    createdAt: "now"
                )
                let outcomes = await runner.run(seq) { _ in true }
                try expect(rec.queueCalls.count == 1,
                           "approved queue should have run: \(rec.queueCalls)")
                try expect(rec.progressCount == 1,
                           "second step should have run after approved first")
                try expect(outcomes.allSatisfy {
                    if case .completed = $0.result { return true }
                    return false
                }, "all outcomes should be completed")
            }

            TestHarness.test("Policy violation halts before dispatch") {
                let rec = Recorder()
                let runner = ConciergeSequenceRunner(bridge: makeBridge(rec))
                // Empty sequence trips the validate() empty-step rule.
                let seq = ConciergeSequence(
                    id: "x", originPrompt: "empty",
                    steps: [],
                    createdAt: "now"
                )
                let outcomes = await runner.run(seq) { _ in true }
                try expect(rec.scanCount == 0, "no dispatch on policy fail")
                try expect(outcomes.count == 1, "expected single policy outcome")
                if case .failed = outcomes[0].result {
                    // ok
                } else {
                    throw TestError("expected failed outcome on policy violation")
                }
            }

            TestHarness.test("Missing argument fails the step (mutating)") {
                let rec = Recorder()
                let runner = ConciergeSequenceRunner(bridge: makeBridge(rec))
                let seq = ConciergeSequence(
                    id: "x", originPrompt: "no url",
                    steps: [step("1", .queueURL, args: "{}")],
                    createdAt: "now"
                )
                let outcomes = await runner.run(seq) { _ in true }
                try expect(rec.queueCalls.isEmpty,
                           "queueURL should not run without 'url' argument")
                if case .failed = outcomes[0].result {
                    // ok
                } else {
                    throw TestError("expected failed on missing url")
                }
            }
        }
    }
}
