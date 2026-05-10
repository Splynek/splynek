import Foundation
@testable import SplynekCore

/// v1.7: ConciergeToolRegistry shape invariants + Codable round-trip
/// for the tool-pick wire format.  These guard the 2.5.2-relevant
/// claim that the tool surface is fixed at compile time and that
/// invocation envelopes deserialise predictably.
enum ConciergeToolsTests {

    static func run() {
        TestHarness.suite("ConciergeToolRegistry — invariants") {

            TestHarness.test("Registry has exactly 9 tools (drift guard)") {
                // 8 tools shipped through v1.7; 9th
                // (`migrate_review_digest`) added 2026-05-10 in
                // PRO-PLUS-IPHONE Sprint 3.  Every catalog
                // expansion is intentional + audited — drift here
                // means the dispatcher gained a path that no
                // longer matches the MAS-2.5.2 invariants; update
                // both this number AND the dispatcher review
                // before bumping.
                //
                // (Note: the MAS-2.5.2 brief talks about the 8 MCP
                // tools in MCPToolRegistry — a separate surface.
                // ConciergeToolRegistry has its own evolving set
                // gated by ProStubs for the free tier.)
                let n = ConciergeToolRegistry.allTools.count
                try expect(n == 9, "Tool count drifted to \(n) — update guard if intentional")
            }

            TestHarness.test("Every tool has a non-empty id, title, description") {
                for t in ConciergeToolRegistry.allTools {
                    try expect(!t.id.isEmpty, "Empty id")
                    try expect(!t.title.isEmpty, "Empty title for \(t.id)")
                    try expect(t.description.count > 50, "Suspiciously short description for \(t.id) (\(t.description.count) chars)")
                }
            }

            TestHarness.test("Every tool id is unique") {
                let ids = ConciergeToolRegistry.allTools.map { $0.id }
                try expect(Set(ids).count == ids.count, "Duplicate ids: \(ids)")
            }

            TestHarness.test("Tool ids are snake_case (consistent wire format)") {
                let pat = #"^[a-z][a-z0-9_]*$"#
                for t in ConciergeToolRegistry.allTools {
                    try expect(
                        t.id.range(of: pat, options: .regularExpression) != nil,
                        "Tool id \(t.id) is not snake_case"
                    )
                }
            }

            TestHarness.test("Lookup by id returns the matching tool") {
                let t = ConciergeToolRegistry.tool(withID: "search_history")
                try expect(t?.id == "search_history")
                try expect(ConciergeToolRegistry.tool(withID: "nonexistent_tool") == nil)
            }
        }

        TestHarness.suite("ConciergeInvocation — Codable round-trip") {

            TestHarness.test("Round-trips through JSON encoder/decoder") {
                let invocation = ConciergeInvocation(
                    tool: "search_history",
                    args: .object(["query": .string("ubuntu")])
                )
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                let data = try encoder.encode(invocation)
                let decoded = try decoder.decode(ConciergeInvocation.self, from: data)
                try expect(decoded == invocation, "Round-trip mismatch")
            }

            TestHarness.test("LLM-style payload decodes correctly") {
                // Simulates what a small LLM might emit.
                let json = #"{"tool":"download_by_goal","args":{"goal":"the latest Ubuntu ISO"}}"#
                let data = json.data(using: .utf8)!
                let inv = try JSONDecoder().decode(ConciergeInvocation.self, from: data)
                try expect(inv.tool == "download_by_goal")
                try expect(inv.args.string("goal") == "the latest Ubuntu ISO")
            }

            TestHarness.test("Mismatched-shape JSON throws cleanly") {
                let bad = #"{"not_a_tool_field": 42}"#
                let data = bad.data(using: .utf8)!
                var threw = false
                do { _ = try JSONDecoder().decode(ConciergeInvocation.self, from: data) }
                catch { threw = true }
                try expect(threw, "Should have thrown on missing 'tool' field")
            }

            TestHarness.test("ConciergeJSON.string accessor works") {
                let json = ConciergeJSON.object([
                    "name": .string("hello"),
                    "count": .number(5),
                ])
                try expect(json.string("name") == "hello")
                try expect(json.string("count") == nil, "Number should not stringify via .string()")
                try expect(json.string("missing") == nil)
            }
        }
    }
}
