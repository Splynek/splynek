import Foundation

/// v1.6: MCP (Model Context Protocol) server for Splynek.
///
/// Wraps Splynek's existing capabilities — multi-interface downloads,
/// BitTorrent, Sovereignty + Trust catalog lookups, queue control —
/// as MCP tools that any MCP-compatible client (Claude Desktop,
/// Claude.ai, ChatGPT-with-MCP, custom agents) can call.
///
/// **Transport:** JSON-RPC 2.0 over HTTP POST.  This is the simplest
/// MCP transport — no SSE, no streaming notifications.  Server-initiated
/// messages aren't supported in this revision; tools/call is fully
/// functional.  The HTTP+SSE and stdio transports can be layered on top
/// in v1.7 if there's demand.
///
/// **Endpoint:** `POST /splynek/v1/mcp/rpc?t=<fleet-token>`
/// **Body:** JSON-RPC 2.0 request — single message or batch.
/// **Auth:** the same `webToken` that protects `/splynek/v1/ui/submit`.
/// Tokens are 256 bits of CryptoKit randomness, persisted in the user's
/// Application Support container, regenerated only when explicitly
/// asked for.
///
/// **Opt-in:** off by default.  User flips `Settings → MCP server`
/// (`SplynekViewModel.mcpEnabled`) before any client can connect.  When
/// off, the route returns 503.
///
/// **Privacy posture:**
///   - The MCP server runs on the SAME loopback-or-LAN listener as
///     the web dashboard.  No new sockets, no new entitlements.
///   - All tool invocations are logged via `Log.system` at .info level
///     so users can audit who did what.
///   - The `splynek_run_sovereignty_scan` tool returns app metadata
///     that's already visible in the user's `/Applications` directory;
///     it doesn't reveal anything a `ls` couldn't.
///   - Tools that mutate state (download, queue, cancel) confirm via
///     the same VM ingest path as drag-drop / menu-bar / browser
///     extension; identical guard rails apply.
///
/// **Why this matters:** Splynek becomes a programmable substrate.
/// Conversations like *"download these five papers, run a sovereignty
/// check, and summarize what I'm installing"* become one-shot prompts
/// that any LLM with MCP support can execute.

import os

// MARK: - JSON-RPC 2.0 wire format

/// JSON-RPC 2.0 request envelope.
///
/// Per spec, `id` MAY be a string OR a number OR null.  We model it as
/// `RPCID` (an enum) so we round-trip whatever the client sent.
struct RPCRequest: Decodable {
    let jsonrpc: String
    let id: RPCID?
    let method: String
    let params: RPCParams?

    enum CodingKeys: String, CodingKey {
        case jsonrpc, id, method, params
    }
}

enum RPCID: Codable, Equatable {
    case string(String)
    case number(Int)
    case null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let s = try? c.decode(String.self) { self = .string(s); return }
        if let n = try? c.decode(Int.self) { self = .number(n); return }
        throw DecodingError.typeMismatch(
            RPCID.self,
            .init(codingPath: decoder.codingPath,
                  debugDescription: "id must be string, number, or null")
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s): try c.encode(s)
        case .number(let n): try c.encode(n)
        case .null:          try c.encodeNil()
        }
    }
}

/// `params` can be either an array (positional) or an object (named).
/// Tools we expose all use named, but we accept both per spec.
enum RPCParams: Decodable {
    case object([String: AnyJSON])
    case array([AnyJSON])
    case none

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .none; return }
        if let dict = try? c.decode([String: AnyJSON].self) {
            self = .object(dict); return
        }
        if let arr = try? c.decode([AnyJSON].self) {
            self = .array(arr); return
        }
        self = .none
    }

    /// Convenience: extract a named parameter.
    func string(_ key: String) -> String? {
        if case let .object(d) = self, case let .string(s)? = d[key] { return s }
        return nil
    }

    func int(_ key: String) -> Int? {
        if case let .object(d) = self, case let .int(n)? = d[key] { return n }
        return nil
    }

    func bool(_ key: String) -> Bool? {
        if case let .object(d) = self, case let .bool(b)? = d[key] { return b }
        return nil
    }
}

/// Tiny JSON ADT — Foundation's built-ins don't round-trip arbitrary
/// JSON cleanly without a third-party dep, so we carry our own.
indirect enum AnyJSON: Codable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null
    case array([AnyJSON])
    case object([String: AnyJSON])

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null; return }
        if let v = try? c.decode(Bool.self)   { self = .bool(v); return }
        if let v = try? c.decode(Int.self)    { self = .int(v); return }
        if let v = try? c.decode(Double.self) { self = .double(v); return }
        if let v = try? c.decode(String.self) { self = .string(v); return }
        if let v = try? c.decode([AnyJSON].self) { self = .array(v); return }
        if let v = try? c.decode([String: AnyJSON].self) { self = .object(v); return }
        self = .null
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let s):  try c.encode(s)
        case .int(let n):     try c.encode(n)
        case .double(let d):  try c.encode(d)
        case .bool(let b):    try c.encode(b)
        case .null:           try c.encodeNil()
        case .array(let a):   try c.encode(a)
        case .object(let o):  try c.encode(o)
        }
    }
}

/// JSON-RPC 2.0 error envelope.  Per spec the `code` field is a Number
/// in the range -32768 to -32000 for protocol errors; method-specific
/// errors use other ranges.  We use -32xxx for protocol, -40xxx for
/// MCP semantic.
struct RPCError: Codable {
    let code: Int
    let message: String
    let data: AnyJSON?

    static let parseError      = RPCError(code: -32_700, message: "Parse error", data: nil)
    static let invalidRequest  = RPCError(code: -32_600, message: "Invalid Request", data: nil)
    static let methodNotFound  = RPCError(code: -32_601, message: "Method not found", data: nil)
    static let invalidParams   = RPCError(code: -32_602, message: "Invalid params", data: nil)
    static let internalError   = RPCError(code: -32_603, message: "Internal error", data: nil)
    static let serverDisabled  = RPCError(code: -32_001, message: "MCP server is disabled — enable in Splynek → Settings → MCP", data: nil)
    static let unauthorized    = RPCError(code: -32_002, message: "Unauthorized — fleet token missing or invalid", data: nil)

    static func toolError(_ message: String, data: AnyJSON? = nil) -> RPCError {
        RPCError(code: -40_001, message: message, data: data)
    }
}

/// JSON-RPC 2.0 response.  Either `result` xor `error` must be present.
struct RPCResponse: Codable {
    let jsonrpc: String
    let id: RPCID?
    let result: AnyJSON?
    let error: RPCError?

    static func ok(id: RPCID?, _ result: AnyJSON) -> RPCResponse {
        .init(jsonrpc: "2.0", id: id, result: result, error: nil)
    }

    static func fail(id: RPCID?, _ error: RPCError) -> RPCResponse {
        .init(jsonrpc: "2.0", id: id, result: nil, error: error)
    }
}

// MARK: - MCP server

/// Top-level MCP request handler.  Owns nothing mutable; all state
/// lives behind the `bridge` callable so we can isolate test
/// invocations and the FleetCoordinator wiring uses one shared
/// instance per app run.
public final class MCPServer {

    /// Bridge to Splynek's actual capabilities.  Injected so tests can
    /// stub it without spinning up the whole VM + queue + catalog.
    public struct Bridge {
        /// All mutating tools throw `MCPBridgeError` on rejection so
        /// the tool layer can map them to `isError: true` results
        /// without needing a custom Result+Error pair.
        public var startDownload: @Sendable (_ url: String, _ sha256: String?) async throws -> String
        public var queueDownload: @Sendable (_ url: String, _ sha256: String?) async throws -> String
        public var getProgress: @Sendable () async -> [JobSummary]
        public var cancelAll: @Sendable () async -> Void
        public var listHistory: @Sendable (_ limit: Int) async -> [HistorySummary]
        public var lookupSovereignty: @Sendable (_ query: String) async -> SovereigntyHit?
        public var lookupTrust: @Sendable (_ query: String) async -> TrustHit?
        public var runSovereigntyScan: @Sendable () async -> ScanSummary

        public init(
            startDownload: @escaping @Sendable (_ url: String, _ sha256: String?) async throws -> String,
            queueDownload: @escaping @Sendable (_ url: String, _ sha256: String?) async throws -> String,
            getProgress: @escaping @Sendable () async -> [JobSummary],
            cancelAll: @escaping @Sendable () async -> Void,
            listHistory: @escaping @Sendable (_ limit: Int) async -> [HistorySummary],
            lookupSovereignty: @escaping @Sendable (_ query: String) async -> SovereigntyHit?,
            lookupTrust: @escaping @Sendable (_ query: String) async -> TrustHit?,
            runSovereigntyScan: @escaping @Sendable () async -> ScanSummary
        ) {
            self.startDownload = startDownload
            self.queueDownload = queueDownload
            self.getProgress = getProgress
            self.cancelAll = cancelAll
            self.listHistory = listHistory
            self.lookupSovereignty = lookupSovereignty
            self.lookupTrust = lookupTrust
            self.runSovereigntyScan = runSovereigntyScan
        }
    }

    public struct JobSummary: Codable, Sendable {
        public let id: String
        public let url: String
        public let filename: String
        public let lifecycle: String       // "running", "paused", etc.
        public let downloaded: Int64
        public let total: Int64
        public let throughputBps: Double
    }

    public struct HistorySummary: Codable, Sendable {
        public let id: String
        public let url: String
        public let filename: String
        public let totalBytes: Int64
        public let finishedAt: Date
        public let outputPath: String
    }

    public struct SovereigntyHit: Codable, Sendable {
        public let bundleID: String
        public let displayName: String
        public let targetOrigin: String           // "EU", "US", "OSS", etc.
        public let alternatives: [Alternative]

        public struct Alternative: Codable, Sendable {
            public let id: String
            public let name: String
            public let origin: String
            public let homepage: String
            public let downloadURL: String?
            public let note: String
        }
    }

    public struct TrustHit: Codable, Sendable {
        public let bundleID: String
        public let displayName: String
        public let lastReviewed: String
        public let score: Int                     // 0...100
        public let level: String                  // "low", "moderate", "high", "severe"
        public let concernCount: Int
        public let concerns: [Concern]

        public struct Concern: Codable, Sendable {
            public let id: String
            public let axis: String
            public let severity: String
            public let summary: String
            public let evidenceURL: String
        }
    }

    public struct ScanSummary: Codable, Sendable {
        public let appsScanned: Int
        public let entriesMatched: Int
    }

    public let bridge: Bridge
    public var enabled: Bool

    public init(bridge: Bridge, enabled: Bool = false) {
        self.bridge = bridge
        self.enabled = enabled
    }

    // MARK: Top-level dispatcher

    /// Decode + dispatch a single JSON-RPC request envelope.
    /// Returns the encoded JSON response (or `nil` for notifications,
    /// which JSON-RPC defines as requests without `id`).
    public func handle(rawBody: Data) async -> Data {
        // Cheap pre-filter: if the body is an array, treat as batch.
        if let batch = try? JSONDecoder().decode([RPCRequest].self, from: rawBody) {
            var responses: [RPCResponse] = []
            for req in batch {
                if req.id == nil { _ = await dispatch(req); continue }
                responses.append(await dispatch(req))
            }
            if responses.isEmpty { return Data() }
            return (try? JSONEncoder().encode(responses)) ?? Data()
        }

        guard let req = try? JSONDecoder().decode(RPCRequest.self, from: rawBody) else {
            let resp = RPCResponse.fail(id: nil, .parseError)
            return (try? JSONEncoder().encode(resp)) ?? Data()
        }

        if req.id == nil {
            // Notification — no response per spec.
            _ = await dispatch(req)
            return Data()
        }

        let resp = await dispatch(req)
        return (try? JSONEncoder().encode(resp)) ?? Data()
    }

    private func dispatch(_ req: RPCRequest) async -> RPCResponse {
        Log.system.info("MCP \(req.method, privacy: .public)")

        switch req.method {
        case "initialize":
            return RPCResponse.ok(id: req.id, .object([
                "protocolVersion": .string("2024-11-05"),
                "serverInfo": .object([
                    "name": .string("splynek-mcp"),
                    "version": .string("1.6.0"),
                ]),
                "capabilities": .object([
                    "tools": .object([:]),
                ]),
            ]))

        case "initialized", "notifications/initialized":
            // Notifications — no return.
            return RPCResponse.ok(id: req.id, .null)

        case "tools/list":
            return RPCResponse.ok(id: req.id, .object([
                "tools": .array(MCPToolRegistry.allTools.map { $0.descriptor }),
            ]))

        case "tools/call":
            return await handleToolCall(req)

        case "ping":
            return RPCResponse.ok(id: req.id, .object([:]))

        default:
            return RPCResponse.fail(id: req.id, .methodNotFound)
        }
    }

    private func handleToolCall(_ req: RPCRequest) async -> RPCResponse {
        guard case let .object(p) = req.params,
              case let .string(name)? = p["name"]
        else { return RPCResponse.fail(id: req.id, .invalidParams) }
        let args: RPCParams
        if case let .object(a)? = p["arguments"] {
            args = .object(a)
        } else {
            args = .object([:])
        }
        guard let tool = MCPToolRegistry.allTools.first(where: { $0.name == name }) else {
            return RPCResponse.fail(id: req.id, .methodNotFound)
        }
        do {
            let result = try await tool.handler(args, bridge)
            // MCP convention: tools return `content: [{ type: "text", text: "..." }]`.
            return RPCResponse.ok(id: req.id, .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(result),
                    ]),
                ]),
                "isError": .bool(false),
            ]))
        } catch let err as MCPToolError {
            return RPCResponse.ok(id: req.id, .object([
                "content": .array([
                    .object([
                        "type": .string("text"),
                        "text": .string(err.userMessage),
                    ]),
                ]),
                "isError": .bool(true),
            ]))
        } catch {
            return RPCResponse.fail(id: req.id, .toolError(String(describing: error)))
        }
    }
}

/// Errors a tool can throw to short-circuit with an MCP-friendly
/// `isError: true` content block (rather than a JSON-RPC-level error).
struct MCPToolError: Error {
    let userMessage: String
    init(_ message: String) { self.userMessage = message }
}

/// Errors the bridge throws when a mutating call is rejected
/// (URL parse failure, scheme guard, file system permission, etc.).
/// Converted to `MCPToolError` at the tool boundary.
public struct MCPBridgeError: Error, Sendable {
    public let userMessage: String
    public init(_ message: String) { self.userMessage = message }
}
