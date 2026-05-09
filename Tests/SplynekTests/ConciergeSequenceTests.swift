import Foundation
@testable import SplynekCore

/// Pure-policy tests for the Concierge sequence type.  Sprint 2
/// scaffold (2026-05-09) — runner + UI come in Sprint 2 part 2.
enum ConciergeSequenceTests {

    static func run() {
        TestHarness.suite("Concierge sequence — policy") {

            func step(_ id: String, _ kind: ConciergeStepKind) -> ConciergeSequenceStep {
                ConciergeSequenceStep(id: id, kind: kind, summary: "test")
            }

            TestHarness.test("Empty sequence is rejected") {
                let s = ConciergeSequence(
                    id: "x", originPrompt: "test",
                    steps: [], createdAt: "2026-05-09"
                )
                let result = ConciergeSequencePolicy.validate(s)
                try expect(result != nil, "empty sequence should fail validation")
                try expect(result!.contains("no steps"),
                           "wrong error: '\(result!)'")
            }

            TestHarness.test("Sequences within bounds pass") {
                let s = ConciergeSequence(
                    id: "x", originPrompt: "find spotify alternatives",
                    steps: [
                        step("1", .lookupSovereignty),
                        step("2", .lookupTrust)
                    ],
                    createdAt: "2026-05-09"
                )
                try expect(ConciergeSequencePolicy.validate(s) == nil,
                           "valid sequence rejected")
            }

            TestHarness.test("Too many steps is rejected") {
                let steps = (0..<(ConciergeSequencePolicy.maxSteps + 1)).map {
                    step("\($0)", .lookupSovereignty)
                }
                let s = ConciergeSequence(
                    id: "x", originPrompt: "test",
                    steps: steps, createdAt: "2026-05-09"
                )
                let r = ConciergeSequencePolicy.validate(s)
                try expect(r != nil, "should reject for too many steps")
                try expect(r!.contains("maximum"), "wrong error: \(r!)")
            }

            TestHarness.test("Too many mutating steps is rejected") {
                let s = ConciergeSequence(
                    id: "x", originPrompt: "queue lots",
                    steps: [
                        step("1", .queueURL),
                        step("2", .queueURL),
                        step("3", .queueURL),
                        step("4", .queueURL)
                    ],
                    createdAt: "2026-05-09"
                )
                let r = ConciergeSequencePolicy.validate(s)
                try expect(r != nil, "should reject for too many mutating steps")
                try expect(r!.contains("mutating"), "wrong error: \(r!)")
            }

            TestHarness.test("Duplicate IDs are rejected") {
                let s = ConciergeSequence(
                    id: "x", originPrompt: "dup",
                    steps: [
                        step("1", .lookupSovereignty),
                        step("1", .lookupTrust)  // dup id
                    ],
                    createdAt: "2026-05-09"
                )
                let r = ConciergeSequencePolicy.validate(s)
                try expect(r != nil, "should reject duplicate IDs")
                try expect(r!.contains("Duplicate"), "wrong error: \(r!)")
            }

            TestHarness.test("isMutating is correct for each kind") {
                try expect(ConciergeStepKind.lookupSovereignty.isMutating == false,
                           "lookup is read-only")
                try expect(ConciergeStepKind.queueURL.isMutating,
                           "queueURL must be mutating")
                try expect(ConciergeStepKind.cancelAll.isMutating,
                           "cancelAll must be mutating")
                try expect(ConciergeStepKind.getProgress.isMutating == false,
                           "getProgress is read-only")
            }

            TestHarness.test("Every kind maps to a non-empty MCP tool name") {
                for kind in ConciergeStepKind.allCases {
                    let name = kind.mcpToolName
                    try expect(!name.isEmpty,
                               "empty mcpToolName for \(kind.rawValue)")
                    try expect(name.hasPrefix("splynek_"),
                               "tool name must start with splynek_: \(name)")
                }
            }

            TestHarness.test("hasMutatingSteps + mutatingStepCount") {
                let s = ConciergeSequence(
                    id: "x", originPrompt: "mix",
                    steps: [
                        step("1", .lookupSovereignty),
                        step("2", .queueURL),
                        step("3", .lookupTrust),
                        step("4", .cancelAll)
                    ],
                    createdAt: "2026-05-09"
                )
                try expect(s.hasMutatingSteps, "mix has 2 mutating")
                try expect(s.mutatingStepCount == 2,
                           "expected 2 mutating, got \(s.mutatingStepCount)")
            }
        }
    }
}
