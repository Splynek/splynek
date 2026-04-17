import Foundation
@testable import SplynekCore

/// Load-bearing claim (v0.24): the web dashboard HTML polls state,
/// submits with a token, and renders the device label. A regression
/// here means the mobile dashboard breaks silently — no endpoint talks
/// to us, but the page still loads.
enum WebDashboardTests {

    static func run() {
        TestHarness.suite("Web dashboard") {

            TestHarness.test("HTML declares UTF-8 + mobile viewport") {
                let html = WebDashboard.html
                try expect(html.contains("<meta charset=\"utf-8\">"))
                try expect(html.contains("width=device-width"))
                try expect(html.contains("viewport-fit=cover"),
                           "iOS safe-area handling requires viewport-fit=cover")
            }

            TestHarness.test("HTML polls the state endpoint") {
                let html = WebDashboard.html
                try expect(html.contains("/splynek/v1/ui/state"),
                           "state-polling URL missing from dashboard HTML")
            }

            TestHarness.test("HTML submits to the token-gated endpoint") {
                let html = WebDashboard.html
                try expect(html.contains("/splynek/v1/ui/submit?t="),
                           "submit URL must carry ?t= for token gating")
            }

            TestHarness.test("HTML reads the token from window.location") {
                let html = WebDashboard.html
                // The page picks the token from its own URL — that's how
                // the QR handoff works.
                try expect(html.contains("URLSearchParams"),
                           "dashboard must read token from location.search")
                try expect(html.contains("t'"))  // qs.get('t')
            }

            TestHarness.test("HTML declares dark-mode adaptation") {
                try expect(WebDashboard.html.contains("prefers-color-scheme"),
                           "dashboard must adapt to system appearance")
            }

            TestHarness.test("LocalState JSON round-trips via Codable") {
                let state = WebDashboard.State(
                    device: "Test Mac",
                    uuid: "0000-…",
                    port: 12345,
                    peerCount: 2,
                    active: [
                        .init(url: "https://x/1", filename: "a.iso",
                              outputPath: "/tmp/a", totalBytes: 100,
                              downloaded: 50, chunkSize: 4 * 1024 * 1024,
                              completedChunks: [0, 1])
                    ],
                    completed: [
                        .init(url: "https://x/2", filename: "b.iso",
                              outputPath: "/tmp/b", totalBytes: 200,
                              finishedAt: Date(timeIntervalSince1970: 1_000_000),
                              sha256: "deadbeef")
                    ]
                )
                let enc = JSONEncoder()
                enc.dateEncodingStrategy = .iso8601
                let data = try enc.encode(state)
                let dec = JSONDecoder()
                dec.dateDecodingStrategy = .iso8601
                let round = try dec.decode(WebDashboard.State.self, from: data)
                try expectEqual(round.device, "Test Mac")
                try expectEqual(round.port, 12345)
                try expectEqual(round.active.first?.completedChunks ?? [], [0, 1])
                try expectEqual(round.completed.first?.sha256, "deadbeef")
            }
        }
    }
}
