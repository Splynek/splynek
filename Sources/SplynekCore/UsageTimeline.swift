import Foundation

/// Pure data-shaping helpers for the Usage timeline chart. Kept
/// independent of SwiftUI + filesystem so the test harness can pin
/// the grouping logic (top-N host picking, "Other" rollup, today-
/// first ordering) without spinning up a view.
///
/// Design notes:
/// - A host that hasn't reappeared in the last N days still counts
///   toward the top-N ranking but drops out of the legend because
///   no point is emitted for it. That keeps the chart readable as
///   usage patterns drift.
/// - "Other" only appears when there's something to sum — a day
///   where every host made the top-N has no Other bar.
/// - Dates come in as `yyyy-MM-dd` strings already (the rollover
///   code writes them that way). We don't re-parse; lexicographic
///   sort matches chronological for that format, so the "newest
///   first" ordering falls out naturally.
struct UsageTimelinePoint: Hashable, Identifiable, Sendable {
    /// `yyyy-MM-dd` or the literal `"today"` when the current-day
    /// state didn't yet have a real date string.
    let date: String
    /// Host name, or the literal `"Other"` for the grouped rollup,
    /// or `"Cellular"` / `"Cellular (over cap)"` for the cellular
    /// variant of the chart.
    let series: String
    let bytes: Int64
    /// True only for the current-day point so the view can style
    /// the today bar differently (e.g., brighter colour).
    let isToday: Bool

    var id: String { "\(date)|\(series)" }
}

enum UsageTimeline {

    // MARK: - Host usage

    /// Produce stacked-bar points for the host-usage chart over the
    /// last `lastNDays` days. Hosts outside the top-`topN` (by total
    /// bytes across the window) are summed under a single `"Other"`
    /// series so the legend stays readable.
    /// QA P2 #11 (v0.43): hosts that come in as literal LAN IPs
    /// (e.g. `172.20.10.4` served by the integration-test runner,
    /// a home NAS, or any RFC-1918 address) render as bare
    /// numbers in the chart legend — which looks like debug
    /// output. Rewrite those to the friendlier "LAN (172.20.10.4)"
    /// so users recognise them. IPv6 ULA (`fc00::/7`) and link-
    /// local (`fe80::/10`) get the same treatment.
    static func displayHost(_ raw: String) -> String {
        if raw.isEmpty { return "(unknown)" }
        if isPrivateIPv4(raw) || isPrivateIPv6(raw) {
            return "LAN (\(raw))"
        }
        return raw
    }

    private static func isPrivateIPv4(_ host: String) -> Bool {
        let parts = host.split(separator: ".").compactMap { Int($0) }
        guard parts.count == 4, parts.allSatisfy({ (0...255).contains($0) }) else {
            return false
        }
        let (a, b) = (parts[0], parts[1])
        if a == 10 { return true }
        if a == 172 && (16...31).contains(b) { return true }
        if a == 192 && b == 168 { return true }
        if a == 127 { return true }  // loopback
        return false
    }

    private static func isPrivateIPv6(_ host: String) -> Bool {
        let lower = host.lowercased()
        return lower.hasPrefix("fc") || lower.hasPrefix("fd")
            || lower.hasPrefix("fe80") || lower == "::1"
    }

    static func hostData(
        today: HostUsageState,
        history: [HostUsageDaily],
        lastNDays: Int = 14,
        topN: Int = 8
    ) -> [UsageTimelinePoint] {
        var days: [(date: String, entries: [HostUsageEntry], isToday: Bool)] = []
        let todayDate = today.dateString.isEmpty ? "today" : today.dateString
        days.append((todayDate, today.entries, true))
        for day in history.prefix(max(0, lastNDays - 1)) {
            days.append((day.dateString, day.entries, false))
        }

        // Aggregate bytes per host across the whole window so the
        // top-N picks are stable across the chart rather than
        // reshuffling day-to-day.
        var totalByHost: [String: Int64] = [:]
        for d in days {
            for e in d.entries {
                totalByHost[e.host, default: 0] += e.bytesToday
            }
        }
        let topHosts = Set(
            totalByHost
                .sorted { lhs, rhs in
                    if lhs.value != rhs.value { return lhs.value > rhs.value }
                    return lhs.key < rhs.key   // stable tiebreak
                }
                .prefix(topN)
                .map(\.key)
        )

        var points: [UsageTimelinePoint] = []
        for d in days {
            var dayOther: Int64 = 0
            for e in d.entries {
                if topHosts.contains(e.host) {
                    points.append(UsageTimelinePoint(
                        date: d.date, series: displayHost(e.host),
                        bytes: e.bytesToday, isToday: d.isToday
                    ))
                } else {
                    dayOther += e.bytesToday
                }
            }
            if dayOther > 0 {
                points.append(UsageTimelinePoint(
                    date: d.date, series: "Other",
                    bytes: dayOther, isToday: d.isToday
                ))
            }
        }
        return points
    }

    // MARK: - Cellular budget

    /// Produce bar points for the cellular-usage chart over the last
    /// `lastNDays` days. Exactly one point per day; the `series`
    /// value is `"Cellular (over cap)"` for days whose total
    /// exceeded the cap that was in force, `"Cellular"` otherwise.
    /// This splits the colour so over-budget days jump out without
    /// needing chart-level styling by date.
    static func cellularData(
        today: CellularBudgetState,
        history: [CellularBudgetDaily],
        lastNDays: Int = 14
    ) -> [UsageTimelinePoint] {
        var points: [UsageTimelinePoint] = []
        let todayDate = today.dateString.isEmpty ? "today" : today.dateString
        let todayOver = today.dailyCap > 0 && today.bytesToday >= today.dailyCap
        points.append(UsageTimelinePoint(
            date: todayDate,
            series: todayOver ? "Cellular (over cap)" : "Cellular",
            bytes: today.bytesToday,
            isToday: true
        ))
        for day in history.prefix(max(0, lastNDays - 1)) {
            let over = day.dailyCap > 0 && day.bytesTotal >= day.dailyCap
            points.append(UsageTimelinePoint(
                date: day.dateString,
                series: over ? "Cellular (over cap)" : "Cellular",
                bytes: day.bytesTotal,
                isToday: false
            ))
        }
        return points
    }
}
