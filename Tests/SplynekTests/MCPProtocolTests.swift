import Foundation
@testable import SplynekCore

/// v1.6: MCP server protocol tests.
///
/// These exercise the JSON-RPC parser + dispatcher against a stubbed
/// bridge (no VM, no FleetCoordinator).  Each test asserts that one
/// MCP method shape produces the expected response shape.  Tool-level
/// behaviour (catalog lookups, etc.) is covered by `lookupSovereignty`
/// and `lookupTrust` directly via `MCPBridgeBuilder` — those don't
/// need the VM either.
///
/// Key invariants we want to lock in:
///   1. `initialize` returns `protocolVersion`, `serverInfo`,
///      `capabilities.tools` (present even if empty).
///   2. `tools/list` returns ALL registered tools in `MCPToolRegistry.allTools`.
///   3. `tools/call` with a valid name + args returns `content[0].text`
///      and `isError: false`.
///   4. `tools/call` with an unknown name returns a JSON-RPC
///      `methodNotFound` (-32601).
///   5. Notifications (no `id`) return empty body, never an envelope.
///   6. Parse error on bad JSON returns -32700.
///   7. The `serverDisabled` route returns -32001 when `enabled: false`.
enum MCPProtocolTests {

    static func run() {
        TestHarness.suite("MCP server protocol") {
            let bridge = stubBridge()

            TestHarness.test("initialize returns protocolVersion + serverInfo + tools cap") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {"jsonrpc":"2.0","id":1,"method":"initialize"}
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                try expect(json.contains("\"protocolVersion\":\"2024-11-05\""),
                           "missing protocolVersion: \(json)")
                try expect(json.contains("\"name\":\"splynek-mcp\""),
                           "missing serverInfo.name: \(json)")
                try expect(json.contains("\"tools\":{}") || json.contains("\"tools\""),
                           "missing capabilities.tools: \(json)")
            }

            TestHarness.test("tools/list returns all 8 registered tools") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {"jsonrpc":"2.0","id":2,"method":"tools/list"}
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                for tool in MCPToolRegistry.allTools {
                    try expect(json.contains("\"\(tool.name)\""),
                               "tools/list missing tool \(tool.name): \(json)")
                }
            }

            TestHarness.test("tools/call get_progress with empty args returns isError:false") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {
                    "jsonrpc": "2.0", "id": 3, "method": "tools/call",
                    "params": { "name": "splynek_get_progress", "arguments": {} }
                }
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                try expect(json.contains("\"isError\":false"),
                           "expected isError:false: \(json)")
                try expect(json.contains("No active downloads"),
                           "expected stub no-active text: \(json)")
            }

            TestHarness.test("tools/call with unknown tool returns methodNotFound") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {
                    "jsonrpc": "2.0", "id": 4, "method": "tools/call",
                    "params": { "name": "not_a_real_tool", "arguments": {} }
                }
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                try expect(json.contains("\"code\":-32601"),
                           "expected -32601 method-not-found: \(json)")
            }

            TestHarness.test("tools/call download_url with bad URL returns isError:true") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {
                    "jsonrpc": "2.0", "id": 5, "method": "tools/call",
                    "params": {
                        "name": "splynek_download_url",
                        "arguments": { "url": "ftp://example.com/file" }
                    }
                }
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                try expect(json.contains("\"isError\":true"),
                           "expected isError:true for ftp scheme: \(json)")
            }

            TestHarness.test("notification (no id) returns empty body") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {"jsonrpc":"2.0","method":"notifications/initialized"}
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                try expect(resp.isEmpty,
                           "notifications must return empty body, got \(resp.count) bytes")
            }

            TestHarness.test("malformed JSON returns parseError -32700") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = "not json at all".data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                try expect(json.contains("\"code\":-32700"),
                           "expected parse error -32700: \(json)")
            }

            TestHarness.test("ping returns empty object result") {
                let server = MCPServer(bridge: bridge, enabled: true)
                let body = """
                {"jsonrpc":"2.0","id":6,"method":"ping"}
                """.data(using: .utf8)!
                let resp = await server.handle(rawBody: body)
                let json = String(data: resp, encoding: .utf8) ?? ""
                try expect(json.contains("\"result\":{}"),
                           "expected empty-object result for ping: \(json)")
            }
        }

        TestHarness.suite("MCP catalog bridge (no VM)") {

            TestHarness.test("lookupSovereignty by bundle ID returns hit shape") {
                // Pick a known catalog entry; we don't care which, so
                // just take the first.
                guard let first = SovereigntyCatalog.entries.first else { return }
                let hit = MCPBridgeBuilder.lookupSovereignty(query: first.targetBundleID)
                try expect(hit != nil, "Should hit by bundle ID")
                try expect(hit?.bundleID == first.targetBundleID, "Bundle ID round-trip")
                try expect(hit?.displayName == first.targetDisplayName, "Display name round-trip")
            }

            TestHarness.test("lookupSovereignty miss returns nil") {
                let hit = MCPBridgeBuilder.lookupSovereignty(query: "com.totally-not-real.xyz")
                try expect(hit == nil, "Bogus bundle ID should miss")
            }

            TestHarness.test("lookupTrust by bundle ID + default weights produces a score") {
                guard let first = TrustCatalog.entries.first else { return }
                let hit = MCPBridgeBuilder.lookupTrust(
                    query: first.targetBundleID,
                    weights: TrustScorer.Weights.default
                )
                try expect(hit != nil, "Should hit by bundle ID")
                try expect((hit?.score ?? -1) >= 0 && (hit?.score ?? -1) <= 100,
                           "Score must be in 0...100")
            }

            TestHarness.test("runSovereigntyScan returns non-negative counts") {
                // Doesn't assert an absolute count — that depends on the
                // host machine.  Just shape: appsScanned ≥ 0,
                // entriesMatched ≤ appsScanned.
                let s = MCPBridgeBuilder.runSovereigntyScan()
                try expect(s.appsScanned >= 0, "non-negative appsScanned")
                try expect(s.entriesMatched <= s.appsScanned,
                           "matched can't exceed scanned")
            }
        }
    }

    // MARK: - Stub bridge

    /// Sendable stub.  Returns deterministic empty data for every call;
    /// catalog lookups still hit the real (compile-time) catalog so the
    /// "no VM needed" property holds.
    private static func stubBridge() -> MCPServer.Bridge {
        MCPServer.Bridge(
            startDownload: { _, _ in
                throw MCPBridgeError("stub: not actually downloading")
            },
            queueDownload: { _, _ in
                throw MCPBridgeError("stub: not actually queueing")
            },
            getProgress: { [] },
            cancelAll: { },
            listHistory: { _ in [] },
            lookupSovereignty: { q in
                MCPBridgeBuilder.lookupSovereignty(query: q)
            },
            lookupTrust: { q in
                MCPBridgeBuilder.lookupTrust(query: q, weights: TrustScorer.Weights.default)
            },
            runSovereigntyScan: { MCPBridgeBuilder.runSovereigntyScan() }
        )
    }
}
