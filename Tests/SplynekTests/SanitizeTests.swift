import Foundation
@testable import SplynekCore

/// Load-bearing claim: server-supplied filenames can't escape the
/// user's chosen output directory. A regression here is path-traversal:
/// a hostile Content-Disposition overwrites `~/.ssh/authorized_keys`.
enum SanitizeTests {

    static func run() {
        TestHarness.suite("Sanitize.filename") {

            TestHarness.test("Strips leading dots (no hidden writes)") {
                try expectEqual(Sanitize.filename(".bashrc"), "bashrc")
                try expectEqual(Sanitize.filename("....evil"), "evil")
            }

            TestHarness.test("Forward-slash path traversal is neutralised") {
                // `lastPathComponent` drops the `../../etc/` prefix.
                try expectEqual(
                    Sanitize.filename("../../../etc/passwd"),
                    "passwd"
                )
            }

            TestHarness.test("Back-slash is replaced with underscore") {
                try expectEqual(
                    Sanitize.filename("windows\\style\\path"),
                    "windows_style_path"
                )
            }

            TestHarness.test("Null bytes and C0 controls are removed") {
                let hostile = "foo\u{0000}bar\u{0007}baz"
                try expectEqual(Sanitize.filename(hostile), "foobarbaz")
            }

            TestHarness.test("Empty result falls back to download.bin") {
                try expectEqual(Sanitize.filename(""), "download.bin")
                try expectEqual(Sanitize.filename("..."), "download.bin")
                try expectEqual(Sanitize.filename("   "), "download.bin")
            }

            TestHarness.test("Long filenames are truncated below 200 bytes") {
                let huge = String(repeating: "a", count: 400) + ".iso"
                let got = Sanitize.filename(huge)
                try expect(got.utf8.count <= 200)
                try expect(got.hasSuffix(".iso"), "extension preserved")
            }

            TestHarness.test("Normal filenames pass through unchanged") {
                try expectEqual(Sanitize.filename("ubuntu-24.04.iso"), "ubuntu-24.04.iso")
                try expectEqual(Sanitize.filename("movie-720p.mkv"), "movie-720p.mkv")
            }
        }
    }
}
