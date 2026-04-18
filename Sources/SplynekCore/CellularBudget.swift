import Foundation

/// Daily cellular-interface byte tracker.
///
/// Every lane records how many bytes it egressed on an `isExpensive`
/// interface today; the totals reset at local midnight. The user can set a
/// daily byte budget; when the accumulated total crosses it, the VM warns
/// before starting a new download on a cellular lane.
///
/// Persisted to `~/Library/Application Support/Splynek/cellular-budget.json`.
/// Intentionally interface-kind-based (not per-host): the thing users
/// actually worry about is "don't burn my hotspot plan", not per-domain
/// accounting.
struct CellularBudgetState: Codable {
    /// Bytes used today, summed across every cellular interface.
    var bytesToday: Int64
    /// ISO-8601 date (local) the counter was last reset.
    var dateString: String
    /// Optional daily cap, in bytes. 0 = no cap.
    var dailyCap: Int64

    static let empty = CellularBudgetState(bytesToday: 0, dateString: "", dailyCap: 0)
}

/// One frozen day's worth of cellular usage, appended to the history
/// log on midnight roll-over so the CSV exporter can emit a timeline.
struct CellularBudgetDaily: Codable, Hashable, Identifiable, Sendable {
    var dateString: String
    var bytesTotal: Int64
    /// The cap that was in effect on this day (0 = uncapped). Useful for
    /// post-hoc analysis of whether the user hit the ceiling.
    var dailyCap: Int64
    var id: String { dateString }
}

private struct CellularBudgetHistory: Codable {
    var days: [CellularBudgetDaily]
    static let empty = CellularBudgetHistory(days: [])
}

enum CellularBudget {

    static var storeURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("cellular-budget.json")
    }

    static var historyURL: URL {
        storeURL.deletingLastPathComponent()
                .appendingPathComponent("cellular-budget-history.json")
    }

    static let historyDayCap = 365

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func today() -> String { dateFormatter.string(from: Date()) }

    static func load() -> CellularBudgetState {
        guard let data = try? Data(contentsOf: storeURL),
              let state = try? JSONDecoder().decode(CellularBudgetState.self, from: data)
        else { return .empty }
        // Reset if day has rolled over since the saved snapshot.
        if state.dateString != today() {
            // Snapshot yesterday into history before discarding, so the
            // CSV exporter sees a continuous timeline. Skip zero-byte
            // days that had no cap either — they're noise.
            if !state.dateString.isEmpty,
               state.bytesToday > 0 || state.dailyCap > 0 {
                appendHistory(CellularBudgetDaily(
                    dateString: state.dateString,
                    bytesTotal: state.bytesToday,
                    dailyCap: state.dailyCap
                ))
            }
            let rolled = CellularBudgetState(
                bytesToday: 0, dateString: today(), dailyCap: state.dailyCap
            )
            save(rolled)
            return rolled
        }
        return state
    }

    /// Read the frozen-day history, most-recent-first.
    static func loadHistory() -> [CellularBudgetDaily] {
        guard let data = try? Data(contentsOf: historyURL),
              let history = try? JSONDecoder().decode(CellularBudgetHistory.self, from: data)
        else { return [] }
        return history.days.sorted { $0.dateString > $1.dateString }
    }

    private static func appendHistory(_ day: CellularBudgetDaily) {
        var history = (try? JSONDecoder().decode(
            CellularBudgetHistory.self,
            from: (try? Data(contentsOf: historyURL)) ?? Data()
        )) ?? .empty
        history.days.removeAll { $0.dateString == day.dateString }
        history.days.append(day)
        history.days.sort { $0.dateString > $1.dateString }
        if history.days.count > historyDayCap {
            history.days = Array(history.days.prefix(historyDayCap))
        }
        if let data = try? JSONEncoder().encode(history) {
            try? data.write(to: historyURL, options: .atomic)
        }
    }

    static func save(_ state: CellularBudgetState) {
        let data = try? JSONEncoder().encode(state)
        try? data?.write(to: storeURL, options: .atomic)
    }

    /// Atomically add `bytes` to today's counter.
    static func add(_ bytes: Int64) {
        var state = load()
        if state.dateString.isEmpty { state.dateString = today() }
        state.bytesToday += bytes
        save(state)
    }

    static func setDailyCap(_ bytes: Int64) {
        var state = load()
        state.dailyCap = bytes
        save(state)
    }

    /// True iff a cap is set and today's usage has exceeded it.
    static func isOverBudget() -> Bool {
        let state = load()
        return state.dailyCap > 0 && state.bytesToday >= state.dailyCap
    }
}
