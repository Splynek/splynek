import Foundation
import SplynekCompanionCore

/// S4 phase 2 (2026-05-07): tests for `SplynekPairURL` — the
/// canonical pairing-URL format encoded into QR codes by the Mac
/// and decoded by the iOS Splynek Companion app's QR scanner.
///
/// Round-trip is the load-bearing invariant — Mac and iOS sides
/// must agree byte-for-byte on the format or pairing fails.
enum CompanionPairURLTests {

    static func run() {
        TestHarness.suite("SplynekPairURL — encode") {

            TestHarness.test("Includes scheme + host + all required query items") {
                let s = SplynekPairURL.encode(.init(
                    host: "192.168.1.20", port: 18280,
                    token: "tok-abc", name: "Paulo's Mac"))
                try expect(s.hasPrefix("splynek://pair?"))
                try expect(s.contains("host=192.168.1.20"))
                try expect(s.contains("port=18280"))
                try expect(s.contains("token=tok-abc"))
                // URL-encoded apostrophe; either form is acceptable
                try expect(s.contains("name=Paulo"))
            }

            TestHarness.test("Omits name when nil") {
                let s = SplynekPairURL.encode(.init(
                    host: "h", port: 1, token: "t", name: nil))
                try expect(!s.contains("name="))
            }

            TestHarness.test("Omits name when empty") {
                let s = SplynekPairURL.encode(.init(
                    host: "h", port: 1, token: "t", name: ""))
                try expect(!s.contains("name="))
            }
        }

        TestHarness.suite("SplynekPairURL — decode") {

            TestHarness.test("Round-trips a fully populated record") {
                let original = SplynekPairURL.Components(
                    host: "192.168.1.20", port: 18280,
                    token: "tok-abc", name: "Paulo's Mac")
                let encoded = SplynekPairURL.encode(original)
                let decoded = SplynekPairURL.decode(from: encoded)
                try expect(decoded == original)
            }

            TestHarness.test("Tolerates leading/trailing whitespace") {
                let raw = "  splynek://pair?host=h&port=1&token=t  \n"
                let decoded = SplynekPairURL.decode(from: raw)
                try expect(decoded?.host == "h")
            }

            TestHarness.test("Wrong scheme → nil") {
                try expect(SplynekPairURL.decode(
                    from: "https://pair?host=h&port=1&token=t") == nil)
            }

            TestHarness.test("Wrong host → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://wrong?host=h&port=1&token=t") == nil)
            }

            TestHarness.test("Missing host → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?port=1&token=t") == nil)
            }

            TestHarness.test("Missing port → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?host=h&token=t") == nil)
            }

            TestHarness.test("Non-numeric port → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?host=h&port=abc&token=t") == nil)
            }

            TestHarness.test("Negative / zero port → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?host=h&port=0&token=t") == nil)
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?host=h&port=-5&token=t") == nil)
            }

            TestHarness.test("Missing token → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?host=h&port=1") == nil)
            }

            TestHarness.test("Empty token → nil") {
                try expect(SplynekPairURL.decode(
                    from: "splynek://pair?host=h&port=1&token=") == nil)
            }

            TestHarness.test("Missing name leaves Components.name nil") {
                let decoded = SplynekPairURL.decode(
                    from: "splynek://pair?host=h&port=1&token=t")
                try expect(decoded?.name == nil)
            }

            TestHarness.test("Garbage text → nil") {
                try expect(SplynekPairURL.decode(from: "hello world") == nil)
                try expect(SplynekPairURL.decode(from: "") == nil)
                try expect(SplynekPairURL.decode(from: "splynek://") == nil)
            }
        }
    }
}
