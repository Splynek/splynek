import Foundation
@testable import SplynekCore

/// Load-bearing claim: we parse every canonical magnet shape, including
/// BEP 52 `urn:btmh:` hybrids. A regression here means pure-v2 magnets
/// silently fall back to v1 — breaking the v0.19 promise.
enum MagnetTests {

    static func run() {
        TestHarness.suite("Magnet links") {

            TestHarness.test("Classic v1 btih hex magnet parses") {
                // 40-hex SHA-1 info hash.
                let hex = String(repeating: "ab", count: 20)
                let uri = "magnet:?xt=urn:btih:\(hex)&dn=foo.iso&tr=http://t.example/"
                let m = try Magnet.parse(uri)
                try expectEqual(m.infoHash.count, 20)
                try expectEqual(m.infoHashV2, nil)
                try expect(!m.isV2)
                try expectEqual(m.displayName, "foo.iso")
                try expectEqual(m.trackers.count, 1)
            }

            TestHarness.test("Base32 btih variant decodes") {
                // Base32 SHA-1 — 32 chars, all uppercase.
                let base32 = "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"
                let uri = "magnet:?xt=urn:btih:\(base32)"
                let m = try Magnet.parse(uri)
                try expectEqual(m.infoHash.count, 20)
            }

            TestHarness.test("v2 urn:btmh:1220<hex> SHA-256 parses") {
                // 64-hex SHA-256; prefix 1220 = multihash(SHA-256, 32 bytes).
                let hex = String(repeating: "cd", count: 32)
                let uri = "magnet:?xt=urn:btmh:1220\(hex)&dn=bar.iso"
                let m = try Magnet.parse(uri)
                try expectEqual(m.infoHashV2?.count, 32)
                // Primary handshake hash for pure-v2 is the first 20 bytes.
                try expectEqual(m.infoHash.count, 20)
                try expect(m.isV2)
            }

            TestHarness.test("Hybrid magnet keeps v1 hash for handshake") {
                let v1hex = String(repeating: "ab", count: 20)
                let v2hex = String(repeating: "cd", count: 32)
                let uri = "magnet:?xt=urn:btih:\(v1hex)&xt=urn:btmh:1220\(v2hex)"
                let m = try Magnet.parse(uri)
                try expectEqual(m.infoHashV2?.count, 32)
                // v1 exists; `infoHash` must be the SHA-1 (first byte 0xAB),
                // NOT the truncated SHA-256 (which would start with 0xCD).
                try expectEqual(m.infoHash.first, 0xAB)
                try expect(m.isV2)
            }

            TestHarness.test("Missing xt is rejected") {
                do {
                    _ = try Magnet.parse("magnet:?dn=foo")
                    throw Expectation(message: "expected throw", file: #file, line: #line)
                } catch is MagnetError {
                    // ok
                }
            }

            TestHarness.test("Non-magnet URI is rejected") {
                do {
                    _ = try Magnet.parse("http://example.com")
                    throw Expectation(message: "expected throw", file: #file, line: #line)
                } catch is MagnetError {
                    // ok
                }
            }

            TestHarness.test("Display name with '+' decodes as space (v0.43 QA)") {
                // Real bug from QA walkthrough: magnet URIs encode
                // spaces in `dn` as `+` (x-www-form-urlencoded), but
                // we were only running `removingPercentEncoding`,
                // which leaves `+` intact. Users saw "Ubuntu+Test".
                let hex = String(repeating: "ab", count: 20)
                let uri = "magnet:?xt=urn:btih:\(hex)&dn=Ubuntu+Test"
                let m = try Magnet.parse(uri)
                try expectEqual(m.displayName, "Ubuntu Test")
            }

            TestHarness.test("A literal '+' escaped as %2B still round-trips") {
                // Belt-and-braces: `+` → space, `%2B` → `+`. If a dn
                // genuinely contains a plus, the user sees it.
                let hex = String(repeating: "ab", count: 20)
                let uri = "magnet:?xt=urn:btih:\(hex)&dn=C%2B%2B+Guide"
                let m = try Magnet.parse(uri)
                try expectEqual(m.displayName, "C++ Guide")
            }

            TestHarness.test("Bad btmh multihash is rejected") {
                // Wrong prefix — 1221 (SHA-512) not 1220 (SHA-256).
                let hex = String(repeating: "ef", count: 32)
                let uri = "magnet:?xt=urn:btmh:1221\(hex)"
                do {
                    _ = try Magnet.parse(uri)
                    throw Expectation(message: "expected throw", file: #file, line: #line)
                } catch is MagnetError {
                    // ok
                }
            }
        }
    }
}
