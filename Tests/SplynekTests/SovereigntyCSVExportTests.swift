import Foundation
@testable import SplynekCore

/// v1.7.x: invariants for `SovereigntyExport.csv(...)` (RFC 4180
/// dialect, UTF-8 no BOM, `\n` line endings).  Tests focus on the
/// pure data-shaping + escaping logic so they're deterministic and
/// don't depend on the catalog content.
enum SovereigntyCSVExportTests {

    static func run() {
        TestHarness.suite("SovereigntyExport CSV — escaping") {

            TestHarness.test("Plain field passes through unquoted") {
                try expectEqual(SovereigntyExport.csvEscape("foo"), "foo")
            }

            TestHarness.test("Comma triggers quoting") {
                try expectEqual(SovereigntyExport.csvEscape("Notion, an app"),
                                "\"Notion, an app\"")
            }

            TestHarness.test("Embedded quote gets doubled + wrapped") {
                // `a"b` → `"a""b"`
                try expectEqual(SovereigntyExport.csvEscape("a\"b"),
                                "\"a\"\"b\"")
            }

            TestHarness.test("Newline triggers quoting") {
                try expectEqual(SovereigntyExport.csvEscape("line1\nline2"),
                                "\"line1\nline2\"")
            }

            TestHarness.test("Carriage return triggers quoting") {
                try expectEqual(SovereigntyExport.csvEscape("a\rb"),
                                "\"a\rb\"")
            }

            TestHarness.test("Empty field passes through unquoted") {
                try expectEqual(SovereigntyExport.csvEscape(""), "")
            }
        }

        TestHarness.suite("SovereigntyExport CSV — structure") {

            TestHarness.test("Empty input still emits schema-version + header") {
                let out = SovereigntyExport.csv(installedApps: [])
                let lines = out.split(separator: "\n", omittingEmptySubsequences: false)
                try expectEqual(lines.count, 3,
                    "Schema-version row + header row + trailing empty (from terminating newline)")
                try expect(lines[0].hasPrefix("# splynek_sovereignty_csv_schema="),
                    "First row is the schema-version comment")
                try expectEqual(String(lines[1]),
                    SovereigntyExport.csvColumns.joined(separator: ","),
                    "Second row is the column header")
                try expectEqual(String(lines[2]), "",
                    "File ends with a terminating newline")
            }

            TestHarness.test("File starts with `#` not BOM") {
                let out = SovereigntyExport.csv(installedApps: [])
                let data = Data(out.utf8)
                // BOM bytes for UTF-8: EF BB BF.  We explicitly do NOT
                // emit one — modern tools (Numbers, Google Sheets, every
                // dev tool) read clean UTF-8 correctly; only Excel needs
                // a BOM, which is the wrong tradeoff for a macOS audience.
                try expect(data.count >= 3, "File should be at least 3 bytes")
                let first3 = Array(data.prefix(3))
                try expect(first3 != [0xEF, 0xBB, 0xBF],
                    "BOM detected — must be UTF-8 without BOM")
                try expectEqual(first3[0], 0x23 /* `#` */,
                    "First byte should be `#` (the schema-version comment marker)")
            }

            TestHarness.test("Column count matches the columns array") {
                let out = SovereigntyExport.csv(installedApps: [])
                let header = String(out.split(separator: "\n")[1])
                let count = header.split(separator: ",").count
                try expectEqual(count, SovereigntyExport.csvColumns.count, "Header has 10 columns")
                try expectEqual(count, 10,
                    "If this assertion drops, the docs reference '10 columns' too")
            }

            TestHarness.test("Newline terminator is `\\n` not `\\r\\n`") {
                let out = SovereigntyExport.csv(installedApps: [])
                try expect(!out.contains("\r"),
                    "CRLF line endings detected — expected LF-only")
                try expect(out.hasSuffix("\n"),
                    "File should end with a single LF")
            }

            TestHarness.test("Schema version comment has expected prefix") {
                let out = SovereigntyExport.csv(installedApps: [])
                let firstLine = String(out.split(separator: "\n").first ?? "")
                try expectEqual(firstLine,
                    "# splynek_sovereignty_csv_schema=\(SovereigntyExport.csvSchemaVersion)",
                    "Schema-version comment lets downstream tools detect format drift before parsing.")
            }
        }

        TestHarness.suite("SovereigntyExport CSV — ISO 8601 timestamp") {

            TestHarness.test("ISO 8601 includes T + timezone offset") {
                let date = Date(timeIntervalSince1970: 1_700_000_000)  // pinned
                let stamp = SovereigntyExport.csvISO8601(date)
                // Either +0000 / +0200 / Z form is acceptable depending
                // on system timezone — we just verify the canonical
                // structure (date T time tz).
                try expect(stamp.contains("T"),
                    "ISO 8601 must separate date + time with `T`: \(stamp)")
                try expect(stamp.count >= 20,
                    "Timestamp shorter than expected: \(stamp)")
            }
        }
    }
}
