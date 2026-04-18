import Foundation

/// Global policy that gates when the engine is allowed to start queue
/// items. A simple per-day time window plus a weekday mask plus an
/// optional cellular pause.
///
/// v0.34 ships a **single global** schedule — a first pass that covers
/// the 80/20 case ("only download overnight on home Wi-Fi"). Per-item
/// schedules and named rule sets are a future pass once a real user
/// actually wants them.
///
/// The schedule is evaluated by `runNextInQueue()` every time the queue
/// might want to start, and a 60-second retry timer in `ViewModel`
/// polls for the moment the window opens so a queued item wakes up on
/// its own without the user having to touch anything.
struct DownloadSchedule: Codable, Hashable, Sendable {

    /// Master switch. When false, the schedule never blocks.
    var enabled: Bool = false

    /// Inclusive start hour `[0, 23]`. If `startHour > endHour` the window
    /// wraps midnight (e.g., 22→6 means "from 10 PM through 6 AM").
    var startHour: Int = 2

    /// Exclusive end hour `[0, 24]`. `24` is a legal way to say "until
    /// midnight"; `Calendar` gives us `0..<24` so we clamp on the edges.
    var endHour: Int = 6

    /// Days-of-week when the schedule is active. Encoded as
    /// `Calendar.Component.weekday` values: 1 = Sunday, 2 = Monday, …,
    /// 7 = Saturday. Empty set == "never", which we reject at save time.
    var weekdays: Set<Int> = Set(1...7)

    /// When true, block starts entirely while any selected interface is
    /// cellular — complements the existing daily-bytes cap in
    /// `CellularBudget` by adding a "not now" gate on top of a "not more
    /// than" gate.
    var pauseOnCellular: Bool = false

    static let `default` = DownloadSchedule()

    // MARK: Evaluation

    /// One-shot outcome of gating a potential queue start. `.allowed`
    /// means the engine can pick up the next pending item; `.blocked`
    /// means don't start, and optionally tells the UI when to expect
    /// the next opening so it can render "Waiting until 02:00" next to
    /// the queue row.
    enum Evaluation: Hashable, Sendable {
        case allowed
        case blocked(reason: BlockReason, nextAllowed: Date?)
    }

    enum BlockReason: String, Codable, Hashable, Sendable {
        case disabledSchedule      // not reachable — we early-return .allowed
        case outsideWindow         // wrong hour
        case outsideWeekday        // wrong day of week
        case cellularActive        // pauseOnCellular + a cellular lane is selected
        case noWeekdaysSelected    // misconfiguration — user picked no days

        var displayText: String {
            switch self {
            case .disabledSchedule:   return "Schedule off"
            case .outsideWindow:      return "Outside window"
            case .outsideWeekday:     return "Not today"
            case .cellularActive:     return "Cellular active"
            case .noWeekdaysSelected: return "No days selected"
            }
        }
    }

    /// Pure function: given "now", a calendar, and whether any currently
    /// selected interface is cellular, return `.allowed` or `.blocked`.
    /// Kept free of side effects + MainActor so the test harness can pin
    /// every branch without spinning up the VM.
    func evaluate(at now: Date,
                  calendar: Calendar = .current,
                  onCellular: Bool = false) -> Evaluation {
        guard enabled else { return .allowed }

        if pauseOnCellular && onCellular {
            return .blocked(reason: .cellularActive, nextAllowed: nil)
        }

        if weekdays.isEmpty {
            return .blocked(reason: .noWeekdaysSelected, nextAllowed: nil)
        }

        let weekday = calendar.component(.weekday, from: now)
        if !weekdays.contains(weekday) {
            return .blocked(
                reason: .outsideWeekday,
                nextAllowed: Self.nextWindowOpening(
                    after: now, calendar: calendar,
                    startHour: startHour, weekdays: weekdays
                )
            )
        }

        if !isHourInWindow(now, calendar: calendar) {
            return .blocked(
                reason: .outsideWindow,
                nextAllowed: Self.nextWindowOpening(
                    after: now, calendar: calendar,
                    startHour: startHour, weekdays: weekdays
                )
            )
        }

        return .allowed
    }

    /// Short human-readable summary for Settings + queue-row badge.
    /// Examples: "off" / "daily 02:00–06:00" / "weekdays 22:00–06:00"
    /// / "Sun + Sat 00:00–24:00".
    var summary: String {
        guard enabled else { return "off" }
        let days: String
        if weekdays.count == 7 {
            days = "daily"
        } else if weekdays == Set([2,3,4,5,6]) {
            days = "weekdays"
        } else if weekdays == Set([1,7]) {
            days = "weekends"
        } else if weekdays.isEmpty {
            days = "never"
        } else {
            let names = ["", "Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
            days = weekdays.sorted().map { names[$0] }.joined(separator: "+")
        }
        return "\(days) \(pad(startHour)):00–\(pad(endHour)):00"
    }

    private func pad(_ h: Int) -> String {
        String(format: "%02d", max(0, min(24, h)))
    }

    // MARK: Internals

    private func isHourInWindow(_ date: Date, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: date)
        let minute = calendar.component(.minute, from: date)
        let nowMin = hour * 60 + minute
        let start = clampHour(startHour) * 60
        let end = clampHour(endHour) * 60
        if start == end { return false }                 // zero-length / degenerate
        if start < end { return nowMin >= start && nowMin < end }
        return nowMin >= start || nowMin < end           // wraps midnight
    }

    private func clampHour(_ h: Int) -> Int {
        min(24, max(0, h))
    }

    /// Walks up to 8 calendar days looking for the next moment the
    /// window would open. Returns nil if no weekday is enabled or if
    /// the schedule itself is disabled. Ignores cellular — we only
    /// compute the time-based next opening.
    static func nextWindowOpening(
        after now: Date,
        calendar: Calendar,
        startHour: Int,
        weekdays: Set<Int>
    ) -> Date? {
        guard !weekdays.isEmpty else { return nil }
        let clamped = min(24, max(0, startHour))
        for offset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: offset, to: now) else {
                continue
            }
            let weekday = calendar.component(.weekday, from: day)
            guard weekdays.contains(weekday) else { continue }
            var comps = calendar.dateComponents([.year, .month, .day], from: day)
            comps.hour = clamped
            comps.minute = 0
            comps.second = 0
            guard let candidate = calendar.date(from: comps) else { continue }
            if candidate > now { return candidate }
        }
        return nil
    }

    // MARK: Persistence

    static var storeURL: URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("schedule.json")
    }

    static func load() -> DownloadSchedule {
        guard let data = try? Data(contentsOf: storeURL),
              let decoded = try? JSONDecoder().decode(DownloadSchedule.self, from: data)
        else { return .default }
        return decoded
    }

    func save() {
        guard let data = try? JSONEncoder.pretty.encode(self) else { return }
        try? data.write(to: Self.storeURL, options: .atomic)
    }
}

private extension JSONEncoder {
    static var pretty: JSONEncoder {
        let e = JSONEncoder()
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
