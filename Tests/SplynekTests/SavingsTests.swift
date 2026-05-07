import Foundation
@testable import SplynekCore

/// 2026-05-07 product expansion phase 2: tests for AppPricing
/// schema invariants + the SavingsSummary computation.
enum SavingsTests {

    static func run() {
        TestHarness.suite("AppPricing — schema invariants") {

            TestHarness.test("Every pricing record has a non-empty source") {
                for (bid, p) in AppPricing.seedPrices {
                    if p.model != .free && p.approxUSD != nil {
                        try expect(p.sourceURL != nil,
                                   "\(bid) is paid but has no sourceURL")
                    }
                }
            }

            TestHarness.test("Every paid pricing has approxUSD + billingCycle") {
                for (bid, p) in AppPricing.seedPrices {
                    if p.model == .subscription || p.model == .oneTime {
                        try expect(p.approxUSD != nil,
                                   "\(bid) (model=\(p.model.rawValue)) has no approxUSD")
                        try expect(p.billingCycle != nil,
                                   "\(bid) has no billingCycle")
                    }
                }
            }

            TestHarness.test("Bundle IDs are unique (dictionary invariant)") {
                let count = AppPricing.seedPrices.count
                let unique = Set(AppPricing.seedPrices.keys).count
                try expect(count == unique)
            }

            TestHarness.test("Seed dataset covers a meaningful slice (≥30 apps)") {
                try expect(AppPricing.seedPrices.count >= 30)
            }
        }

        TestHarness.suite("AppPricing — annualizedUSD computation") {

            TestHarness.test("Monthly $10 → $120/yr") {
                let p = AppPricing.Pricing(
                    model: .subscription, approxUSD: 10,
                    billingCycle: .monthly)
                try expect(p.annualizedUSD == 120)
            }

            TestHarness.test("Annual $99 → $99/yr") {
                let p = AppPricing.Pricing(
                    model: .subscription, approxUSD: 99,
                    billingCycle: .annual)
                try expect(p.annualizedUSD == 99)
            }

            TestHarness.test("One-time $50 → $10/yr (5y amortization)") {
                let p = AppPricing.Pricing(
                    model: .oneTime, approxUSD: 50,
                    billingCycle: .oneTime)
                try expect(p.annualizedUSD == 10)
            }

            TestHarness.test("Free → nil annualized") {
                let p = AppPricing.Pricing(
                    model: .free, freeTier: true)
                try expect(p.annualizedUSD == nil)
            }

            TestHarness.test("Pricing without approxUSD → nil annualized") {
                let p = AppPricing.Pricing(model: .freemium, freeTier: true)
                try expect(p.annualizedUSD == nil)
            }
        }

        TestHarness.suite("AppPricing — Codable round-trip") {

            TestHarness.test("Pricing struct round-trips") {
                let original = AppPricing.Pricing(
                    model: .subscription, freeTier: false,
                    approxUSD: 19.99, billingCycle: .monthly,
                    sourceURL: URL(string: "https://example.com/pricing"))
                let data = try JSONEncoder().encode(original)
                let decoded = try JSONDecoder().decode(AppPricing.Pricing.self, from: data)
                try expect(decoded.model == .subscription)
                try expect(decoded.approxUSD == 19.99)
                try expect(decoded.billingCycle == .monthly)
                try expect(decoded.sourceURL?.host == "example.com")
            }
        }

        TestHarness.suite("AppPricing.Model + BillingCycle — display labels") {

            TestHarness.test("Every Model has a non-empty label") {
                for m in AppPricing.Model.allCases {
                    try expect(!m.displayLabel.isEmpty)
                }
            }
            TestHarness.test("Every BillingCycle has a non-empty label") {
                for b in AppPricing.BillingCycle.allCases {
                    try expect(!b.displayLabel.isEmpty)
                }
            }
        }

        TestHarness.suite("AppPricing.supportedBundleIDs") {

            TestHarness.test("Set matches dictionary keys") {
                try expect(AppPricing.supportedBundleIDs.count
                           == AppPricing.seedPrices.count)
            }

            TestHarness.test("Adobe Photoshop is covered (sanity check)") {
                try expect(AppPricing.pricing(for: "com.adobe.Photoshop") != nil)
                try expect(AppPricing.pricing(for: "com.adobe.Photoshop")?.model == .subscription)
            }
        }
    }
}
