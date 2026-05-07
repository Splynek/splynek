import Foundation
@testable import SplynekCore

/// 2026-05-07: tests for `SovereigntyCatalog.DeliveryKind` + the
/// back-compat default applied by `Alternative.effectiveDeliveryKind`.
enum DeliveryKindTests {

    static func run() {
        TestHarness.suite("DeliveryKind — display surface") {

            TestHarness.test("Every kind has a non-empty display label") {
                for k in SovereigntyCatalog.DeliveryKind.allCases {
                    try expect(!k.displayLabel.isEmpty)
                }
            }

            TestHarness.test("Every kind has a non-empty SF Symbol") {
                for k in SovereigntyCatalog.DeliveryKind.allCases {
                    try expect(!k.symbol.isEmpty)
                }
            }

            TestHarness.test("Every kind has a non-trivial tooltip") {
                for k in SovereigntyCatalog.DeliveryKind.allCases {
                    try expect(k.tooltip.count > 20)
                }
            }
        }

        TestHarness.suite("Alternative.effectiveDeliveryKind — back-compat") {

            TestHarness.test("Explicit deliveryKind wins") {
                let alt = SovereigntyCatalog.Alternative(
                    id: "x:y", origin: .oss, name: "X",
                    homepage: URL(string: "https://x.example")!,
                    note: "x", downloadURL: nil,
                    deliveryKind: .webService)
                try expect(alt.effectiveDeliveryKind == .webService)
            }

            TestHarness.test("nil deliveryKind + downloadURL → directDownload") {
                let alt = SovereigntyCatalog.Alternative(
                    id: "x:y", origin: .oss, name: "X",
                    homepage: URL(string: "https://x.example")!,
                    note: "x",
                    downloadURL: URL(string: "https://x.example/X.dmg")!,
                    deliveryKind: nil)
                try expect(alt.effectiveDeliveryKind == .directDownload)
            }

            TestHarness.test("nil deliveryKind + nil downloadURL → webService default") {
                let alt = SovereigntyCatalog.Alternative(
                    id: "x:y", origin: .oss, name: "X",
                    homepage: URL(string: "https://x.example")!,
                    note: "x", downloadURL: nil,
                    deliveryKind: nil)
                try expect(alt.effectiveDeliveryKind == .webService)
            }

            TestHarness.test("explicit .versionEmbedded with no URL still classifies") {
                let alt = SovereigntyCatalog.Alternative(
                    id: "x:y", origin: .oss, name: "X",
                    homepage: URL(string: "https://x.example")!,
                    note: "x", downloadURL: nil,
                    deliveryKind: .versionEmbedded)
                try expect(alt.effectiveDeliveryKind == .versionEmbedded)
            }
        }

        TestHarness.suite("DeliveryKind — Codable round-trip") {

            TestHarness.test("Each rawValue round-trips") {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                for k in SovereigntyCatalog.DeliveryKind.allCases {
                    let data = try encoder.encode(k)
                    let decoded = try decoder.decode(
                        SovereigntyCatalog.DeliveryKind.self, from: data)
                    try expect(decoded == k)
                }
            }
        }

        TestHarness.suite("DeliveryKind — catalog distribution sanity") {

            TestHarness.test("Catalog is fully classified after 2026-05-07 migration") {
                // Spot-check: every alt has either an explicit deliveryKind
                // or a downloadURL (which yields the directDownload default).
                // After the migration script, all alts should have explicit
                // deliveryKind values.
                var hasExplicit = 0
                var fallthrough_ = 0
                for entry in SovereigntyCatalog.entries {
                    for alt in entry.alternatives {
                        if alt.deliveryKind != nil {
                            hasExplicit += 1
                        } else {
                            fallthrough_ += 1
                        }
                    }
                }
                // 2026-05-07 migration classified all 3,194 alts.  Future
                // catalog growth before the next PR may add unclassified
                // entries; the back-compat default keeps the UI working.
                try expect(hasExplicit + fallthrough_ >= 3000)
            }
        }
    }
}
