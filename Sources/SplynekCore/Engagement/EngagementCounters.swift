import Foundation

/// **Engagement counters** — Sprint 3 (2026-05-10).
///
/// Pure-local counters that record how often the user touches each
/// Pro-relevant surface.  Used to decide — entirely client-side —
/// whether the user qualifies for a Trust+ subscription pitch
/// (per `STRATEGY-2026-PRO-PLUS-IPHONE.md` § "Sprint 3: Pricing
/// telemetry → Trust+ subscription evaluation if engagement
/// justifies").
///
/// **Privacy posture**: this file represents the entirety of
/// Splynek's "telemetry".  No data ever leaves the device — the
/// user can read the JSON directly + delete it at any time via
/// `~/Library/Application Support/Splynek/engagement.json`.
/// We do not aggregate, transmit, or report; nothing here drives
/// a server-side decision because there is no server.  The only
/// consumer is a future client-side gate that decides whether to
/// show a Trust+ upsell card.
///
/// **Why this exists at all**: without local engagement signal,
/// any "should we charge for Trust Watcher catalog refreshes?"
/// decision becomes a guess.  The counters give the **user**
/// insight ("you've checked Trust Watcher 47 times this month")
/// before any pitch lands — they decide in plain sight.
///
/// **MAS-2.5.2 invariant**: counters are pure integers updated
/// by user-driven UI events.  No LLM, no remote fetch, no
/// derived score.  Shape mirrors `CellularBudget` / `TrustWatchStore`.

public struct EngagementCounters: Codable, Hashable, Sendable {

    // MARK: - Trust Watcher counters

    /// Number of times the user opened the Trust Watcher card in
    /// TrustView (auto-incremented by the view's onAppear).
    public var trustWatcherViews: Int

    /// Number of times the user clicked "Run now" to force a
    /// fresh sweep.
    public var trustWatcherManualRuns: Int

    /// Number of alerts the user has acknowledged (clicked
    /// "Dismiss" or "Clear all").  Distinct from generated count
    /// — counts active engagement, not background activity.
    public var trustWatcherAcksHandled: Int

    /// Number of times the user opened a watched policy URL via
    /// the "View page" button (i.e. actually read the alert).
    public var trustWatcherPagesOpened: Int

    // MARK: - Sovereignty Migrate counters

    /// Number of Migrate plans the user has started (clicked the
    /// "Migrate" button on a Sovereignty alternative).
    public var migrateWizardOpens: Int

    /// Number of Migrate steps completed across all wizard runs.
    public var migrateStepsCompleted: Int

    /// Number of apps marked-for-review (count grows + shrinks
    /// with the review list).
    public var migrateAppsMarkedTotal: Int

    // MARK: - iPhone Companion counters

    /// Number of summary fetches served to the iPhone Companion
    /// (incremented by FleetCoordinator's relay handlers).  Not
    /// per-Mac — total across all paired phones.
    public var iphoneSummaryServes: Int

    /// Number of pause-all / resume-all operations from the
    /// iPhone (any path: App Intent, Lock Screen widget, watch).
    public var iphoneRemoteCommands: Int

    // MARK: - Bookkeeping

    /// First-recorded ISO timestamp.  Lets the UI show "since
    /// {date}".  Set once on file create; never updated.
    public var firstRecordedAt: String?

    /// Most-recently-updated ISO timestamp.  Refreshed every
    /// time any counter changes.  Drives the "in the last X
    /// days" UI labels without holding a daily-rollup table.
    public var lastUpdatedAt: String?

    public static let empty = EngagementCounters(
        trustWatcherViews: 0,
        trustWatcherManualRuns: 0,
        trustWatcherAcksHandled: 0,
        trustWatcherPagesOpened: 0,
        migrateWizardOpens: 0,
        migrateStepsCompleted: 0,
        migrateAppsMarkedTotal: 0,
        iphoneSummaryServes: 0,
        iphoneRemoteCommands: 0,
        firstRecordedAt: nil,
        lastUpdatedAt: nil
    )

    public init(trustWatcherViews: Int = 0,
                trustWatcherManualRuns: Int = 0,
                trustWatcherAcksHandled: Int = 0,
                trustWatcherPagesOpened: Int = 0,
                migrateWizardOpens: Int = 0,
                migrateStepsCompleted: Int = 0,
                migrateAppsMarkedTotal: Int = 0,
                iphoneSummaryServes: Int = 0,
                iphoneRemoteCommands: Int = 0,
                firstRecordedAt: String? = nil,
                lastUpdatedAt: String? = nil) {
        self.trustWatcherViews = trustWatcherViews
        self.trustWatcherManualRuns = trustWatcherManualRuns
        self.trustWatcherAcksHandled = trustWatcherAcksHandled
        self.trustWatcherPagesOpened = trustWatcherPagesOpened
        self.migrateWizardOpens = migrateWizardOpens
        self.migrateStepsCompleted = migrateStepsCompleted
        self.migrateAppsMarkedTotal = migrateAppsMarkedTotal
        self.iphoneSummaryServes = iphoneSummaryServes
        self.iphoneRemoteCommands = iphoneRemoteCommands
        self.firstRecordedAt = firstRecordedAt
        self.lastUpdatedAt = lastUpdatedAt
    }
}

// MARK: - Pure decision policy

public enum EngagementGate {

    /// Threshold for showing a Trust+ subscription pitch.  Tuned
    /// conservatively: a Pro user must have actively engaged with
    /// Trust Watcher (manual runs OR alert acknowledgements) at
    /// least this many times before the upsell appears.
    /// Below the threshold, the upsell is **never** shown — the
    /// user hasn't demonstrated they value the feature enough.
    public static let trustPlusEngagementThreshold = 20

    /// Decide whether the user has crossed the engagement bar
    /// where a Trust+ subscription upsell makes sense.  Pure
    /// function; tested.  Caller is Pro-gating UI; this is just
    /// "do we ever want to ask?".
    public static func shouldOfferTrustPlus(
        counters: EngagementCounters
    ) -> Bool {
        let active = counters.trustWatcherManualRuns
            + counters.trustWatcherAcksHandled
            + counters.trustWatcherPagesOpened
        return active >= trustPlusEngagementThreshold
    }
}

// MARK: - Disk-backed store

public final class EngagementStore: @unchecked Sendable {
    public static var _testOverrideURL: URL?

    private static var fileURL: URL {
        if let u = _testOverrideURL { return u }
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("engagement.json")
    }

    private let lock = NSLock()

    public init() {}

    public func read() -> EngagementCounters {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let c = try? JSONDecoder().decode(EngagementCounters.self, from: data)
        else { return .empty }
        return c
    }

    public func mutate(_ block: (inout EngagementCounters) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var c = (try? Data(contentsOf: Self.fileURL))
            .flatMap { try? JSONDecoder().decode(EngagementCounters.self, from: $0) }
            ?? .empty
        let nowISO = iso8601(Date())
        if c.firstRecordedAt == nil { c.firstRecordedAt = nowISO }
        block(&c)
        c.lastUpdatedAt = nowISO
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(c) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    public static func _resetForTesting() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    private func iso8601(_ date: Date) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: date)
    }
}
