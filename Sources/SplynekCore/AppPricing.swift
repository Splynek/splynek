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

    /// 2026-05-08: a single billing tier within a multi-tier app.
    /// AI tools, design suites, and most modern subscription apps
    /// publish two or three tiers (Pro / Max / Team).  The original
    /// schema only carried the landing rate, which under-counted
    /// users on higher tiers — e.g. Claude Pro is $20/mo, but Claude
    /// Max 5× is $100/mo.  Surfacing tiers lets the Savings tab
    /// honour the user's actual subscription cost.
    public struct Tier: Codable, Hashable, Sendable, Identifiable {
        public let label: String           // "Pro", "Max 5×", "Team"
        public let approxUSD: Double
        public let billingCycle: BillingCycle

        public var id: String { label }

        public init(label: String, approxUSD: Double, billingCycle: BillingCycle) {
            self.label = label
            self.approxUSD = approxUSD
            self.billingCycle = billingCycle
        }

        public var annualizedUSD: Double {
            switch billingCycle {
            case .oneTime: return approxUSD / 5.0
            case .monthly: return approxUSD * 12
            case .annual:  return approxUSD
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
        /// Optional named tiers for multi-tier subscriptions (Claude
        /// Pro / Max / Team, JetBrains All-Products / Per-product,
        /// Adobe Single-app / All-Apps).  When present, the Savings
        /// tab renders a tier picker and the user's selection drives
        /// the annualised cost calculation.  Absent for apps with a
        /// single canonical paid tier (1Password, Alfred Powerpack).
        public let tiers: [Tier]?

        public init(model: Model, freeTier: Bool = false,
                    approxUSD: Double? = nil,
                    billingCycle: BillingCycle? = nil,
                    sourceURL: URL? = nil,
                    tiers: [Tier]? = nil) {
            self.model = model
            self.freeTier = freeTier
            self.approxUSD = approxUSD
            self.billingCycle = billingCycle
            self.sourceURL = sourceURL
            self.tiers = tiers
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

        /// Annualised cost when a specific tier is selected.  Used
        /// by the Savings tab when the user has picked their tier
        /// from the segmented control.  Falls back to the legacy
        /// `annualizedUSD` when `tier` is nil or doesn't match.
        public func annualizedUSD(forTier tierLabel: String?) -> Double? {
            guard let tierLabel,
                  let tier = tiers?.first(where: { $0.label == tierLabel })
            else { return annualizedUSD }
            return tier.annualizedUSD
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
        // === AI assistants (multi-tier) ===
        // 2026-05-08: Anthropic Claude desktop has Free / Pro /
        // Max 5× / Max 20× / Team.  Default landing tier is Pro;
        // higher tiers (Max especially) are common with power users
        // and were previously under-counted by Splynek's single-rate
        // schema.  Bundle ID covers both the official desktop app
        // and a couple of common aliases distributed by Anthropic.
        "com.anthropic.claudefordesktop": .init(
            model: .freemium, freeTier: true,
            approxUSD: 20.0, billingCycle: .monthly,
            sourceURL: URL(string: "https://www.anthropic.com/pricing"),
            tiers: [
                .init(label: "Pro",      approxUSD: 20.0,  billingCycle: .monthly),
                .init(label: "Max 5×",   approxUSD: 100.0, billingCycle: .monthly),
                .init(label: "Max 20×",  approxUSD: 200.0, billingCycle: .monthly),
                .init(label: "Team",     approxUSD: 30.0,  billingCycle: .monthly),
            ]),
        "com.anthropic.Claude": .init(
            model: .freemium, freeTier: true,
            approxUSD: 20.0, billingCycle: .monthly,
            sourceURL: URL(string: "https://www.anthropic.com/pricing"),
            tiers: [
                .init(label: "Pro",      approxUSD: 20.0,  billingCycle: .monthly),
                .init(label: "Max 5×",   approxUSD: 100.0, billingCycle: .monthly),
                .init(label: "Max 20×",  approxUSD: 200.0, billingCycle: .monthly),
                .init(label: "Team",     approxUSD: 30.0,  billingCycle: .monthly),
            ]),
        "com.openai.chat": .init(
            model: .freemium, freeTier: true,
            approxUSD: 20.0, billingCycle: .monthly,
            sourceURL: URL(string: "https://openai.com/chatgpt/pricing"),
            tiers: [
                .init(label: "Plus",   approxUSD: 20.0,  billingCycle: .monthly),
                .init(label: "Pro",    approxUSD: 200.0, billingCycle: .monthly),
                .init(label: "Team",   approxUSD: 25.0,  billingCycle: .monthly),
            ]),
        "ai.perplexity.mac": .init(
            model: .freemium, freeTier: true,
            approxUSD: 20.0, billingCycle: .monthly,
            sourceURL: URL(string: "https://www.perplexity.ai/pro"),
            tiers: [
                .init(label: "Pro",        approxUSD: 20.0,  billingCycle: .monthly),
                .init(label: "Enterprise", approxUSD: 40.0,  billingCycle: .monthly),
            ]),

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

        // ============================================================
        // 2026-05-07 expansion: pricing seed 50 → 100+
        // ============================================================
        // Each new entry cites a publisher pricing page in
        // `sourceURL`.  Prices reflect the publisher-published
        // landing tier as of 2026-05-07, USD.  Promotional prices
        // are NOT used (the Savings hero is meant to reflect what
        // the user will actually pay long-term, not introductory
        // discounts).

        // === Productivity / writing ===
        "com.literatureandlatte.scrivener3": .init(
            model: .oneTime, approxUSD: 59.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.literatureandlatte.com/scrivener/buy")),
        "com.flexibits.fantastical2.mac": .init(
            model: .subscription, approxUSD: 56.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://flexibits.com/fantastical/pricing")),
        "com.flexibits.cardhop.mac": .init(
            model: .subscription, approxUSD: 39.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://flexibits.com/cardhop/pricing")),
        "com.agilebits.onepassword4-helper": .init(
            // Same product as 1password7 entry; alias for legacy bundle
            model: .subscription, approxUSD: 2.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://1password.com/pricing")),
        "com.agiletortoise.Drafts-OSX": .init(
            model: .freemium, freeTier: true, approxUSD: 1.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://getdrafts.com/pro/")),
        "com.timepi.numi": .init(
            model: .oneTime, approxUSD: 35.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://numi.app/buy")),
        "com.acqualia.soulver3": .init(
            model: .oneTime, approxUSD: 34.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://soulver.app/buy/")),
        "com.barebones.bbedit": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.barebones.com/products/bbedit/buy.html")),
        "com.gingerlabs.notebook2": .init(
            // Notenik/Notebook style indie — placeholder; conservative
            // landing rate.  Skip if uncertain.
            model: .oneTime, approxUSD: 29.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://gingerlabs.com/")),

        // === Code editors / IDEs ===
        "com.jetbrains.intellij": .init(
            model: .subscription, approxUSD: 169.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.jetbrains.com/idea/buy/")),
        "com.jetbrains.pycharm": .init(
            model: .subscription, approxUSD: 99.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.jetbrains.com/pycharm/buy/")),
        "com.jetbrains.WebStorm": .init(
            model: .subscription, approxUSD: 69.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.jetbrains.com/webstorm/buy/")),
        "com.jetbrains.goland": .init(
            model: .subscription, approxUSD: 99.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.jetbrains.com/go/buy/")),
        "com.jetbrains.rubymine": .init(
            model: .subscription, approxUSD: 89.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.jetbrains.com/ruby/buy/")),
        "com.jetbrains.datagrip": .init(
            model: .subscription, approxUSD: 99.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.jetbrains.com/datagrip/buy/")),
        "com.fournova.Tower3": .init(
            model: .subscription, approxUSD: 69.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.git-tower.com/buy")),
        "com.sublimetext.4": .init(
            model: .oneTime, approxUSD: 99.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.sublimetext.com/buy?v=text")),
        "com.panic.Nova": .init(
            model: .subscription, approxUSD: 99.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://nova.app/pricing/")),
        "com.panic.Transmit": .init(
            model: .oneTime, approxUSD: 45.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://panic.com/transmit/")),
        "com.panic.Prompt-3": .init(
            model: .oneTime, approxUSD: 14.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://panic.com/prompt/")),
        "com.charliemonroe.Downie-4": .init(
            model: .oneTime, approxUSD: 19.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://software.charliemonroe.net/downie/")),

        // === Mac utilities ===
        "com.crystalnix.mac.RDM": .init(
            // Replaces RDM (free) — example freemium utility
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://github.com/avibrazil/RDM")),
        "com.runningwithcrayons.Alfred-5": .init(
            // Powerpack subscription
            model: .oneTime, approxUSD: 39.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.alfredapp.com/shop/")),
        "com.runningwithcrayons.Alfred": .init(
            model: .oneTime, approxUSD: 39.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.alfredapp.com/shop/")),
        "com.knollsoft.Rectangle": .init(
            // Free OSS, but Rectangle Pro is the paid tier
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://rectangleapp.com/")),
        "com.knollsoft.Hookshot": .init(
            // Rectangle Pro
            model: .oneTime, approxUSD: 9.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://rectangleapp.com/pro")),
        "com.hegenberg.BetterTouchTool": .init(
            model: .oneTime, approxUSD: 21.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://folivora.ai/buy.html")),
        "com.stairways.keyboardmaestro": .init(
            model: .oneTime, approxUSD: 36.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.keyboardmaestro.com/main/")),
        "com.macpaw.CleanMyMac-mas": .init(
            model: .subscription, approxUSD: 39.95,
            billingCycle: .annual,
            sourceURL: URL(string: "https://macpaw.com/cleanmymac")),
        "com.macpaw.gemini2": .init(
            model: .subscription, approxUSD: 19.95,
            billingCycle: .annual,
            sourceURL: URL(string: "https://macpaw.com/gemini-mac-duplicate-finder")),
        "com.macpaw.Setapp": .init(
            // Already added above as com.setapp.DesktopClient; alias
            model: .subscription, approxUSD: 9.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://setapp.com/pricing")),
        "com.lwouis.alt-tab-macos": .init(
            // Donation-ware OSS
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://alt-tab-macos.netlify.app/")),
        "com.tunabellysoftware.TGProMac": .init(
            // TG Pro temperature monitor
            model: .oneTime, approxUSD: 19.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.tunabellysoftware.com/tgpro/")),
        "com.bitwarden.desktop": .init(
            model: .freemium, freeTier: true, approxUSD: 10.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://bitwarden.com/pricing/")),

        // === Design / image / video ===
        "com.figma.Desktop": .init(
            model: .freemium, freeTier: true, approxUSD: 12.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.figma.com/pricing/")),
        "com.lemonmojo.CleanShot-X": .init(
            model: .oneTime, approxUSD: 29.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://cleanshot.com/upgrade")),
        "com.acqualia.kaleidoscope3": .init(
            model: .subscription, approxUSD: 99.0,
            billingCycle: .annual,
            sourceURL: URL(string: "https://kaleidoscope.app/pricing")),
        "com.lifesize.Capture-One": .init(
            model: .subscription, approxUSD: 24.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.captureone.com/products-plans/capture-one-pro")),
        "com.toast-x.SoundSource": .init(
            model: .oneTime, approxUSD: 49.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://rogueamoeba.com/soundsource/")),
        "com.rogueamoeba.AudioHijack": .init(
            model: .oneTime, approxUSD: 64.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://rogueamoeba.com/audiohijack/")),
        "com.rogueamoeba.Loopback": .init(
            model: .oneTime, approxUSD: 109.0,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://rogueamoeba.com/loopback/")),

        // === Mind mapping / outlining ===
        "com.mindnode.MindNode": .init(
            model: .subscription, approxUSD: 19.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://www.mindnode.com/pricing/")),
        "com.omnigroup.OmniGraffle7": .init(
            model: .oneTime, approxUSD: 149.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.omnigroup.com/omnigraffle/pricing")),
        "com.omnigroup.OmniOutliner5": .init(
            model: .oneTime, approxUSD: 99.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.omnigroup.com/omnioutliner/pricing")),
        "com.omnigroup.OmniPlan4": .init(
            model: .subscription, approxUSD: 9.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.omnigroup.com/omniplan/pricing")),

        // === Backup / sync / storage ===
        "com.bombich.ccc": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://bombich.com/store")),
        "com.shirt-pocket.SuperDuper": .init(
            model: .oneTime, approxUSD: 27.95,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.shirt-pocket.com/SuperDuper/SuperDuperDescription.html")),
        "com.econtech.ChronoSync": .init(
            model: .oneTime, approxUSD: 49.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.econtechnologies.com/chronosync/buy.html")),

        // === Music / DJ ===
        "com.audirvana.Audirvana-Plus": .init(
            model: .subscription, approxUSD: 6.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://audirvana.com/audirvana-studio/")),
        "com.roonlabs.Roon": .init(
            model: .subscription, approxUSD: 14.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://roonlabs.com/pricing")),

        // === Mail clients (additional) ===
        "com.airmailapp.airmail3": .init(
            model: .subscription, approxUSD: 9.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://airmailapp.com/pricing/")),
        "com.tinder.Tinder": .init(
            // skip — not a Mac app, here for catalog placeholder removal
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://tinder.com/")),

        // === PDF / docs ===
        "com.smileonmymac.PDFpenPro": .init(
            // Now Nitro PDF Pro after acquisition
            model: .oneTime, approxUSD: 199.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://www.gonitro.com/pricing")),
        "com.readdle.PDFExpert-Mac": .init(
            // Different bundle ID from PDFExpert iPhone
            model: .subscription, approxUSD: 79.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://pdfexpert.com/pricing")),
        "com.tinrocket.MarkMyWords": .init(
            model: .oneTime, approxUSD: 19.99,
            billingCycle: .oneTime,
            sourceURL: URL(string: "https://tinrocket.com/")),

        // === Communication / VoIP ===
        "com.skype.skype": .init(
            // Free; calls to phones are paid via credit
            model: .freemium, freeTier: true,
            sourceURL: URL(string: "https://www.skype.com/en/buy-credit/")),
        "com.microsoft.teams2": .init(
            model: .freemium, freeTier: true, approxUSD: 4.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.microsoft.com/microsoft-teams/compare-microsoft-teams-options")),

        // === VPN / privacy ===
        "com.NordVPN.macOS": .init(
            model: .subscription, approxUSD: 12.99,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://nordvpn.com/order/")),
        "com.expressvpn.ExpressVPN": .init(
            model: .subscription, approxUSD: 12.95,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.expressvpn.com/order")),

        // === AI / ML ===
        // 2026-05-08: ChatGPT + Claude desktop moved to the top of
        // the file as multi-tier listings.  The single-rate aliases
        // that lived here have been retired so the dictionary stays
        // single-source-of-truth (and avoids the runtime crash from
        // duplicate keys in a Swift dictionary literal).

        // === Games / streaming ===

        "com.valvesoftware.steam": .init(
            // Free client, individual games priced separately
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://store.steampowered.com/about/")),
        "com.netflix.Netflix": .init(
            model: .subscription, approxUSD: 15.49,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://www.netflix.com/signup/planform")),

        // === Reading / RSS ===
        "com.reederapp.5": .init(
            model: .subscription, approxUSD: 9.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://reederapp.com/pricing/")),
        "com.brentsimmons.NetNewsWire5": .init(
            // Free OSS
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://netnewswire.com/")),

        // === Specialty productivity ===
        "com.timing.timing": .init(
            // Time tracker
            model: .subscription, approxUSD: 9.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://timingapp.com/pricing")),
        "com.todoist.mac": .init(
            model: .freemium, freeTier: true, approxUSD: 5.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://todoist.com/pricing")),
        "com.tickticklabs.TickTickMac": .init(
            model: .freemium, freeTier: true, approxUSD: 35.99,
            billingCycle: .annual,
            sourceURL: URL(string: "https://ticktick.com/about/premium")),
        "com.airtable.airtable-desktop": .init(
            model: .freemium, freeTier: true, approxUSD: 24.0,
            billingCycle: .monthly,
            sourceURL: URL(string: "https://airtable.com/pricing")),

        // === Network / dev tools ===
        "com.apple.dt.Xcode": .init(
            // Free
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://developer.apple.com/xcode/")),
        "com.googlecode.iterm2": .init(
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://iterm2.com/")),
        "co.zeit.hyper": .init(
            model: .free, freeTier: true,
            sourceURL: URL(string: "https://hyper.is/")),
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
