import Foundation
@testable import SplynekCore

/// Tests for the Sovereignty Migrate Wizard's plan builder.
/// Sprint 2 scaffold (2026-05-09) — pure planner exercised here;
/// the runner + UI come in Sprint 2 part 2.
enum SovereigntyMigratePlanTests {

    static func run() {
        TestHarness.suite("Sovereignty Migrate — plan builder") {

            // Build a synthetic alternative + entry for testing.
            // We don't read the real catalog — the planner is
            // catalog-agnostic; passing data in is cleaner.
            let alt = SovereigntyCatalog.Alternative(
                id: "tidal",
                origin: .europe,
                name: "Tidal",
                homepage: URL(string: "https://tidal.com")!,
                note: "Norwegian streaming service.",
                downloadURL: nil
            )
            let entry = SovereigntyCatalog.Entry(
                targetBundleID: "com.spotify.client",
                targetDisplayName: "Spotify",
                targetOrigin: .other,
                alternatives: [alt]
            )

            TestHarness.test("Plan has stable shape: opens homepage + flags original") {
                guard let plan = SovereigntyMigratePlanner.makePlan(
                    from: entry, alternative: alt
                ) else {
                    throw TestError("planner returned nil")
                }
                try expect(plan.steps.count == 2,
                           "expected exactly 2 steps in scaffold; got \(plan.steps.count)")
                try expect(plan.steps[0].action == .openHomepage,
                           "first step should be openHomepage")
                try expect(plan.steps[1].action == .markOriginalForReview,
                           "second step should be markOriginalForReview")
            }

            TestHarness.test("Plan IDs are unique per call") {
                guard let p1 = SovereigntyMigratePlanner.makePlan(from: entry, alternative: alt),
                      let p2 = SovereigntyMigratePlanner.makePlan(from: entry, alternative: alt)
                else { throw TestError("planner nil") }
                try expect(p1.id != p2.id,
                           "two plans for the same input should have different UUIDs")
            }

            TestHarness.test("Each step's confirmation prompt is non-empty") {
                guard let plan = SovereigntyMigratePlanner.makePlan(from: entry, alternative: alt) else {
                    throw TestError("nil")
                }
                for step in plan.steps {
                    try expect(!step.confirmationPrompt.isEmpty,
                               "step \(step.id) has empty confirmationPrompt")
                    try expect(!step.title.isEmpty, "empty title on \(step.id)")
                    try expect(!step.summary.isEmpty, "empty summary on \(step.id)")
                }
            }

            TestHarness.test("openHomepage step is marked non-destructive") {
                guard let plan = SovereigntyMigratePlanner.makePlan(from: entry, alternative: alt),
                      let first = plan.steps.first else { throw TestError("nil") }
                try expect(first.isDestructive == false,
                           "openHomepage should be non-destructive")
            }

            TestHarness.test("markOriginalForReview step is destructive") {
                guard let plan = SovereigntyMigratePlanner.makePlan(from: entry, alternative: alt),
                      let mark = plan.steps.first(where: { $0.action == .markOriginalForReview })
                else { throw TestError("nil") }
                try expect(mark.isDestructive,
                           "mark-for-review should be destructive (changes app state)")
            }

            TestHarness.test("Round-trip Codable") {
                guard let plan = SovereigntyMigratePlanner.makePlan(from: entry, alternative: alt) else {
                    throw TestError("nil")
                }
                let data = try JSONEncoder().encode(plan)
                let decoded = try JSONDecoder().decode(SovereigntyMigratePlan.self, from: data)
                try expect(decoded == plan,
                           "round-trip lost data: \(decoded.steps.count) vs \(plan.steps.count)")
            }
        }
    }
}

/// Local minimal error type for the planner tests; matches the
/// pattern other test files use.
struct TestError: Error { let msg: String; init(_ m: String) { msg = m } }
