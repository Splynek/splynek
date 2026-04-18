import Foundation

/// Pure CSV formatters for the two usage data sets. Kept free of
/// filesystem + UI concerns so the test harness can pin every escape
/// case (commas in hostnames, quotes in anything, CRLF in theory)
/// without touching disk.
///
/// Output dialect: RFC 4180 — CRLF line endings, fields containing
/// `,` / `"` / `CR` / `LF` are wrapped in double quotes, embedded
/// quotes are doubled. That's the dialect every spreadsheet handles
/// natively (Numbers, Excel, Google Sheets).
enum UsageCSV {

    // MARK: - Host usage

    /// Emit a CSV with one row per (date, host). Today's state comes first
    /// (so the most-recent activity is immediately visible), followed by
    /// frozen-day history rows most-recent-first.
    static func hostUsageCSV(
        today: HostUsageState,
        history: [HostUsageDaily]
    ) -> String {
        var rows: [[String]] = [["date", "host", "bytes", "daily_cap_bytes", "over_cap", "updated_at"]]
        let iso = ISO8601DateFormatter()

        // Today's entries (may be empty if no traffic yet).
        if !today.entries.isEmpty {
            let date = today.dateString.isEmpty ? "today" : today.dateString
            for e in today.entries.sorted(by: { $0.bytesToday > $1.bytesToday }) {
                rows.append([
                    date,
                    e.host,
                    String(e.bytesToday),
                    String(e.dailyCap),
                    e.isOverCap ? "true" : "false",
                    iso.string(from: e.updatedAt)
                ])
            }
        }

        for day in history {
            let sorted = day.entries.sorted(by: { $0.bytesToday > $1.bytesToday })
            for e in sorted {
                rows.append([
                    day.dateString,
                    e.host,
                    String(e.bytesToday),
                    String(e.dailyCap),
                    e.isOverCap ? "true" : "false",
                    iso.string(from: e.updatedAt)
                ])
            }
        }

        return render(rows: rows)
    }

    // MARK: - Cellular budget

    /// Emit a CSV with one row per day. Today's row is always written
    /// first (even when `bytesToday == 0`, so users see the current-day
    /// snapshot); history rows follow most-recent-first.
    static func cellularBudgetCSV(
        today: CellularBudgetState,
        history: [CellularBudgetDaily]
    ) -> String {
        var rows: [[String]] = [["date", "bytes", "daily_cap_bytes", "over_cap"]]

        let todayDate = today.dateString.isEmpty ? "today" : today.dateString
        rows.append([
            todayDate,
            String(today.bytesToday),
            String(today.dailyCap),
            (today.dailyCap > 0 && today.bytesToday >= today.dailyCap) ? "true" : "false"
        ])

        for day in history {
            rows.append([
                day.dateString,
                String(day.bytesTotal),
                String(day.dailyCap),
                (day.dailyCap > 0 && day.bytesTotal >= day.dailyCap) ? "true" : "false"
            ])
        }

        return render(rows: rows)
    }

    // MARK: - RFC 4180

    static func escape(_ field: String) -> String {
        // A field needs quoting if it contains any of these. Otherwise
        // pass through unmodified — that keeps the common case
        // (numeric strings, simple hostnames) readable by eye.
        let needsQuoting = field.contains(",")
            || field.contains("\"")
            || field.contains("\n")
            || field.contains("\r")
        if !needsQuoting { return field }
        let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
        return "\"\(escaped)\""
    }

    private static func render(rows: [[String]]) -> String {
        rows
            .map { row in row.map(escape).joined(separator: ",") }
            .joined(separator: "\r\n") + "\r\n"
    }
}
