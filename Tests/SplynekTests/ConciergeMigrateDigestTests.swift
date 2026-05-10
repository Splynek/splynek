import Foundation
@testable import SplynekCore

/// Tests for the Concierge `migrate_review_digest` handler.
/// Sprint 3 (2026-05-10).
enum ConciergeMigrateDigestTests {

    static func run() {
        TestHarness.suite("Concierge migrate_review_digest") {

            func entry(_ bundle: String, _ name: String, _ alt: String,
                       _ markedAt: String) -> SovereigntyMigrateReviewEntry {
                SovereigntyMigrateReviewEntry(
                    bundleID: bundle,
                    originalDisplayName: name,
                    alternativeName: alt,
                    alternativeHomepage: URL(string: "https://example.invalid/")!,
                    markedAt: markedAt
                )
            }

            func textOf(_ card: ConciergeCard) -> String {
                if case .text(let s) = card { return s }
                return "<not text: \(card)>"
            }

            TestHarness.test("Empty list returns 'list is empty' guidance") {
                var bridge = LiveConciergeBridge()
                bridge.migrateReviewFixture = .empty
                let result = await bridge.dispatch(
                    ConciergeInvocation(
                        tool: ConciergeToolRegistry.migrateReviewDigest.id,
                        args: .object([:])
                    )
                )
                let text = textOf(result.card)
                try expect(text.lowercased().contains("empty"),
                           "expected empty-list guidance, got: \(text)")
            }

            TestHarness.test("Non-empty list summarises count + names") {
                var bridge = LiveConciergeBridge()
                bridge.migrateReviewFixture = SovereigntyMigrateReviewList(entries: [
                    entry("com.spotify.client", "Spotify", "Tidal",
                          "2026-05-09T00:00:00Z"),
                    entry("com.adobe.Photoshop", "Adobe Photoshop", "Affinity Photo",
                          "2026-05-09T00:00:00Z"),
                ])
                let result = await bridge.dispatch(
                    ConciergeInvocation(
                        tool: ConciergeToolRegistry.migrateReviewDigest.id,
                        args: .object([:])
                    )
                )
                let text = textOf(result.card)
                try expect(text.contains("2 app"),
                           "expected count of 2, got: \(text)")
                try expect(text.contains("Spotify"),
                           "expected Spotify name, got: \(text)")
                try expect(text.contains("Tidal"),
                           "expected Tidal name, got: \(text)")
            }

            TestHarness.test("Stale entries (>7 days) trigger nudge line") {
                var bridge = LiveConciergeBridge()
                let f = ISO8601DateFormatter()
                f.formatOptions = [.withInternetDateTime]
                let weekAgo = f.string(from: Date().addingTimeInterval(-8 * 86_400))
                bridge.migrateReviewFixture = SovereigntyMigrateReviewList(entries: [
                    entry("com.old.app", "Old App", "New App", weekAgo),
                ])
                let result = await bridge.dispatch(
                    ConciergeInvocation(
                        tool: ConciergeToolRegistry.migrateReviewDigest.id,
                        args: .object([:])
                    )
                )
                let text = textOf(result.card)
                try expect(text.lowercased().contains("week"),
                           "expected stale-week nudge, got: \(text)")
            }

            TestHarness.test("Tool is in the registry's allTools") {
                let names = ConciergeToolRegistry.allTools.map(\.id)
                try expect(names.contains("migrate_review_digest"),
                           "tool not registered: \(names)")
            }
        }
    }
}
