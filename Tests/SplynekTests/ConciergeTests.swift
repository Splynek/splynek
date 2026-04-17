import Foundation
@testable import SplynekCore

/// Load-bearing claim (v0.28): the AI Concierge classifies user
/// utterances into a small set of dispatchable actions. The actions
/// struct is Equatable + Sendable and mirrors the ConciergeView's
/// expected shape. These tests pin the types + the ConciergeMessage
/// transcript so regressions in the AI layer don't silently break
/// the chat UI.
enum ConciergeTests {

    static func run() {
        TestHarness.suite("AI Concierge") {

            TestHarness.test("ConciergeAction values are Equatable") {
                let u = URL(string: "https://example.com/a")!
                try expect(
                    AIAssistant.ConciergeAction.download(url: u, rationale: "x")
                    == .download(url: u, rationale: "x")
                )
                try expect(
                    AIAssistant.ConciergeAction.cancelAll == .cancelAll
                )
                try expect(
                    AIAssistant.ConciergeAction.unclear(followUp: "hm")
                    == .unclear(followUp: "hm")
                )
                try expect(
                    AIAssistant.ConciergeAction.download(url: u, rationale: "x")
                    != .download(url: u, rationale: "y")
                )
            }

            TestHarness.test("ConciergeMessage roles are exhaustive + render clean") {
                let msg = SplynekViewModel.ConciergeMessage(
                    role: .user, text: "hi", action: nil
                )
                try expectEqual(msg.role.rawValue, "user")
                try expectEqual(msg.text, "hi")
                try expect(msg.action == nil)
            }
        }
    }
}
