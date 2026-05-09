import Foundation

/// Codable summary types served by the new `/splynek/v1/api/*/summary`
/// endpoints + consumed by the iOS Companion / iOS Widget / iOS App
/// Intents / external clients (Raycast, Alfred, scripts).
///
/// **Why summaries, not full payloads?**  The phone over LAN /
/// CloudKit relay should receive only the *gist* — counts, top-N,
/// score deltas — never the full Sovereignty/Trust/History tables.
/// Three reasons:
///
/// 1. **Privacy posture** — even a phone *belonging to the same
///    user* shouldn't replicate the entire installed-app inventory
///    over the wire by default.
/// 2. **Bandwidth** — typical Trust/Sovereignty tables are ~150 KB
///    JSON; summary is ~2 KB.  Live Activity refresh + Widget
///    updates + Siri intents need to be fast.
/// 3. **Stable contract** — full payloads change shape every release
///    (new fields, deprecated bundle IDs).  Summary fields are
///    stable across versions; clients can read newer servers
///    without re-shipping.
///
/// 2026-05-09 Sprint 1 PRO-PLUS-IPHONE: created.  All types live in
/// the public dual-targeted SplynekCore so the iOS Companion
/// (`SplynekCompanionCore` SwiftPM library) can decode them
/// directly without a parallel definition.
public enum RelaySummary {

    // MARK: - Sovereignty

    /// Top-level snapshot of "how sovereign is this Mac's app
    /// inventory".  The iPhone widget shows the score; the
    /// summary view drills into top-3 most-concerning apps.
    public struct Sovereignty: Codable, Hashable, Sendable {
        /// 0-100 score: higher = more sovereign (more apps with
        /// EU/OSS alternatives swapped in, fewer big-tech
        /// dependencies).  Computed by `Scorer.percentSovereign`.
        public let score: Int
        /// Total apps enumerated by SovereigntyScanner.
        public let totalApps: Int
        /// Apps with at least one Sovereignty alternative listed.
        public let appsWithAlternatives: Int
        /// Top-3 most-flagged apps for the user to look at first.
        /// Empty when the user has zero alternatives flagged.
        public let topConcerns: [TopApp]
        /// ISO-8601 generation time.  Caches expire client-side
        /// after ~10 minutes (the `Cache-Control` header on the
        /// REST endpoint already says no-store; the client
        /// timestamp is for "as of HH:MM" UI labels).
        public let generatedAt: String

        public init(score: Int, totalApps: Int, appsWithAlternatives: Int,
                    topConcerns: [TopApp], generatedAt: String) {
            self.score = score
            self.totalApps = totalApps
            self.appsWithAlternatives = appsWithAlternatives
            self.topConcerns = topConcerns
            self.generatedAt = generatedAt
        }

        public struct TopApp: Codable, Hashable, Sendable {
            public let bundleID: String
            public let displayName: String
            public let firstAlternative: String?  // friendly name of #1 alt
            public init(bundleID: String, displayName: String,
                        firstAlternative: String?) {
                self.bundleID = bundleID
                self.displayName = displayName
                self.firstAlternative = firstAlternative
            }
        }
    }

    // MARK: - Trust

    public struct Trust: Codable, Hashable, Sendable {
        /// Average Trust score across installed apps that have a
        /// catalog profile.  0 = catastrophic; 100 = clean.
        public let averageScore: Int
        public let totalAppsWithProfile: Int
        /// Apps whose Trust score is < 50 (high-risk band).
        public let highRiskCount: Int
        /// Top-3 most-concerning apps.
        public let topConcerns: [TopApp]
        public let generatedAt: String

        public init(averageScore: Int, totalAppsWithProfile: Int,
                    highRiskCount: Int, topConcerns: [TopApp],
                    generatedAt: String) {
            self.averageScore = averageScore
            self.totalAppsWithProfile = totalAppsWithProfile
            self.highRiskCount = highRiskCount
            self.topConcerns = topConcerns
            self.generatedAt = generatedAt
        }

        public struct TopApp: Codable, Hashable, Sendable {
            public let bundleID: String
            public let displayName: String
            public let score: Int
            public let topConcernSummary: String
            public init(bundleID: String, displayName: String,
                        score: Int, topConcernSummary: String) {
                self.bundleID = bundleID
                self.displayName = displayName
                self.score = score
                self.topConcernSummary = topConcernSummary
            }
        }
    }

    // MARK: - Trust Watcher (Pro)

    /// Summary of the daily-diff Trust Watcher state.  Fetchable
    /// by an iPhone Companion **only when the paired Mac is Pro**
    /// — the endpoint returns 404 on free-tier Macs.  Same API
    /// contract as the local TrustWatchStore but trimmed for
    /// over-the-wire delivery.
    public struct TrustWatcher: Codable, Hashable, Sendable {
        public let watchingCount: Int       // distinct bundle IDs
        public let pendingAlertCount: Int   // unacknowledged alerts
        public let lastSweepAt: String?
        public let recentAlerts: [Alert]    // up to 10, newest first
        public let generatedAt: String

        public init(watchingCount: Int, pendingAlertCount: Int,
                    lastSweepAt: String?, recentAlerts: [Alert],
                    generatedAt: String) {
            self.watchingCount = watchingCount
            self.pendingAlertCount = pendingAlertCount
            self.lastSweepAt = lastSweepAt
            self.recentAlerts = recentAlerts
            self.generatedAt = generatedAt
        }

        public struct Alert: Codable, Hashable, Sendable {
            public let id: String
            public let displayName: String
            public let kindLabel: String       // "Privacy Policy" / "ToS"
            public let severityLabel: String   // "Minor change" / etc.
            public let observedAt: String
            public let acknowledged: Bool
            public let pageURL: String         // the watched URL itself
            public init(id: String, displayName: String, kindLabel: String,
                        severityLabel: String, observedAt: String,
                        acknowledged: Bool, pageURL: String) {
                self.id = id
                self.displayName = displayName
                self.kindLabel = kindLabel
                self.severityLabel = severityLabel
                self.observedAt = observedAt
                self.acknowledged = acknowledged
                self.pageURL = pageURL
            }
        }
    }

    // MARK: - History

    public struct History: Codable, Hashable, Sendable {
        /// Total persisted history entries on this Mac.
        public let totalEntries: Int
        /// Sum of bytes downloaded across all history.
        public let totalBytes: Int64
        /// Most-recent 10 entries for the iOS feed.
        public let recent: [Item]
        public let generatedAt: String

        public init(totalEntries: Int, totalBytes: Int64,
                    recent: [Item], generatedAt: String) {
            self.totalEntries = totalEntries
            self.totalBytes = totalBytes
            self.recent = recent
            self.generatedAt = generatedAt
        }

        public struct Item: Codable, Hashable, Sendable {
            public let url: String
            public let filename: String
            public let bytes: Int64
            public let finishedAt: String
            public init(url: String, filename: String, bytes: Int64,
                        finishedAt: String) {
                self.url = url
                self.filename = filename
                self.bytes = bytes
                self.finishedAt = finishedAt
            }
        }
    }
}
