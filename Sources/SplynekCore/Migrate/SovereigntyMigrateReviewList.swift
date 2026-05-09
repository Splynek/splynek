import Foundation

/// **Sovereignty Migrate review list** — Sprint 2 part-2 (2026-05-09).
///
/// When the Migrate Wizard's `markOriginalForReview` step runs,
/// the original app's bundle ID lands here.  The Sovereignty tab
/// then surfaces a small banner — "3 apps you committed to migrating;
/// have you?" — a week after the mark date, so the user actually
/// follows through on the swap rather than half-doing it.
///
/// Persisted at
/// `~/Library/Application Support/Splynek/migrate-review-list.json`.
/// Same shape as `CellularBudget` / `TrustWatchStore`: single
/// JSON file, atomic write, lock-guarded reads + writes.
///
/// This is a **list**, not a queue — the user can have an
/// arbitrary number of pending swaps in flight at once.

public struct SovereigntyMigrateReviewEntry: Codable, Hashable, Sendable, Identifiable {
    public var id: String { bundleID + "|" + alternativeName }
    public let bundleID: String
    public let originalDisplayName: String
    public let alternativeName: String
    public let alternativeHomepage: URL
    /// ISO-8601 mark timestamp.  Used to compute "is it time to
    /// nudge the user about this one yet?".
    public let markedAt: String
    /// User's own note: "I migrated, can uninstall now" or
    /// "decided to stay" — empty until the user fills it.
    public var note: String

    public init(bundleID: String, originalDisplayName: String,
                alternativeName: String, alternativeHomepage: URL,
                markedAt: String, note: String = "") {
        self.bundleID = bundleID
        self.originalDisplayName = originalDisplayName
        self.alternativeName = alternativeName
        self.alternativeHomepage = alternativeHomepage
        self.markedAt = markedAt
        self.note = note
    }
}

public struct SovereigntyMigrateReviewList: Codable, Sendable {
    public var entries: [SovereigntyMigrateReviewEntry]

    public static let empty = SovereigntyMigrateReviewList(entries: [])

    public init(entries: [SovereigntyMigrateReviewEntry] = []) {
        self.entries = entries
    }

    /// Insert at head; idempotent on the (bundleID, alternativeName)
    /// composite key.  An idempotent re-mark refreshes `markedAt` so
    /// the "X days ago" label resets.
    public mutating func upsert(_ entry: SovereigntyMigrateReviewEntry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
        } else {
            entries.insert(entry, at: 0)
        }
    }

    public mutating func remove(id: String) {
        entries.removeAll { $0.id == id }
    }

    /// Entries marked at least `days` ago — used to surface the
    /// "still on your list" banner only after enough time has
    /// passed for the user to genuinely have migrated.
    public func entriesOlderThan(days: Int, now: Date = Date()) -> [SovereigntyMigrateReviewEntry] {
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return entries.filter {
            guard let marked = f.date(from: $0.markedAt) else { return false }
            return marked < cutoff
        }
    }
}

// MARK: - Disk I/O

public final class SovereigntyMigrateReviewStore: @unchecked Sendable {
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
        return dir.appendingPathComponent("migrate-review-list.json")
    }

    private let lock = NSLock()

    public init() {}

    public func read() -> SovereigntyMigrateReviewList {
        lock.lock(); defer { lock.unlock() }
        guard let data = try? Data(contentsOf: Self.fileURL),
              let list = try? JSONDecoder().decode(SovereigntyMigrateReviewList.self, from: data)
        else { return .empty }
        return list
    }

    public func write(_ list: SovereigntyMigrateReviewList) {
        lock.lock(); defer { lock.unlock() }
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(list) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    public func mutate(_ block: (inout SovereigntyMigrateReviewList) -> Void) {
        lock.lock(); defer { lock.unlock() }
        var list = (try? Data(contentsOf: Self.fileURL))
            .flatMap { try? JSONDecoder().decode(SovereigntyMigrateReviewList.self, from: $0) }
            ?? .empty
        block(&list)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? enc.encode(list) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    public static func _resetForTesting() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
