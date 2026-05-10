import Foundation

/// **Concierge Sequence Runner** — Sprint 2 part-2 (2026-05-09).
///
/// Executes a `ConciergeSequence` (built in Sprint 2 part-1) against
/// the existing MCP `Bridge` — the single dispatch layer every tool
/// already routes through.  Per-step confirmation is required for
/// every mutating step; non-mutating steps auto-run.
///
/// **Why reuse MCPServer.Bridge** instead of inventing a parallel
/// dispatch?  Single source of truth for tool semantics: when a
/// future commit adds a new tool, both the MCP server and Concierge
/// sequences pick it up via the bridge with no parallel changes.
///
/// **MAS posture**:
///   - The LLM (in `splynek-pro`'s Concierge) emits a sequence; it
///     never invokes the runner directly.  The runner only fires
///     after the user clicks Confirm in the SwiftUI preview sheet.
///   - Every mutating step requires its own confirmation callback
///     return value of `true` — the LLM cannot bypass this.
///   - Policy validation runs first; an LLM-emitted sequence that
///     violates `ConciergeSequencePolicy.validate` fails before any
///     dispatch.
///
/// Pure-logic-amenable: the runner is an actor with deterministic
/// behaviour given a Bridge.  Tests stub the Bridge with closures
/// that record their invocations and assert call order.

actor ConciergeSequenceRunner {

    enum StepResult: Equatable, Sendable {
        case completed(output: String)
        case skipped(reason: String)
        case failed(reason: String)
    }

    struct Outcome: Sendable {
        let stepID: String
        let kind: ConciergeStepKind
        let result: StepResult
    }

    private let bridge: MCPServer.Bridge

    init(bridge: MCPServer.Bridge) {
        self.bridge = bridge
    }

    /// Run the sequence step-by-step.
    ///
    /// - Parameters:
    ///   - sequence: validated `ConciergeSequence`
    ///   - confirm: closure invoked once per **mutating** step;
    ///     return `true` to authorize execution.  Non-mutating
    ///     steps don't call confirm — they run automatically.
    /// - Returns: per-step Outcome list, in order.  Halts on first
    ///   `failed` (so a download chain that hits a rejected URL
    ///   doesn't proceed to the next mutating step).
    func run(
        _ sequence: ConciergeSequence,
        confirm: @Sendable (ConciergeSequenceStep) async -> Bool
    ) async -> [Outcome] {
        // Policy gate first.  This catches LLM-malformed sequences
        // before any dispatch.
        if let problem = ConciergeSequencePolicy.validate(sequence) {
            return [Outcome(
                stepID: "<policy>",
                kind: .lookupSovereignty,
                result: .failed(reason: problem)
            )]
        }

        var outcomes: [Outcome] = []

        for step in sequence.steps {
            if step.kind.isMutating {
                let ok = await confirm(step)
                if !ok {
                    outcomes.append(Outcome(
                        stepID: step.id,
                        kind: step.kind,
                        result: .skipped(reason: "User declined.")
                    ))
                    // Halt after a declined mutating step — the
                    // user said no, don't keep the cascade going.
                    break
                }
            }
            let result = await invoke(step)
            outcomes.append(Outcome(
                stepID: step.id,
                kind: step.kind,
                result: result
            ))
            if case .failed = result {
                // Stop on first failure to avoid compounding.
                break
            }
        }

        return outcomes
    }

    // MARK: - Per-step dispatch

    private func invoke(_ step: ConciergeSequenceStep) async -> StepResult {
        let args = parseArgs(step.argumentsJSON)
        do {
            switch step.kind {
            case .lookupSovereignty:
                let query = args["query"] as? String ?? ""
                guard !query.isEmpty else {
                    return .skipped(reason: "Missing 'query' argument.")
                }
                if let hit = await bridge.lookupSovereignty(query) {
                    return .completed(output: "\(hit.displayName): \(hit.alternatives.count) alternatives.")
                }
                return .completed(output: "No catalog match for '\(query)'.")

            case .lookupTrust:
                let query = args["query"] as? String ?? ""
                guard !query.isEmpty else {
                    return .skipped(reason: "Missing 'query' argument.")
                }
                if let hit = await bridge.lookupTrust(query) {
                    return .completed(output: "\(hit.displayName): score \(hit.score), \(hit.concernCount) concerns.")
                }
                return .completed(output: "No Trust profile for '\(query)'.")

            case .sovereigntyScan:
                let summary = await bridge.runSovereigntyScan()
                return .completed(output: "Scanned \(summary.appsScanned) apps; \(summary.entriesMatched) catalog matches.")

            case .getProgress:
                let jobs = await bridge.getProgress()
                let running = jobs.filter { $0.lifecycle == "running" }.count
                return .completed(output: "\(jobs.count) total, \(running) running.")

            case .listHistory:
                let limit = (args["limit"] as? Int) ?? 25
                let history = await bridge.listHistory(limit)
                return .completed(output: "\(history.count) recent entries.")

            case .downloadURL:
                guard let url = args["url"] as? String, !url.isEmpty else {
                    return .failed(reason: "Missing 'url' argument.")
                }
                let sha = args["sha256"] as? String
                let id = try await bridge.startDownload(url, sha)
                return .completed(output: "Started download \(id).")

            case .queueURL:
                guard let url = args["url"] as? String, !url.isEmpty else {
                    return .failed(reason: "Missing 'url' argument.")
                }
                let sha = args["sha256"] as? String
                let id = try await bridge.queueDownload(url, sha)
                return .completed(output: "Queued \(id).")

            case .cancelAll:
                await bridge.cancelAll()
                return .completed(output: "Cancelled all in-flight downloads.")
            }
        } catch {
            return .failed(reason: error.localizedDescription)
        }
    }

    /// Best-effort JSON → [String: Any].  Empty dictionary on
    /// parse failure — the per-step invoke handlers gracefully
    /// surface "missing argument" errors when keys aren't found.
    private func parseArgs(_ json: String) -> [String: Any] {
        guard let data = json.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return parsed
    }
}
