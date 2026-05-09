import Foundation

/// **Concierge sequences** — Sprint 2 scaffold (2026-05-09).
///
/// "Aposta B" of `STRATEGY-2026-PRO-PLUS-IPHONE.md`: turn Concierge
/// from informative ("here's where you can find that file") to
/// actionable ("I'll do steps 1 + 2 + 3 with confirmation").
///
/// ## Why a sequence type
///
/// Splynek's MAS-2.5.2 invariants forbid LLM-driven mutating actions
/// without explicit user confirmation per-step.  A Concierge
/// "sequence" is a **plan of N tool calls** the user previews +
/// confirms.  Each step is one of the existing tools in
/// `MCPToolRegistry` — the LLM can compose them but never invent
/// new actions.
///
/// ## Scope of Sprint 2 scaffold
///
/// **Built here**:
///   - `ConciergeSequenceStep` — one tool invocation in a sequence
///   - `ConciergeSequence` — ordered plan with confirmation gate
///   - `ConciergeSequencePolicy` — pure decision: which tools allowed
///     in a sequence, in which order
///   - Tests covering invariants
///
/// **Not built here** (Sprint 2 part 2 — runner + UI):
///   - The chat-driven sequence builder (LLM emits a Sequence;
///     ConciergeBridge validates + previews)
///   - Per-step confirmation UI in ConciergeView
///   - The runner that calls each step's tool with the LLM-supplied
///     arguments
///
/// ## MAS posture
///
/// The LLM never directly invokes a sequence.  It emits a *plan*
/// the user previews; the runner only executes steps the user
/// confirms.  Mutating tools (download, queue, cancel) require an
/// explicit "Run all" or per-step confirmation; non-mutating tools
/// (lookups) auto-run as part of the preview.

enum ConciergeStepKind: String, Codable, Sendable, CaseIterable {
    case lookupSovereignty       // read-only
    case lookupTrust             // read-only
    case sovereigntyScan         // read-only
    case getProgress             // read-only
    case listHistory             // read-only
    case downloadURL             // mutating
    case queueURL                // mutating
    case cancelAll               // mutating

    /// True when the step changes user state (queues a download,
    /// cancels a job, etc.).  Mutating steps require explicit
    /// per-step confirmation in the runner UI.
    var isMutating: Bool {
        switch self {
        case .downloadURL, .queueURL, .cancelAll:
            return true
        default:
            return false
        }
    }

    /// Maps to the existing MCP tool name so the runner can
    /// dispatch through the same registry the MCP server uses.
    /// Single source of truth — adding a new tool means adding a
    /// kind here AND registering it in MCPToolRegistry.
    var mcpToolName: String {
        switch self {
        case .lookupSovereignty:   return "splynek_lookup_sovereignty"
        case .lookupTrust:         return "splynek_lookup_trust"
        case .sovereigntyScan:     return "splynek_run_sovereignty_scan"
        case .getProgress:         return "splynek_get_progress"
        case .listHistory:         return "splynek_list_history"
        case .downloadURL:         return "splynek_download_url"
        case .queueURL:            return "splynek_queue_url"
        case .cancelAll:           return "splynek_cancel_all"
        }
    }
}

struct ConciergeSequenceStep: Codable, Hashable, Sendable, Identifiable {
    let id: String
    let kind: ConciergeStepKind
    /// Human-readable summary the user sees in the preview.
    let summary: String
    /// JSON-encoded arguments to pass through to the tool.  Stored
    /// as String for simple Codable + diffing in tests; the runner
    /// parses to a Dictionary at execution time.
    let argumentsJSON: String

    init(id: String, kind: ConciergeStepKind, summary: String,
         argumentsJSON: String = "{}") {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.argumentsJSON = argumentsJSON
    }
}

struct ConciergeSequence: Codable, Hashable, Sendable, Identifiable {
    let id: String
    /// Original natural-language prompt the user typed — kept so
    /// the chat transcript can show "you asked → I planned".
    let originPrompt: String
    let steps: [ConciergeSequenceStep]
    let createdAt: String   // ISO-8601

    var hasMutatingSteps: Bool {
        steps.contains(where: { $0.kind.isMutating })
    }

    var mutatingStepCount: Int {
        steps.filter { $0.kind.isMutating }.count
    }
}

// MARK: - Policy (pure invariants the runner enforces)

enum ConciergeSequencePolicy {

    /// Maximum steps a single sequence can contain.  Prevents a
    /// runaway LLM from emitting a 200-step plan that the user
    /// can't reasonably preview.  Conservative bound.
    static let maxSteps = 8

    /// Maximum mutating steps in a single sequence.  Sequences with
    /// >3 mutating actions are too coarse to "confirm all"; the
    /// UI should split them into separate sequences.
    static let maxMutatingSteps = 3

    /// Validate a proposed sequence.  Returns nil on success or
    /// a human-readable error describing the policy violation.
    /// Pure function — exercised by tests; runner calls before
    /// any mutation.
    static func validate(_ sequence: ConciergeSequence) -> String? {
        if sequence.steps.isEmpty {
            return "Sequence has no steps."
        }
        if sequence.steps.count > maxSteps {
            return "Sequence has \(sequence.steps.count) steps; maximum is \(maxSteps)."
        }
        if sequence.mutatingStepCount > maxMutatingSteps {
            return "Sequence has \(sequence.mutatingStepCount) mutating steps; maximum is \(maxMutatingSteps)."
        }
        // Step IDs must be unique — the runner uses them to
        // record per-step user confirmation.
        let ids = Set(sequence.steps.map(\.id))
        if ids.count != sequence.steps.count {
            return "Duplicate step IDs in sequence."
        }
        return nil
    }
}
