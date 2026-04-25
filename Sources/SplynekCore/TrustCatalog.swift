import Foundation

/// v1.5: the **Trust** catalog — surfaces public-record concerns
/// (App Store privacy labels, regulatory enforcement actions, CVEs,
/// confirmed breaches, vendor security advisories) for installed
/// Mac apps so users can make informed choices.
///
/// **MAS-safe by design.**  Every concern in this catalog cites a
/// PRIMARY SOURCE that the user can verify themselves: Apple's own
/// App Store privacy nutrition labels, EU Data Protection Authority
/// rulings, FTC consent orders, court records, the NVD CVE database,
/// vendor security advisories, or the universally-cited HIBP breach
/// corpus.  We never editorialise — we surface public record.
///
/// The legal model: this is **journalistic aggregation**.  Apple
/// publishes privacy labels.  DPAs publish fines.  HIBP publishes
/// breach data.  We index the apps a user has installed against
/// those public sources and present the result.  Apple themselves
/// requires developers to publish privacy labels precisely so users
/// can make informed choices — this tab amplifies that programme.
///
/// **What this catalog DOES NOT do:**
///   • No subjective opinions ("this app is bad").
///   • No accusations not backed by a primary-source URL + date.
///   • No AI-generated risk claims (the on-device LLM is used only
///     for finding *alternatives*, never to manufacture concerns).
///   • No editorial language ("spies on you", "you are the product")
///     in concern summaries — only factual descriptions of what the
///     primary source says.
///
/// **Pipeline mirrors Sovereignty:** the entries live in
/// `Scripts/trust-catalog.json`; Swift in `TrustCatalog+Entries.swift`
/// is generated.  Edit the JSON, run
/// `swift Scripts/regenerate-trust-catalog.swift`, commit both.
/// See `TRUST-CONTRIBUTING.md` for source allowlist + workflow.
enum TrustCatalog {

    // MARK: - Axes

    /// The four dimensions a Trust concern can fall into.  Each
    /// concern declares one axis; the scorer weights axes per the
    /// user's own preferences (Settings → Trust weights).  Keeping
    /// these orthogonal means a single CVE doesn't double-count
    /// against an app that also has a privacy concern.
    enum Axis: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
        /// Privacy: data collection, tracking, third-party sharing.
        /// Sourced from Apple's App Store privacy labels (which
        /// developers self-disclose) or DPA / FTC findings.
        case privacy

        /// Security: vulnerabilities, breaches, weak crypto, abandoned
        /// projects.  Sourced from NVD, vendor advisories, HIBP.
        case security

        /// Trust / reputation: regulatory fines, court rulings,
        /// ownership chains, sanctions.  Public record only.
        case trust

        /// Business model: developer-disclosed advertising, telemetry,
        /// ToS-disclosed data sharing.  Sourced from App Store
        /// description + privacy label, or vendor's own ToS.
        case businessModel

        var id: String { rawValue }

        var label: String {
            switch self {
            case .privacy:        return "Privacy"
            case .security:       return "Security"
            case .trust:          return "Trust"
            case .businessModel:  return "Business model"
            }
        }
    }

    // MARK: - Severity

    /// How serious a single concern is.  Combined with the axis
    /// weight in `TrustScorer` to produce the per-app score.
    enum Severity: String, Codable, CaseIterable, Hashable, Sendable {
        case low       // disclosed but minor; transparency wins, no
                       // pattern of harm.
        case moderate  // material concern with primary-source backing.
        case high      // documented harm or material breach.
        case severe    // catastrophic breach, headline regulatory
                       // ruling, or active sanctions.

        var label: String {
            switch self {
            case .low:       return "Low"
            case .moderate:  return "Moderate"
            case .high:      return "High"
            case .severe:    return "Severe"
            }
        }
    }

    // MARK: - Concern kinds

    /// The exhaustive list of *what kind of public-record fact* a
    /// concern represents.  Adding a new kind is a deliberate change
    /// — every kind must map to a class of source we trust as
    /// authoritative (Apple, regulator, NVD, HIBP, vendor advisory).
    /// No "user reports", "tech press claims", or "community ratings".
    enum Kind: String, Codable, CaseIterable, Hashable, Sendable {

        // ── Apple App Store self-disclosures ──
        /// Apple App Store privacy label: "Data Used to Track You".
        /// The most direct privacy signal Apple publishes — the
        /// developer is telling Apple they share data with brokers.
        case appStoreTrackingData
        /// "Data Linked to You" — collected and tied to identity.
        case appStoreLinkedData
        /// "Data Not Linked to You" — collected but anonymised.
        /// Lowest severity by default.
        case appStoreUnlinkedData

        // ── Regulatory ──
        /// GDPR enforcement by an EU Data Protection Authority.
        /// Cite case number + DPA + date.
        case regulatoryFineGDPR
        /// US Federal Trade Commission consent order or fine.
        case regulatoryFineFTC
        /// Other regulator: SEC, ICO (UK), CMA, ACCC, etc.
        case regulatoryFineOther
        /// Final court ruling (not a complaint, not a settlement
        /// without admission).  Public docket data.
        case courtRuling
        /// Sanction by a government against the vendor or its
        /// parent entity (US OFAC, UK OFSI, EU sanctions list).
        case governmentSanction

        // ── Vulnerabilities ──
        /// Known CVE in a recent version, citing the NVD entry.
        case knownCVE
        /// Vendor security advisory: MSRC, Apple Security Notes,
        /// Google Project Zero.
        case vendorSecurityAdvisory

        // ── Breaches ──
        /// Confirmed data breach, sourced from HIBP or vendor's own
        /// disclosure.  Cite breach date + record count.
        case dataBreachConfirmed

        // ── Business model (factual self-disclosures) ──
        /// Free with ads, where the developer self-discloses
        /// advertising in the App Store privacy label or app
        /// description.  Surfaced because users may not realise.
        case adSupportedFree
        /// Default-on telemetry per the developer's own privacy
        /// label or settings UI.
        case telemetryDefaultOn
        /// Vendor's own ToS / privacy policy discloses sharing
        /// with data brokers or advertising networks.
        case vendorPolicyDataSharing
    }

    // MARK: - Concern

    /// A single primary-source-cited concern about a single app.
    struct Concern: Codable, Sendable, Hashable, Identifiable {
        /// Stable ID, "<targetBundleID-slug>:<concern-slug>".  Used
        /// for SwiftUI list diffing and dedupe across the catalog.
        let id: String
        let kind: Kind
        let axis: Axis
        let severity: Severity
        /// Factual one-liner describing what the cited source says.
        /// MUST be quotable from the source — no editorial.
        let summary: String
        /// Primary-source URL.  Validated to be https at build time
        /// (see `regenerate-trust-catalog.swift`).
        let evidenceURL: URL
        /// ISO-8601 date (YYYY-MM-DD) when this evidence was
        /// recorded by Splynek.  Older than 18 months → flagged for
        /// re-review by `validate-trust-catalog.swift`.
        let evidenceDate: String
        /// Friendly source name shown in the UI: "Apple App Store",
        /// "CNIL", "FTC", "NVD", "HIBP", etc.
        let sourceName: String

        init(id: String, kind: Kind, axis: Axis, severity: Severity,
             summary: String, evidenceURL: URL, evidenceDate: String,
             sourceName: String) {
            self.id = id; self.kind = kind; self.axis = axis
            self.severity = severity; self.summary = summary
            self.evidenceURL = evidenceURL; self.evidenceDate = evidenceDate
            self.sourceName = sourceName
        }
    }

    // MARK: - Fallback alternative

    /// A "trusted alternative" the Trust tab can offer when the
    /// Sovereignty catalog has nothing for the target app.  Trust
    /// alternatives are allowed to be non-EU + non-OSS — they're
    /// just *better* than the target on the axes the user cares
    /// about.  Apple itself, for example, isn't EU/OSS but its apps
    /// have stronger privacy labels than most US competitors.
    struct FallbackAlternative: Codable, Sendable, Hashable, Identifiable {
        let id: String
        let name: String
        let homepage: URL
        /// One-line factual reason this is a defensible fallback —
        /// "Strong App Store privacy label", "On-device processing",
        /// etc.  Same no-editorial rule applies.
        let note: String
    }

    // MARK: - Entry

    struct Entry: Codable, Sendable, Hashable {
        let targetBundleID: String
        let targetDisplayName: String
        /// ISO-8601 date when this entry was last reviewed end-to-end.
        /// Used by `validate-trust-catalog.swift` to flag stale entries.
        let lastReviewed: String
        let concerns: [Concern]
        /// Optional — present when Sovereignty has nothing for this
        /// target.  Lookup chain in `TrustView` is:
        ///   1. SovereigntyCatalog.alternatives(for: bundleID)
        ///   2. Entry.fallbackAlternatives
        ///   3. AI fallback (Pro)
        let fallbackAlternatives: [FallbackAlternative]
    }

    // MARK: - Lookup

    /// Build a fast lookup map by bundle ID.  Like the Sovereignty
    /// catalog, this is first-match-wins; `validate-trust-catalog.swift`
    /// catches duplicates at lint time.
    private static let byBundleID: [String: Entry] = {
        var m: [String: Entry] = [:]
        for e in entries where m[e.targetBundleID] == nil {
            m[e.targetBundleID] = e
        }
        return m
    }()

    /// Look up the Trust profile for a specific bundle ID.  Returns
    /// nil when the catalog has no profile for this app — meaning
    /// either the app is uncommon enough that we haven't curated it
    /// yet, or there's nothing public-record-worthy to say about it.
    static func profile(for bundleID: String) -> Entry? {
        byBundleID[bundleID]
    }
}
