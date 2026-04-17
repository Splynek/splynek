import Foundation

/// Per-host byte usage accounting. Complements `CellularBudget` but
/// tracks at the origin-host granularity (`URL.host`) so users can see
/// *where* their bandwidth went today, not just *through what interface*.
///
/// Read-only for v0.15: no caps, no enforcement. Just a metric.
///
/// Stored as JSON at
/// `~/Library/Application Support/Splynek/host-usage.json`, rolled at
/// local midnight. Each row is `{ host, bytesToday, updatedAt }`.
struct HostUsageEntry: Codable, Identifiable, Hashable {
    var host: String
    var bytesToday: Int64
    var updatedAt: Date
    /// Optional daily cap, in bytes. 0 = no cap. Persisted independently
    /// of the usage so it survives the midnight roll.
    var dailyCap: Int64 = 0

    var id: String { host }

    /// True iff a cap is set and today's usage has reached it.
    var isOverCap: Bool { dailyCap > 0 && bytesToday >= dailyCap }
}

struct HostUsageState: Codable {
    var dateString: String
    var entries: [HostUsageEntry]

    static let empty = HostUsageState(dateString: "", entries: [])
}

enum HostUsage {

    static var storeURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("host-usage.json")
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func today() -> String { dateFormatter.string(from: Date()) }

    static func load() -> HostUsageState {
        guard let data = try? Data(contentsOf: storeURL),
              var state = try? JSONDecoder.iso8601.decode(HostUsageState.self, from: data)
        else { return HostUsageState(dateString: today(), entries: []) }
        if state.dateString != today() {
            // Roll: keep caps, reset bytes. Drop entries that were
            // momentary (no cap and no usage) to avoid unbounded growth.
            let rolled = state.entries
                .filter { $0.dailyCap > 0 }
                .map { entry -> HostUsageEntry in
                    var e = entry
                    e.bytesToday = 0
                    e.updatedAt = Date()
                    return e
                }
            state = HostUsageState(dateString: today(), entries: rolled)
            save(state)
        }
        return state
    }

    static func save(_ state: HostUsageState) {
        if let data = try? JSONEncoder.iso8601.encode(state) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    /// Credit `bytes` to `host` in today's tally, creating the entry if
    /// needed. Cheap: decode-modify-encode on every call, but the file is
    /// tiny (< 4 KB for any realistic day).
    static func credit(host: String?, bytes: Int64) {
        guard let host, !host.isEmpty, bytes > 0 else { return }
        var state = load()
        if let idx = state.entries.firstIndex(where: { $0.host == host }) {
            state.entries[idx].bytesToday += bytes
            state.entries[idx].updatedAt = Date()
        } else {
            state.entries.append(HostUsageEntry(
                host: host, bytesToday: bytes, updatedAt: Date()
            ))
        }
        save(state)
    }

    /// Top-N hosts by today's usage, most-used first.
    static func top(_ n: Int = 5) -> [HostUsageEntry] {
        let state = load()
        return Array(state.entries.sorted { $0.bytesToday > $1.bytesToday }.prefix(n))
    }

    /// Set (or clear with `bytes == 0`) the daily cap for a host.
    /// Creates a zero-usage entry if the host has never been seen.
    static func setCap(host: String, bytes: Int64) {
        guard !host.isEmpty else { return }
        var state = load()
        if let idx = state.entries.firstIndex(where: { $0.host == host }) {
            state.entries[idx].dailyCap = max(0, bytes)
            state.entries[idx].updatedAt = Date()
        } else {
            state.entries.append(HostUsageEntry(
                host: host, bytesToday: 0,
                updatedAt: Date(), dailyCap: max(0, bytes)
            ))
        }
        save(state)
    }

    /// Look up a host's current entry. Returns nil if unknown.
    static func entry(for host: String) -> HostUsageEntry? {
        load().entries.first { $0.host == host }
    }

    /// Pre-flight check: is this host already over its daily cap?
    static func isOverCap(for host: String) -> Bool {
        entry(for: host)?.isOverCap ?? false
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
