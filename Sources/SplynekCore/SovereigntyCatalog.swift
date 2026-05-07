import Foundation

/// The alternatives catalog — maps installed Mac apps to European
/// or open-source alternatives.
///
/// **v1.4: JSON-backed pipeline.**  The actual entries live in
/// `Scripts/sovereignty-catalog.json` and the Swift array in
/// `SovereigntyCatalog+Entries.swift` is regenerated from there by
/// `Scripts/regenerate-sovereignty-catalog.swift`.  Edit the JSON,
/// not the Swift.  See `SOVEREIGNTY-CONTRIBUTING.md` for the full
/// pipeline including discovery, AI-drafted proposals, and human
/// review.
///
/// Framing: the tab is about **EU digital sovereignty**, not about
/// any one country.  An app controlled by a US corporation and an
/// app controlled by a Chinese corporation are in the same bucket
/// from the perspective of a European user concerned with jurisdiction,
/// data residency, GDPR applicability, and supply-chain risk.  We
/// surface the target's origin so the user sees *where control sits*,
/// and we recommend European or open-source alternatives because
/// those are the two buckets that most reduce non-EU dependence.
///
/// Catalog size: ~1150 entries as of v1.4 (up from 90 at v1.3 via
/// the bulk-seed + discovery pipeline).  Goal isn't to be exhaustive
/// — it's to surface high-quality alts the user can act on today.
/// Community PRs grow the catalog further by editing the JSON.
///
/// Design principles for new entries:
///
///   1. **Alternatives must be real and shippable.**  No vapourware.
///      Link to an actual download page.
///   2. **European ecosystem = EU member state + EEA + UK + Switzerland.**
///      Pragmatic definition that matches the region users think of
///      as "not-non-EU."  Call out the country in the note —
///      "Mullvad (Sweden)", "Proton (Switzerland)" etc.
///   3. **OSS = genuinely open-source, usable license.**  GPL / MIT /
///      BSD / MPL / Apache.  "Source-available" or "commons clause"
///      doesn't count.
///   4. **One or two alternatives per target.**  Choice paralysis
///      kills action.
///   5. **Never shame the original.**  The tone is "here's a door
///      out if you want one," not "you should feel bad about having
///      Chrome installed."
///   6. **Origin-neutral targeting.**  Any app whose vendor sits
///      outside the European ecosystem is a valid target — not just
///      US apps.  Chinese, Russian, other jurisdictions all count.
enum SovereigntyCatalog {

    /// Where an app (or its alternative) is controlled from.
    ///
    /// For *targets*: any value is valid — describes where the user's
    /// installed app's control sits.
    /// For *alternatives*: we only recommend `.europe`, `.oss`, or
    /// `.europeAndOSS`.  Those are the buckets that reduce non-EU
    /// dependency.
    enum Origin: String, Codable, CaseIterable, Identifiable, Sendable {
        /// EU member state, EEA, UK, or Switzerland.  The pragmatic
        /// "European tech ecosystem" definition.
        case europe
        /// Open-source (recognized license, jurisdiction-agnostic).
        case oss
        /// Both European AND open-source.
        case europeAndOSS
        /// United States.  The largest single origin of installed
        /// Mac apps, but not the only one flagged.
        case unitedStates
        /// China.
        case china
        /// Russia.
        case russia
        /// Anywhere else (Canada, Japan, Korea, Australia, etc.).
        /// Put the specific country in the entry's note.
        case other

        var id: String { rawValue }

        /// Short UI label — rendered as a coloured badge.
        var label: String {
            switch self {
            case .europe:        return "EU"
            case .oss:           return "OSS"
            case .europeAndOSS:  return "EU + OSS"
            case .unitedStates:  return "US"
            case .china:         return "CN"
            case .russia:        return "RU"
            case .other:         return "OTHER"
            }
        }

        /// True when this origin represents an alternative we'd
        /// positively recommend — i.e. European or open-source.
        /// Used by the UI filter + by guards that prevent us from
        /// accidentally suggesting a US app as an "alternative" to
        /// another US app.
        var isRecommendable: Bool {
            self == .europe || self == .oss || self == .europeAndOSS
        }

        /// v1.4: spoken-language description for VoiceOver.  The
        /// visual badge label ("EU", "US") is too terse for screen
        /// readers — it gets pronounced as "ee yoo" / "you ess",
        /// which obscures the meaning.  This expanded form is used
        /// as the badge's `.accessibilityLabel(_:)`.
        var accessibilityLabel: String {
            switch self {
            case .europe:        return "European origin"
            case .oss:           return "Open-source"
            case .europeAndOSS:  return "European and open-source"
            case .unitedStates:  return "United States origin"
            case .china:         return "China origin"
            case .russia:        return "Russia origin"
            case .other:         return "Other non-European origin"
            }
        }
    }

    /// What kind of distribution channel an alternative ships
    /// through.  Drives both the badge and the call-to-action button
    /// the UI surfaces — replaces the binary "downloadURL or not"
    /// fallback that confused users into expecting a DMG and getting
    /// a SaaS sign-up wall instead.
    ///
    /// 2026-05-07: introduced after the Sovereignty coverage push
    /// found that ~92% of alternatives don't have a `downloadURL`,
    /// for legitimate reasons that the UI never communicated.
    enum DeliveryKind: String, Codable, Hashable, Sendable, CaseIterable {
        /// Stable, canonical DMG / PKG / ZIP — `downloadURL` resolves
        /// to a binary Content-Type.  Splynek installs in one click.
        case directDownload
        /// Native Mac app, but distributed exclusively via Mac App
        /// Store.  UI deep-links to `macappstore://…` instead of
        /// trying to download.
        case macAppStore
        /// No native Mac app exists — service is web-only (Mastodon,
        /// Bluesky, Mailbox.org, Plausible, etc.).  UI says "Open"
        /// and skips any "Install" pretense.
        case webService
        /// Native CLI / app distributed via Homebrew.  UI offers a
        /// "Copy `brew install …`" affordance.
        case homebrew
        /// Native Mac app exists but downloading requires a free
        /// account (Tuta, some Proton tiers, etc.).
        case signupRequired
        /// Native Mac app exists but downloading requires payment
        /// (F-Secure, MUBI client, ClamXAV, Spotify-paid-only, etc.).
        case purchaseRequired
        /// Native Mac app exists with a publisher-canonical URL,
        /// but the URL embeds a version number that won't survive
        /// a release.  The auto-prune cron watches for breakage.
        /// UI behaves like .directDownload until the verifier flags it.
        case versionEmbedded
        /// Desktop app announced but not yet shipped (rare; e.g. a
        /// publicly-promised port).  UI is "Visit (in development)".
        case comingSoon

        /// Short user-facing label for the badge ("Direct download",
        /// "App Store", "Web service", …).
        var displayLabel: String {
            switch self {
            case .directDownload:    return "Direct download"
            case .macAppStore:       return "App Store"
            case .webService:        return "Web service"
            case .homebrew:          return "Homebrew"
            case .signupRequired:    return "Account required"
            case .purchaseRequired:  return "Purchase required"
            case .versionEmbedded:   return "Direct download"
            case .comingSoon:        return "In development"
            }
        }

        /// SF Symbol name used in the UI badge.
        var symbol: String {
            switch self {
            case .directDownload:    return "arrow.down.circle.fill"
            case .macAppStore:       return "apple.logo"
            case .webService:        return "globe"
            case .homebrew:          return "terminal"
            case .signupRequired:    return "person.crop.circle.badge.questionmark"
            case .purchaseRequired:  return "creditcard"
            case .versionEmbedded:   return "arrow.down.circle.fill"
            case .comingSoon:        return "hammer"
            }
        }

        /// Tooltip explainer surfaced on hover / long-press.  Each
        /// reads as a calm factual sentence, not editorial framing.
        var tooltip: String {
            switch self {
            case .directDownload:
                return "One-click install via Splynek. Verified binary download URL."
            case .macAppStore:
                return "Distributed exclusively via the Mac App Store. Opens Apple's App Store app to install."
            case .webService:
                return "No native Mac app — runs in your browser."
            case .homebrew:
                return "Install via Homebrew. Tap to copy the brew install command."
            case .signupRequired:
                return "Free Mac app, but downloading requires creating an account on the publisher's site."
            case .purchaseRequired:
                return "Mac app exists, but downloading requires payment on the publisher's site."
            case .versionEmbedded:
                return "Direct download. The auto-pruner watches this URL weekly — if a publisher releases a new version with a different filename, the URL is dropped."
            case .comingSoon:
                return "Desktop app announced by the publisher but not yet shipped. Splynek tracks the project page."
            }
        }
    }

    struct Alternative: Codable, Identifiable, Hashable, Sendable {
        let id: String          // stable key, "<targetBundleID>:<slug>"
        let origin: Origin
        let name: String
        let homepage: URL
        /// One-line note shown under the alternative in the UI.
        /// Include country + license so users can decide at a glance.
        let note: String
        /// v1.2: optional direct-download URL for one-click install
        /// via Splynek.  When present, the UI shows an "Install"
        /// button that hands the URL to Splynek's download engine.
        /// When absent, the UI shows a "Visit" button that opens
        /// `homepage` in the default browser.
        ///
        /// We populate this only for alternatives with stable,
        /// canonical download URLs (e.g. `releases.latest/download/
        /// …` patterns).  Apps that require a version-specific path
        /// or a platform picker are left homepage-only to avoid
        /// hallucinating stale URLs — the user takes one click
        /// more but lands on a real page.
        let downloadURL: URL?
        /// 2026-05-07: explicit distribution channel.  Drives the
        /// UI's badge + CTA-button choice.  Optional in the JSON
        /// schema for back-compat with pre-2026-05-07 entries —
        /// the regenerator infers a sensible default at load time
        /// (`directDownload` if `downloadURL != nil`, otherwise
        /// `webService` as the most common no-download case).
        let deliveryKind: DeliveryKind?

        init(id: String, origin: Origin, name: String,
             homepage: URL, note: String, downloadURL: URL? = nil,
             deliveryKind: DeliveryKind? = nil) {
            self.id = id
            self.origin = origin
            self.name = name
            self.homepage = homepage
            self.note = note
            self.downloadURL = downloadURL
            self.deliveryKind = deliveryKind
        }

        /// Resolves the effective delivery kind, applying the back-
        /// compat default when `deliveryKind` is nil.  UI callers
        /// use this rather than the raw stored value.
        public var effectiveDeliveryKind: DeliveryKind {
            if let k = deliveryKind { return k }
            return downloadURL != nil ? .directDownload : .webService
        }
    }

    struct Entry: Codable, Hashable, Sendable {
        let targetBundleID: String
        let targetDisplayName: String   // as shown in UI when listing
        /// Where the target app is controlled from.  Surfaced in the
        /// UI as a small badge next to the app name, so the user sees
        /// at a glance *why* we're suggesting an alternative.
        let targetOrigin: Origin
        let alternatives: [Alternative]
    }

    // The full catalog lives in a generated file to keep this one
    // readable.  JSON source:     Scripts/sovereignty-catalog.json
    //                 Generator:  swift Scripts/regenerate-sovereignty-catalog.swift
    // See SOVEREIGNTY-CONTRIBUTING.md for the pipeline.
    //
    // Invariants (enforced by `SovereigntyCatalogTests`):
    //   • every target has `targetOrigin` outside the European
    //     ecosystem — apps that are already sovereign don't need
    //     alternatives.
    //   • every alternative is `.europe` / `.oss` / `.europeAndOSS`
    //     or `.other` (AU/CA/SG/JP…).  The catalog NEVER suggests a
    //     US/CN/RU alternative — that defeats the purpose.
    //   • every entry has at least one recommendable (EU/OSS) pick
    //     so the sovereignty filters never come up empty.

    /// Build a fast lookup map by bundle ID.  Done lazily because
    /// `entries` has potential duplicates for rebranded bundle IDs
    /// (Teams new/old, 1Password 7/8) — first-match-wins here.
    private static let byBundleID: [String: Entry] = {
        var m: [String: Entry] = [:]
        for e in entries where m[e.targetBundleID] == nil {
            m[e.targetBundleID] = e
        }
        return m
    }()

    /// Look up alternatives for a specific bundle ID.  Returns nil if
    /// the app isn't in the catalog — the UI can then optionally ask
    /// the local LLM for suggestions (v1.3 feature).
    static func alternatives(for bundleID: String) -> Entry? {
        byBundleID[bundleID]
    }
}
