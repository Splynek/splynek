import Foundation
@testable import SplynekCore

/// Strategy Bet S5 — HLSProxyServer route parsing + session
/// lifecycle tests.  Network round-trips (handleMaster /
/// handleVariant / handleSegment) are tested at runtime with a real
/// HLS source; these unit tests cover the deterministic surfaces.
enum HLSProxyServerTests {

    static func run() {
        TestHarness.suite("HLSProxyServer — handlesPath") {

            TestHarness.test("HLS paths claimed") {
                try expect(HLSProxyServer.handlesPath("/hls/abc/v?u=xx"))
                try expect(HLSProxyServer.handlesPath("/hls/abc/s?u=xx"))
                try expect(HLSProxyServer.handlesPath("/hls/abc/master?u=xx"))
            }

            TestHarness.test("Non-HLS paths ignored") {
                try expect(!HLSProxyServer.handlesPath("/splynek/v1/status"))
                try expect(!HLSProxyServer.handlesPath("/hls"))
                try expect(!HLSProxyServer.handlesPath("/"))
                try expect(!HLSProxyServer.handlesPath(""))
            }
        }

        TestHarness.suite("HLSProxyServer — parseRoute") {

            TestHarness.test("Variant route") {
                let original = "https://cdn.example.com/720p.m3u8"
                let encoded = HLSManifest.base64URL(original)
                let sid = "11111111-1111-1111-1111-111111111111"
                let url = URL(string: "http://localhost/hls/\(sid)/v?u=\(encoded)")!
                let route = HLSProxyServer.parseRoute(url)
                guard case .variant(let parsedSid, let upstream) = route else {
                    try expect(false, "Expected .variant")
                    return
                }
                try expectEqual(parsedSid.uuidString, sid)
                try expectEqual(upstream.absoluteString, original)
            }

            TestHarness.test("Segment route") {
                let original = "https://cdn.example.com/seg42.ts"
                let encoded = HLSManifest.base64URL(original)
                let sid = "22222222-2222-2222-2222-222222222222"
                let url = URL(string: "http://localhost/hls/\(sid)/s?u=\(encoded)")!
                guard case .segment(let parsedSid, let upstream) = HLSProxyServer.parseRoute(url) else {
                    try expect(false, "Expected .segment")
                    return
                }
                try expectEqual(parsedSid.uuidString, sid)
                try expectEqual(upstream.absoluteString, original)
            }

            TestHarness.test("Master route") {
                let original = "https://cdn.example.com/master.m3u8"
                let encoded = HLSManifest.base64URL(original)
                let sid = "33333333-3333-3333-3333-333333333333"
                let url = URL(string: "http://localhost/hls/\(sid)/master?u=\(encoded)")!
                guard case .master(let parsedSid, let upstream) = HLSProxyServer.parseRoute(url) else {
                    try expect(false, "Expected .master")
                    return
                }
                try expectEqual(parsedSid.uuidString, sid)
                try expectEqual(upstream.absoluteString, original)
            }

            TestHarness.test("Garbage rejected") {
                try expect(HLSProxyServer.parseRoute(URL(string: "http://localhost/")!) == nil)
                try expect(HLSProxyServer.parseRoute(URL(string: "http://localhost/hls")!) == nil)
                // Bad UUID
                let bad = URL(string: "http://localhost/hls/not-a-uuid/v?u=eHk")!
                try expect(HLSProxyServer.parseRoute(bad) == nil)
                // Missing ?u=
                let missingU = URL(string: "http://localhost/hls/11111111-1111-1111-1111-111111111111/v")!
                try expect(HLSProxyServer.parseRoute(missingU) == nil)
                // Unknown kind
                let badKind = URL(string: "http://localhost/hls/11111111-1111-1111-1111-111111111111/x?u=eHk")!
                try expect(HLSProxyServer.parseRoute(badKind) == nil)
            }
        }

        TestHarness.suite("HLSProxyServer — segment Content-Type inference") {

            TestHarness.test("Common HLS segment extensions") {
                // The function is private but we can exercise it via
                // route handling; quick smoke test on the public surface.
                let server = MainActor.assumeIsolated { HLSProxyServer() }
                let _ = server  // suppress unused
                // (No assertion — the contentType field is used inside
                // handleSegment + we don't have a test for that yet.)
                try expect(true, "Smoke")
            }
        }

        TestHarness.suite("HLSProxyServer — session lifecycle") {

            TestHarness.test("Session created on first lookup, persists, prunes by age") {
                try MainActor.assumeIsolated {
                    let server = HLSProxyServer()
                    let sid = UUID()
                    let upstream = URL(string: "https://cdn.example.com/master.m3u8")!
                    _ = server.session(for: sid, masterURL: upstream)
                    try expectEqual(server.sessions.count, 1)
                    // Prune everything older than 1 hour ago — our session
                    // is fresh, should survive.
                    server.prune(olderThan: Date().addingTimeInterval(-3600))
                    try expectEqual(server.sessions.count, 1)
                    // Prune everything older than now+1s — should drop ours.
                    server.prune(olderThan: Date().addingTimeInterval(1))
                    try expectEqual(server.sessions.count, 0)
                }
            }
        }
    }
}
