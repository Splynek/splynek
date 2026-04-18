import Foundation
@testable import SplynekCore

/// `DownloadSchedule.evaluate(...)` is what gates every queue start, so
/// its branches need to be pinned. These tests use a fixed Gregorian
/// calendar in UTC so runs on a developer's machine don't drift with
/// local time zone, and synthesise specific `Date` values for each
/// branch instead of probing "now."
enum DownloadScheduleTests {

    /// Build a UTC date from ISO components. The suite standardises on
    /// `2026-04-20` which is a Monday (weekday = 2).
    private static func date(
        year: Int = 2026, month: Int = 4, day: Int = 20,
        hour: Int, minute: Int = 0
    ) -> Date {
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day
        comps.hour = hour; comps.minute = minute
        comps.timeZone = TimeZone(identifier: "UTC")
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal.date(from: comps)!
    }

    private static var utcCal: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }

    static func run() {
        TestHarness.suite("DownloadSchedule") {

            TestHarness.test("disabled schedule is always allowed") {
                var s = DownloadSchedule.default
                s.enabled = false
                s.startHour = 2; s.endHour = 6
                // Outside any plausible window, but schedule off.
                let now = date(hour: 14)
                try expectEqual(s.evaluate(at: now, calendar: utcCal), .allowed)
            }

            TestHarness.test("inside simple window (02:00–06:00) → allowed") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 2; s.endHour = 6
                s.weekdays = Set(1...7)
                try expectEqual(s.evaluate(at: date(hour: 3), calendar: utcCal), .allowed)
            }

            TestHarness.test("at startHour exactly → allowed (inclusive)") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 2; s.endHour = 6
                try expectEqual(s.evaluate(at: date(hour: 2), calendar: utcCal), .allowed)
            }

            TestHarness.test("at endHour exactly → blocked (exclusive)") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 2; s.endHour = 6
                let result = s.evaluate(at: date(hour: 6), calendar: utcCal)
                guard case .blocked(let reason, _) = result else {
                    try expect(false, "expected .blocked, got \(result)"); return
                }
                try expectEqual(reason, .outsideWindow)
            }

            TestHarness.test("outside simple window → blocked with outsideWindow") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 2; s.endHour = 6
                let result = s.evaluate(at: date(hour: 14), calendar: utcCal)
                guard case .blocked(let reason, let next) = result else {
                    try expect(false, "expected .blocked, got \(result)"); return
                }
                try expectEqual(reason, .outsideWindow)
                try expect(next != nil, "expected a next-opening Date")
            }

            TestHarness.test("midnight-wrapping window (22:00–06:00) allowed at 23:00") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 22; s.endHour = 6
                try expectEqual(s.evaluate(at: date(hour: 23), calendar: utcCal), .allowed)
            }

            TestHarness.test("midnight-wrapping window (22:00–06:00) allowed at 05:00") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 22; s.endHour = 6
                try expectEqual(s.evaluate(at: date(hour: 5), calendar: utcCal), .allowed)
            }

            TestHarness.test("midnight-wrapping window blocked at 10:00") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 22; s.endHour = 6
                let r = s.evaluate(at: date(hour: 10), calendar: utcCal)
                guard case .blocked(let reason, _) = r else {
                    try expect(false, "expected .blocked"); return
                }
                try expectEqual(reason, .outsideWindow)
            }

            TestHarness.test("weekday not in set → blocked with outsideWeekday") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 0; s.endHour = 24
                // 2026-04-20 is Monday (weekday = 2). Restrict to Sundays.
                s.weekdays = [1]
                let r = s.evaluate(at: date(hour: 3), calendar: utcCal)
                guard case .blocked(let reason, let next) = r else {
                    try expect(false, "expected .blocked"); return
                }
                try expectEqual(reason, .outsideWeekday)
                try expect(next != nil)
            }

            TestHarness.test("empty weekdays set → blocked with noWeekdaysSelected") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.weekdays = []
                let r = s.evaluate(at: date(hour: 3), calendar: utcCal)
                guard case .blocked(let reason, let next) = r else {
                    try expect(false, "expected .blocked"); return
                }
                try expectEqual(reason, .noWeekdaysSelected)
                try expect(next == nil, "no weekdays means no next opening")
            }

            TestHarness.test("pauseOnCellular blocks regardless of window") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 0; s.endHour = 24
                s.pauseOnCellular = true
                let r = s.evaluate(at: date(hour: 3), calendar: utcCal, onCellular: true)
                guard case .blocked(let reason, _) = r else {
                    try expect(false, "expected .blocked"); return
                }
                try expectEqual(reason, .cellularActive)
            }

            TestHarness.test("pauseOnCellular + not on cellular → allowed") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 0; s.endHour = 24
                s.pauseOnCellular = true
                try expectEqual(
                    s.evaluate(at: date(hour: 3), calendar: utcCal, onCellular: false),
                    .allowed
                )
            }

            TestHarness.test("nextWindowOpening rolls forward to the next enabled day") {
                // Monday (weekday=2) @ 14:00 UTC, schedule 02:00 only on
                // Sundays (weekday=1). Next opening is next Sunday at 02:00.
                let now = date(hour: 14)
                let next = DownloadSchedule.nextWindowOpening(
                    after: now, calendar: utcCal, startHour: 2, weekdays: [1]
                )
                try expect(next != nil)
                let weekday = utcCal.component(.weekday, from: next!)
                try expectEqual(weekday, 1)
                let hour = utcCal.component(.hour, from: next!)
                try expectEqual(hour, 2)
            }

            TestHarness.test("nextWindowOpening returns today-later when same day still has a future start") {
                // Monday @ 00:30 UTC, schedule starts Monday 02:00.
                let now = date(hour: 0, minute: 30)
                let next = DownloadSchedule.nextWindowOpening(
                    after: now, calendar: utcCal, startHour: 2, weekdays: Set(1...7)
                )
                try expect(next != nil)
                let diff = next!.timeIntervalSince(now)
                try expect(diff > 0 && diff < 3 * 3600, "expected a same-day opening in ~1.5h, got \(diff)s")
            }

            TestHarness.test("summary renders 'off' when disabled") {
                var s = DownloadSchedule.default
                s.enabled = false
                try expectEqual(s.summary, "off")
            }

            TestHarness.test("summary labels weekdays / weekends / daily") {
                var s = DownloadSchedule.default
                s.enabled = true
                s.startHour = 2; s.endHour = 6
                s.weekdays = Set(1...7)
                try expectEqual(s.summary, "daily 02:00–06:00")
                s.weekdays = [2,3,4,5,6]
                try expectEqual(s.summary, "weekdays 02:00–06:00")
                s.weekdays = [1,7]
                try expectEqual(s.summary, "weekends 02:00–06:00")
            }
        }
    }
}
