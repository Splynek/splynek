// Copyright © 2026 Splynek. MIT.
//
// AppPricing — pure schema + seed dataset for the Savings tab
// (2026-05-07).  Maps installed bundle IDs to pricing facts so the
// Savings tab can:
//
//   1. Total a user's annual spend across installed paid apps.
//   2. Surface free alternatives where Sovereignty has them.
//   3. Show concrete potential savings ("Switch to GIMP — save
//      $239.88/yr from Photoshop").
//
// Data accuracy: pricing changes (new Adobe tier, regional VAT,
// promotional rates).  This file is the seed — maintainers
// (and a future weekly cron, mirroring sovereignty-weekly.yml)
// keep it fresh.  Same threat model as the Trust catalog: each
// price MUST cite a source URL the maintainer can re-verify.
//
// The schema is intentionally minimal — model + freeTier flag +
// approxUSD + billingCycle + sourceURL.  No promotions, no
// regional pricing, no upgrade discounts: the Savings tab is a
// rough "are you spending more than you need to?" signal, not a
// licensing oracle.

import Foundation

public enum AppPricing {

    public enum Model: String, Codable, Hashable, Sendable, CaseIterable {
        /// Free / OSS / Mac App Store free tier.
        case free
        /// One-time purchase (Things 3, Bear with the lifetime
        /// upgrade, Affinity Suite v2, etc.).
        case oneTime
        /// Monthly or annual subscription (Adobe CC, Setapp,
        /// Spotify, 1Password).
        case subscription
        /// Has both a usable free tier and a paid upgrade path
        /// (Bitwarden free vs Premium, ProtonMail free vs Plus,
        /// Notion free vs Plus).
        case freemium
        /// Time-limited trial then paid (e.g. some pro photography
        /// tools).  Treated as `subscription` for cost calculations.
        case trial

        public var displayLabel: String {
            switch self {
            case .free:         return "Free"
            case .oneTime:      return "One-time"
            case .subscription: return "Subscription"
            case .freemium:     return "Freemium"
            case .trial:        return "Trial"
            }
        }
    }

    public enum BillingCycle: String, Codable, Hashable, Sendable, CaseIterable {
        case oneTime
        case monthly
        case annual

        public var displayLabel: String {
            switch self {
            case .oneTime: return "one-time"
            case .monthly: return "month"
            case .annual:  return "year"
            }
        }
    }

    public struct Pricing: Codable, Hashable, Sendable {
        public let model: Model
        /// True when there's a usable free tier (covers most
        /// .free + .freemium cases).  The Savings tab uses this to
        /// decide whether to suggest "you can use this for free
        /// today" alongside paid alternatives.
        public let freeTier: Bool
        /// Approximate cost in USD when the model is paid.  nil
        /// when .free.  Picked to be the "default landing" tier
        /// most users would see — not the cheapest, not the most
        /// expensive.
        public let approxUSD: Double?
        public let billingCycle: BillingCycle?
        /// URL to the publisher's pricing page where the value
        /// can be verified.  Required for paid models so the
        /// Savings tab can link to it.
        public let sourceURL: URL?

        public init(model: Model, freeTier: Bool = false,
                    approxUSD: Double? = nil,
                    billingCycle: BillingCycle? = nil,
                    sourceURL: URL? = nil) {
            self.model = model
            self.freeTier = freeTier
            self.approxUSD = approxUSD
            self.billingCycle = billingCycle
            self.sourceURL = sourceURL
        }

        /// Cost normalized to USD/year.  One-time purchases are
        /// amortized over 5 years (Splynek's chosen "average paid-
        /// app lifetime" — short enough to honor the user's actual
        /// usage pattern; long enough to differentiate from
        /// subscriptions in the Savings hero).
        public var annualizedUSD: Double? {
            guard let p = approxUSD else { return nil }
            switch billingCycle {
            case .oneTime: return p / 5.0
            case .monthly: return p * 12
            case .annual:  return p
            case nil:      return nil
            }
        }
    }

    /// Seed dataset.  Bundle ID → pricing.  This is the starting
    /// point for the Savings tab; maintainers + a future weekly
    /// cron extend it.  Each entry's `sourceURL` is the publisher's
    /// pricing page as of 2026-05-07.
    ///
    /// Roughly ordered: subscriptions first (largest annual cost,
    /// biggest savings opportunities), then one-time purchases,
    /// then freemium tiers.  Cost values are publisher-published
    /// monthly/annual rates rounded to whole dollars where possible.
    public static let seedPrices: [String: Pricing] = [
        // === Adobe Creative Cloud (subscription) ===
        // All Adobe macOS apps share the same CC subscription model.
        // We cite the "All Apps" plan as the typical landing rate.
        "com.adobe.acc.AdobeCreativeCloud": .init(
            model: .subscription, approxUSD: 59.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/creativecloud/plans.html")),
        "com.adobe.Photoshop": .init(
            model: .subscription, approxUSD: 22.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/products/photoshop.html")),
        "com.adobe.LightroomCC": .init(
            model: .subscription, approxUSD: 9.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/products/photoshop-lightroom.html")),
        "com.adobe.Acrobat.Pro": .init(
            model: .subscription, approxUSD: 19.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/acrobat/pricing.html")),
        "com.adobe.spark": .init(
            model: .freemium, freeTier: true, approxUSD: 9.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/express/pricing")),
        "com.adobe.illustrator": .init(
            model: .subscription, approxUSD: 22.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/products/illustrator.html")),
        "com.adobe.InDesign": .init(
            model: .subscription, approxUSD: 22.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/products/indesign.html")),
        "com.adobe.Premiere": .init(
            model: .subscription, approxUSD: 22.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/products/premiere.html")),
        "com.adobe.AfterEffects": .init(
            model: .subscription, approxUSD: 22.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.adobe.com/products/aftereffects.html")),

        // === Microsoft 365 (subscription) ===
        "com.microsoft.Word": .init(
            model: .subscription, approxUSD: 6.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.microsoft.com/microsoft-365/buy/compare-all-microsoft-365-products")),
        "com.microsoft.Excel": .init(
            model: .subscription, approxUSD: 6.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.microsoft.com/microsoft-365/buy/compare-all-microsoft-365-products")),
        "com.microsoft.Powerpoint": .init(
            model: .subscription, approxUSD: 6.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.microsoft.com/microsoft-365/buy/compare-all-microsoft-365-products")),
        "com.microsoft.Outlook": .init(
            model: .subscription, approxUSD: 6.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.microsoft.com/microsoft-365/buy/compare-all-microsoft-365-products")),
        "com.microsoft.OneDrive-mac": .init(
            model: .freemium, freeTier: true, approxUSD: 1.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.microsoft.com/microsoft-365/onedrive/online-cloud-storage")),

        // === Streaming (subscription) ===
        "com.spotify.client": .init(
            model: .freemium, freeTier: true, approxUSD: 11.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.spotify.com/premium/")),
        "com.apple.Music": .init(
            model: .subscription, approxUSD: 10.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.apple.com/apple-music/")),
        "com.amazon.music.mac": .init(
            model: .freemium, freeTier: true, approxUSD: 10.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.amazon.com/music/unlimited")),

        // === Notes / writing (one-time + subscription) ===
        "com.culturedcode.ThingsMac": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://culturedcode.com/things/buy/")),
        "net.shinyfrog.bear": .init(
            model: .freemium, freeTier: true, approxUSD: 14.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://bear.app/pro/")),
        "com.omnigroup.OmniFocus3": .init(
            model: .subscription, approxUSD: 9.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.omnigroup.com/omnifocus/pricing")),
        "com.dayoneapp.DayOne-Mac": .init(
            model: .subscription, approxUSD: 34.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://dayoneapp.com/buy/")),
        "com.devon-technologies.thinkpro2": .init(
            model: .oneTime, approxUSD: 99.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.devontechnologies.com/apps/devonthink/pricing")),
        "com.ulyssesapp.mac": .init(
            model: .subscription, approxUSD: 5.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://ulysses.app/pricing")),
        "pro.writer.mac": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://ia.net/writer/pricing")),

        // === Design tools (subscription / one-time) ===
        "com.bohemiancoding.sketch3": .init(
            model: .subscription, approxUSD: 12.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.sketch.com/pricing/")),
        "com.seriflabs.affinityphoto2": .init(
            model: .oneTime, approxUSD: 69.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://affinity.serif.com/photo/")),
        "com.seriflabs.affinitydesigner2": .init(
            model: .oneTime, approxUSD: 69.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://affinity.serif.com/designer/")),
        "com.pixelmatorteam.pixelmator.x": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.pixelmator.com/pro/")),

        // === Password managers (subscription) ===
        "com.agilebits.onepassword7": .init(
            model: .subscription, approxUSD: 2.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://1password.com/pricing")),
        "com.lastpass.LastPass": .init(
            model: .freemium, freeTier: true, approxUSD: 3.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.lastpass.com/pricing")),
        "com.dashlane.dashlanephonefinal": .init(
            model: .freemium, freeTier: true, approxUSD: 4.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.dashlane.com/pricing")),

        // === Cloud storage (freemium) ===
        "com.dropbox.dropbox": .init(
            model: .freemium, freeTier: true, approxUSD: 11.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.dropbox.com/plans")),
        "com.google.drivefs": .init(
            model: .freemium, freeTier: true, approxUSD: 1.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://one.google.com/about/plans")),
        "com.box.iosapp": .init(
            model: .freemium, freeTier: true, approxUSD: 14.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.box.com/pricing")),

        // === Productivity / aggregators ===
        "com.setapp.DesktopClient": .init(
            model: .subscription, approxUSD: 9.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://setapp.com/pricing")),
        "notion.id": .init(
            model: .freemium, freeTier: true, approxUSD: 10.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.notion.so/pricing")),

        // === Mail / calendar (subscription) ===
        "com.readdle.smartemail-Mac": .init(
            model: .freemium, freeTier: true, approxUSD: 4.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://sparkmailapp.com/pricing")),
        "com.mimestream.Mimestream": .init(
            model: .subscription, approxUSD: 5.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://mimestream.com/pricing")),

        // === Backup ===
        "com.haystacksoftware.Arq6": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.arqbackup.com/pricing/")),
        "com.backblaze.bzbmenu": .init(
            model: .subscription, approxUSD: 9.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.backblaze.com/cloud-backup/pricing")),

        // === Antivirus (subscription) ===
        "com.fsecure.SAFE": .init(
            model: .subscription, approxUSD: 39.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.f-secure.com/total")),
        "com.intego.NetUpdate": .init(
            model: .subscription, approxUSD: 49.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.intego.com/mac-internet-security")),

        // === Video editing (subscription) ===
        "com.blackmagic-design.DaVinciResolve": .init(
            // Free version exists; Studio is the paid tier
            model: .freemium, freeTier: true, approxUSD: 295.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.blackmagicdesign.com/products/davinciresolve")),
        "com.apple.FinalCut": .init(
            model: .oneTime, approxUSD: 299.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.apple.com/final-cut-pro/")),
        "com.apple.logic10": .init(
            model: .oneTime, approxUSD: 199.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.apple.com/logic-pro/")),

        // === Communication (freemium) ===
        "com.tinyspeck.slackmacgap": .init(
            model: .freemium, freeTier: true, approxUSD: 8.75,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://slack.com/pricing")),
        "us.zoom.xos": .init(
            model: .freemium, freeTier: true, approxUSD: 14.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://zoom.us/pricing")),
    ]

    /// Look up pricing for a bundle ID.  Returns nil when we
    /// have no data — caller treats that as "unknown" (greyed-out
    /// in the UI rather than asserted as free).
    public static func pricing(for bundleID: String) -> Pricing? {
        seedPrices[bundleID]
    }

    /// All bundle IDs the seed dataset covers.  Useful for the
    /// Savings tab's "supported" badge and for the unit tests'
    /// "no duplicates" invariant.
    public static var supportedBundleIDs: Set<String> {
        Set(seedPrices.keys)
    }
}
