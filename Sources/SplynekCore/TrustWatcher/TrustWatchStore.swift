import Foundation

/// Persistent store for the Trust Watcher: snapshots (last
/// observed hash + length per target) plus the alert log.
///
/// Persisted to
/// `~/Library/Application Support/Splynek/trust-watcher.json`.
/// Same pattern as `CellularBudget` / `ConciergeTranscriptStore`
/// — single JSON blob, atomic write, lazy-decode on first access.
///
/// Thread-safety: this is a value-type with a class-based file
/// guard (`@unchecked Sendable` lock).  All reads + writes go
/// through `read()` / `write(_:)` which serialise via the lock.
/// Designed to be called from any actor + the main thread.
public struct TrustWatchStore: Codable, Sendable {

    /// Latest observed snapshot per target ID
    /// (`bundleID|kind.rawValue`).  Diff engine compares the
    /// fresh snapshot against the value here.
    public var snapshots: [String: TrustWatchSnapshot]

    /// Most-recent alerts.  Capped at `alertCap` so the file
    /// doesn't grow unbounded over years.  Newest first.
    public var alerts: [TrustWatchAlert]

    /// Last full-sweep ISO timestamp.  Drives the "next run in
    /// X hours" UI label + the daily-rate-limit guard.
    public var lastSweepAt: String?

    public static let alertCap = 100

    public static let empty = TrustWatchStore(
        snapshots: [:],
        alerts: [],
        lastSweepAt: nil
    )

    public init(snapshots: [String: TrustWatchSnapshot] = [:],
                alerts: [TrustWatchAlert] = [],
                lastSweepAt: String? = nil) {
        self.snapshots = snapshots
        self.alerts = alerts
        self.lastSweepAt = lastSweepAt
    }

    /// Stable key used in `snapshots` dictionary + `TrustWatchAlert.id`
    /// disambiguator.
    public static func key(for target: TrustWatchTarget) -> String {
        "\(target.bundleID)|\(target.kind.rawValue)"
    }

    // MARK: Convenience mutations

    /// Insert a new alert at the head, capped at `alertCap`.
    /// De-dupes by `id` so an idempotent re-run of the diff
    /// engine doesn't multiply alerts.
    public mutating func recordAlert(_ alert: TrustWatchAlert) {
        if let i = alerts.firstIndex(where: { $0.id == alert.id }) {
            alerts[i] = alert
        } else {
            alerts.insert(alert, at: 0)
            if alerts.count > Self.alertCap {
                alerts = Array(alerts.prefix(Self.alertCap))
            }
        }
    }

    /// Mark an alert acknowledged.  Idempotent.
    public mutating func acknowledge(alertID: String) {
        guard let i = alerts.firstIndex(where: { $0.id == alertID }) else { return }
        alerts[i].acknowledged = true
    }

    /// Mark every alert acknowledged.  Used by the "Clear all" UI button.
    public mutating func acknowledgeAll() {
        alerts = alerts.map {
            var a = $0
            a.acknowledged = true
            return a
        }
    }

    /// Number of unacknowledged alerts.  Drives the sidebar badge
    /// (when present) + the in-tab hero count.
    public var pendingAlertCount: Int {
        alerts.filter { !$0.acknowledged }.count
    }
}

// MARK: - Disk I/O

/// Disk-backed wrapper for `TrustWatchStore`.  All read/write
/// goes through the lock so concurrent callers from
/// `TrustWatchService` + UI + tests don't tear the file.
public final class TrustWatchStoreFile: @unchecked Sendable {

    /// Override file path (used by tests to redirect to tmp).
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
        return dir.appendingPathComponent("trust-watcher.json")
    }

    private let lock = NSLock()

    public init() {}

    public func read() -> TrustWatchStore {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let store = try? JSONDecoder().decode(TrustWatchStore.self, from: data)
        else { return .empty }
        return store
    }

    public func write(_ store: TrustWatchStore) {
        lock.lock(); defer { lock.unlock() }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(store) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    /// Mutate + persist atomically.  The block must not block on
    /// network I/O (the lock is held throughout).
    public func mutate(_ block: (inout TrustWatchStore) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var store = (try? Data(contentsOf: Self.fileURL))
            .flatMap { try? JSONDecoder().decode(TrustWatchStore.self, from: $0) }
            ?? .empty
        block(&store)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(store) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    /// **Tests only.**  Wipe the file on disk so subsequent reads
    /// return `.empty`.  Mirrors the `_resetForTesting()` pattern
    /// from `InstallRegistry`.
    public static func _resetForTesting() {
        let fm = FileManager.default
        try? fm.removeItem(at: fileURL)
    }
}
