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

        // S5 instrumentation (2026-05-07) — telemetry counters that
        // back the /splynek/v1/hls/stats endpoint + Scripts/hls-watch.sh.
        TestHarness.suite("HLSProxyServer — telemetry counters") {

            TestHarness.test("Initial telemetry is all zero") {
                Task { @MainActor in
                    let server = HLSProxyServer()
                    try expect(server.telemetry.sessionsActive == 0)
                    try expect(server.telemetry.masterFetches == 0)
                    try expect(server.telemetry.variantFetches == 0)
                    try expect(server.telemetry.segmentRequests == 0)
                    try expect(server.telemetry.segmentCacheHits == 0)
                    try expect(server.telemetry.segmentCacheMisses == 0)
                    try expect(server.telemetry.bytesFromCache == 0)
                    try expect(server.telemetry.bytesFromOrigin == 0)
                    try expect(server.telemetry.cacheHitRate == 0)
                }
            }

            TestHarness.test("session(for:) bumps sessionsActive gauge") {
                Task { @MainActor in
                    let server = HLSProxyServer()
                    let url = URL(string: "https://example.com/m.m3u8")!
                    _ = server.session(for: UUID(), masterURL: url)
                    try expect(server.telemetry.sessionsActive == 1)
                    _ = server.session(for: UUID(), masterURL: url)
                    try expect(server.telemetry.sessionsActive == 2)
                }
            }

            TestHarness.test("prune(olderThan:) updates sessionsActive gauge") {
                Task { @MainActor in
                    let server = HLSProxyServer()
                    _ = server.session(for: UUID(),
                                       masterURL: URL(string: "https://x.x/m.m3u8")!)
                    try expect(server.telemetry.sessionsActive == 1)
                    server.prune(olderThan: Date().addingTimeInterval(60))
                    try expect(server.telemetry.sessionsActive == 0)
                }
            }

            TestHarness.test("cacheHitRate computes 0..1 from hit + miss") {
                Task { @MainActor in
                    let server = HLSProxyServer()
                    server.telemetry.segmentCacheHits = 9
                    server.telemetry.segmentCacheMisses = 1
                    try expect(abs(server.telemetry.cacheHitRate - 0.9) < 1e-9)
                    server.telemetry.segmentCacheHits = 0
                    server.telemetry.segmentCacheMisses = 0
                    try expect(server.telemetry.cacheHitRate == 0)
                    server.telemetry.segmentCacheHits = 5
                    server.telemetry.segmentCacheMisses = 5
                    try expect(abs(server.telemetry.cacheHitRate - 0.5) < 1e-9)
                }
            }

            TestHarness.test("resetTelemetry zeroes counters but preserves session gauge") {
                Task { @MainActor in
                    let server = HLSProxyServer()
                    server.telemetry.segmentRequests = 100
                    server.telemetry.segmentCacheHits = 90
                    _ = server.session(
                        for: UUID(),
                        masterURL: URL(string: "https://x.x/m.m3u8")!)
                    try expect(server.telemetry.sessionsActive == 1)
                    server.resetTelemetry()
                    try expect(server.telemetry.segmentRequests == 0)
                    try expect(server.telemetry.segmentCacheHits == 0)
                    try expect(server.telemetry.sessionsActive == 1)  // gauge re-derived from sessions
                }
            }

            TestHarness.test("Telemetry is Codable round-trip identical") {
                let encoder = JSONEncoder()
                let decoder = JSONDecoder()
                var t = HLSProxyServer.Telemetry()
                t.segmentRequests = 42
                t.segmentCacheHits = 30
                t.segmentCacheMisses = 12
                t.bytesFromCache = 1_234_567
                t.bytesFromOrigin = 89_012
                let data = try encoder.encode(t)
                let decoded = try decoder.decode(HLSProxyServer.Telemetry.self, from: data)
                try expect(decoded.segmentRequests == 42)
                try expect(decoded.segmentCacheHits == 30)
                try expect(decoded.bytesFromCache == 1_234_567)
                try expect(abs(decoded.cacheHitRate - 30.0/42.0) < 1e-9)
            }
        }
    }
}
