import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// The Concierge LLM does NOT have free rein.  It picks among the
// FIXED, COMPILE-TIME tool registry below.  This is the same
// architectural pattern as `MCPToolRegistry` (see MCPTools.swift).
//
// What an LLM-generated payload can do:
//   * Invoke one of the 8 fixed tools below
//   * Pass arguments matching the tool's compile-time JSON Schema
//
// What an LLM-generated payload CANNOT do:
//   * Define a new tool / handler at runtime
//   * Pass a code body, expression, or closure as an argument
//   * Trigger any code path that wasn't compiled into the .app bundle
//
// The dispatcher is a simple switch over `ConciergeTool.id`.  Adding
// or removing a tool requires a code change, a recompile, and a new
// App Store submission.
//
// See MAS-2.5.2-COMPLIANCE.md for the full reviewer-facing brief.
// =====================================================================

/// v1.7: the Concierge assistant's tool-pick registry.
///
/// The Pro-tier `AIConcierge` (in `splynek-pro`) prompts the local
/// LLM with the catalogued tool list and asks it to return a
/// structured `{tool: "...", args: {...}}` JSON object.  The
/// dispatcher decodes that object via the `Codable` types here and
/// invokes the matching handler.  Result strings render as chat
/// cards in `ConciergeView`.
///
/// Why "fixed compile-time registry"?
///
///   - **2.5.2 compliance** — see header.
///   - **Privacy contract** — a free-form "let the LLM pick whatever
///     tool it wants" architecture is an exfiltration risk.  Bounded
///     tool surface = bounded data egress surface = "what does the
///     model see" answer that fits on one page.
///   - **Testability** — every tool is a pure function from typed
///     args to a `Result<String, Error>`.  Tests can pin behaviour
///     without an LLM.
///
/// Public-repo scope: this file defines the **types** (tool spec,
/// invocation envelope, dispatch result).  The actual handlers — and
/// the LLM dispatch loop that picks among them — live in the Pro
/// repo (`splynek-pro/Sources/SplynekPro/AIConcierge.swift`).  Free
/// tier still ships the upsell view; only `LocalizedStringKey`
/// strings need to be in the catalog.
enum ConciergeToolRegistry {

    /// The 8 tools the Concierge can pick.  Order is presentation-
    /// only — the LLM is told to pick by `id`, not by position.
    static let allTools: [ConciergeTool] = [
        downloadByGoal,
        searchHistory,
        diskUsage,
        installedApps,
        sovereigntyReport,
        trustReport,
        summarizePDF,
        recentActivity,
    ]

    // MARK: - Tool definitions
    //
    // Each tool's `description` is the prompt the LLM sees when
    // deciding whether to pick it.  Prose should read like a docstring;
    // include phrases users actually type ("disk hog", "find the file
    // about taxes") so the model maps idioms onto our tool names.

    static let downloadByGoal = ConciergeTool(
        id: "download_by_goal",
        title: "Download by goal",
        description: """
            User wants to download a specific file but doesn't have the URL.  \
            Examples: "the latest Ubuntu ISO", "Firefox Developer Edition for Mac", \
            "OBS Studio 30".  The handler maps the goal to a probed URL and shows \
            the user a Download / Cancel sheet.  The user must click Download — \
            this tool never starts a download on its own.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "goal": .object([
                    "type": .string("string"),
                    "description": .string("Plain-English description of the file to find"),
                ]),
            ]),
            "required": .array([.string("goal")]),
        ])
    )

    static let searchHistory = ConciergeTool(
        id: "search_history",
        title: "Search download history",
        description: """
            User wants to find a previously-downloaded file.  Examples: "what \
            did I download about taxes last March?", "find my Ubuntu ISO", \
            "did I already download Logic Pro?".  The handler runs a tokenized \
            ranked search over the user's local DownloadHistory (history.json) \
            and returns the top 5 hits with filename, host, age.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([
                "query": .object([
                    "type": .string("string"),
                    "description": .string("Free-text query"),
                ]),
            ]),
            "required": .array([.string("query")]),
        ])
    )

    static let diskUsage = ConciergeTool(
        id: "disk_usage",
        title: "Disk usage report",
        description: """
            User wants to know what's taking up disk space.  Examples: \
            "what's eating my disk?", "biggest folder under Downloads?", \
            "show me hogs".  The handler asks the user to pick a folder \
            (NSOpenPanel) and returns the top 25 space-takers.  The pick \
            is required by the MAS sandbox — Splynek can't enumerate \
            arbitrary paths without explicit user grant.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ])
    )

    static let installedApps = ConciergeTool(
        id: "installed_apps",
        title: "List installed apps",
        description: """
            User wants to see which apps are installed.  Examples: \
            "what apps do I have?", "is Slack installed?", "list my browsers".  \
            The handler walks /Applications, /Applications/Utilities, and \
            ~/Applications via the existing SovereigntyScanner (privacy-safe — \
            metadata only, no content reads).
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ])
    )

    static let sovereigntyReport = ConciergeTool(
        id: "sovereignty_report",
        title: "Sovereignty report",
        description: """
            User wants to know which of their installed apps have European \
            or open-source alternatives.  Examples: "what should I drop \
            for sovereignty?", "show me US apps I could replace", "give me \
            EU alternatives".  The handler runs a Sovereignty scan, ranks \
            matches by user prominence (Dock + LaunchPad position would be \
            ideal but we currently rank by catalog inclusion), and returns \
            the top 5 with one-line rationale.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ])
    )

    static let trustReport = ConciergeTool(
        id: "trust_report",
        title: "Trust report",
        description: """
            User wants the Trust score on their installed apps.  Examples: \
            "what apps do I have that send my data somewhere?", "check the \
            trust scores of my installed apps", "any privacy red flags?".  \
            Handler runs the Trust catalog over the installed-app list and \
            returns the top 5 by severity.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ])
    )

    static let summarizePDF = ConciergeTool(
        id: "summarize_pdf",
        title: "Summarize a PDF",
        description: """
            User wants a summary of a PDF.  Examples: "summarize this PDF", \
            "give me the gist of the file I just dropped".  The handler asks \
            the user to pick a PDF (NSOpenPanel), extracts up to 8000 \
            characters of text, and asks the LLM for a {summary, bullets[]} \
            response.  The PDF text never leaves the local machine.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ])
    )

    static let recentActivity = ConciergeTool(
        id: "recent_activity",
        title: "Recent activity",
        description: """
            User wants a digest of what Splynek's been up to lately.  \
            Examples: "what did I download today?", "any active downloads?", \
            "what's in my queue?".  Handler reads DownloadHistory + the \
            current queue snapshot and returns a compact summary.
            """,
        argsSchema: .object([
            "type": .string("object"),
            "properties": .object([:]),
            "required": .array([]),
        ])
    )

    // MARK: - Lookup

    static func tool(withID id: String) -> ConciergeTool? {
        allTools.first { $0.id == id }
    }
}

// MARK: - Tool spec types
//
// The `ConciergeTool` descriptor and the `ConciergeInvocation`
// envelope are deliberately Codable on purpose: the dispatcher in
// the Pro repo can decode an LLM-emitted invocation through this
// shape without re-implementing the wire format.

struct ConciergeTool: Hashable, Sendable {
    let id: String
    let title: String
    let description: String
    let argsSchema: ConciergeJSON

    init(
        id: String,
        title: String,
        description: String,
        argsSchema: ConciergeJSON
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.argsSchema = argsSchema
    }
}

/// What the LLM emits in its turn — a tool ID + a JSON object of args.
/// The dispatcher decodes the response through this shape; if the
/// decode fails, the chat card shows "I couldn't understand that"
/// and the user retries.
struct ConciergeInvocation: Codable, Hashable, Sendable {
    let tool: String
    let args: ConciergeJSON

    init(tool: String, args: ConciergeJSON) {
        self.tool = tool
        self.args = args
    }
}

/// Minimal JSON value type so we can serialise tool descriptors
/// (and decode invocations) without dragging in a third-party
/// JSONValue dependency.
indirect enum ConciergeJSON: Codable, Hashable, Sendable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case array([ConciergeJSON])
    case object([String: ConciergeJSON])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self) { self = .bool(v); return }
        if let v = try? c.decode(Double.self) { self = .number(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([ConciergeJSON].self) { self = .array(v); return }
        if let v = try? c.decode([String: ConciergeJSON].self) { self = .object(v); return }
        throw DecodingError.typeMismatch(
            ConciergeJSON.self,
            DecodingError.Context(
                codingPath: decoder.codingPath,
                debugDescription: "Unsupported JSON value"
            )
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .null:           try c.encodeNil()
        case .bool(let v):    try c.encode(v)
        case .number(let v):  try c.encode(v)
        case .string(let v):  try c.encode(v)
        case .array(let v):   try c.encode(v)
        case .object(let v):  try c.encode(v)
        }
    }

    /// Convenience: extract a string field by key, or nil if absent /
    /// non-string.  Used by the dispatcher to read tool arguments
    /// without writing a 3-line guard for every call site.
    func string(_ key: String) -> String? {
        guard case .object(let dict) = self else { return nil }
        if case .string(let s) = dict[key] { return s }
        return nil
    }
}
