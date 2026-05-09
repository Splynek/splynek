import Foundation
@testable import SplynekCore

/// Pure-logic tests for the Trust Watcher.  Network fetches are
/// covered separately by `TrustWatchServiceTests`; this file
/// exercises only the deterministic functions in `TrustWatcher`
/// plus the in-memory store mutations.
enum TrustWatcherTests {

    static func run() {
        TestHarness.suite("Trust Watcher — body normalisation") {

            TestHarness.test("normalize collapses whitespace runs") {
                let input  = "Hello   \t\n  world\n\n"
                let output = TrustWatcher.normalize(input)
                try expect(output == "hello world",
                           "expected 'hello world', got '\(output)'")
            }

            TestHarness.test("normalize lowercases ASCII") {
                let output = TrustWatcher.normalize("Privacy POLICY")
                try expect(output == "privacy policy",
                           "expected lowercase, got '\(output)'")
            }

            TestHarness.test("normalize strips <script> blocks") {
                let html = """
                    <html>
                      <head>
                        <script>console.log("session-id-12345");</script>
                      </head>
                      <body>Privacy Policy</body>
                    </html>
                    """
                let output = TrustWatcher.normalize(html)
                try expect(!output.contains("session-id-12345"),
                           "<script> contents leaked into normalised output")
                try expect(output.contains("privacy policy"),
                           "body content stripped along with script")
            }

            TestHarness.test("normalize strips <style> blocks") {
                let html = """
                    <style>.timestamp:after { content: '2026-05-09T12:34:56Z'; }</style>
                    <body>Terms of Service</body>
                    """
                let output = TrustWatcher.normalize(html)
                try expect(!output.contains("12:34:56"),
                           "<style> contents leaked into normalised output")
            }

            TestHarness.test("normalize is case-insensitive on tags") {
                let html = "<SCRIPT>noise</SCRIPT><body>Real text</body>"
                let output = TrustWatcher.normalize(html)
                try expect(!output.contains("noise"),
                           "uppercase <SCRIPT> not stripped: '\(output)'")
            }

            TestHarness.test("normalize is stable for whitespace-only changes") {
                let a = TrustWatcher.normalize("Privacy   Policy\nv2")
                let b = TrustWatcher.normalize("Privacy\t\tPolicy\nv2")
                try expect(a == b,
                           "different whitespace produced different output: '\(a)' vs '\(b)'")
            }
        }

        TestHarness.suite("Trust Watcher — SHA-256 hashing") {

            TestHarness.test("sha256Hex is deterministic") {
                let a = TrustWatcher.sha256Hex("hello")
                let b = TrustWatcher.sha256Hex("hello")
                try expect(a == b, "sha256 not deterministic")
            }

            TestHarness.test("sha256Hex differs for different inputs") {
                let a = TrustWatcher.sha256Hex("hello")
                let b = TrustWatcher.sha256Hex("world")
                try expect(a != b, "sha256 collision on trivial inputs")
            }

            TestHarness.test("sha256Hex is 64 hex characters") {
                let h = TrustWatcher.sha256Hex("anything")
                try expect(h.count == 64, "expected 64 hex chars, got \(h.count)")
                let hexset = Set("0123456789abcdef")
                try expect(h.allSatisfy { hexset.contains($0) },
                           "non-hex character in: \(h)")
            }
        }

        TestHarness.suite("Trust Watcher — diff engine") {

            let target = TrustWatchTarget(
                bundleID: "test.app",
                kind: .privacyPolicy,
                url: URL(string: "https://example.invalid/privacy")!,
                displayName: "Test App"
            )

            TestHarness.test("Identical hashes produce no alert") {
                let snap = TrustWatchSnapshot(
                    target: target, bodyHash: "abc",
                    bodyLength: 1000, observedAt: "2026-05-09T00:00:00Z",
                    httpStatus: 200
                )
                let alert = TrustWatcher.diff(previous: snap, current: snap)
                try expect(alert == nil, "no alert expected for identical snapshots")
            }

            TestHarness.test("Different hashes produce an alert") {
                let prev = TrustWatchSnapshot(
                    target: target, bodyHash: "abc",
                    bodyLength: 1000, observedAt: "2026-05-09T00:00:00Z",
                    httpStatus: 200
                )
                let curr = TrustWatchSnapshot(
                    target: target, bodyHash: "def",
                    bodyLength: 1100, observedAt: "2026-05-09T01:00:00Z",
                    httpStatus: 200
                )
                let alert = TrustWatcher.diff(previous: prev, current: curr)
                try expect(alert != nil, "expected alert when hashes differ")
            }

            TestHarness.test("Non-200 fetches never alert") {
                let prev = TrustWatchSnapshot(
                    target: target, bodyHash: "abc",
                    bodyLength: 1000, observedAt: "x",
                    httpStatus: 200
                )
                let curr = TrustWatchSnapshot(
                    target: target, bodyHash: "def",
                    bodyLength: 1100, observedAt: "x",
                    httpStatus: 503
                )
                let alert = TrustWatcher.diff(previous: prev, current: curr)
                try expect(alert == nil, "503 should not alert")
            }

            TestHarness.test("Severity escalates with body delta") {
                let prev = TrustWatchSnapshot(
                    target: target, bodyHash: "a",
                    bodyLength: 1000, observedAt: "x", httpStatus: 200
                )
                // <5% delta → info
                let small = TrustWatchSnapshot(
                    target: target, bodyHash: "b",
                    bodyLength: 1020, observedAt: "x", httpStatus: 200
                )
                // 5-20% delta → notice
                let medium = TrustWatchSnapshot(
                    target: target, bodyHash: "c",
                    bodyLength: 1100, observedAt: "x", httpStatus: 200
                )
                // >20% delta → material
                let large = TrustWatchSnapshot(
                    target: target, bodyHash: "d",
                    bodyLength: 1500, observedAt: "x", httpStatus: 200
                )
                try expect(TrustWatcher.diff(previous: prev, current: small)?.severity == .info,
                           "expected .info for small delta")
                try expect(TrustWatcher.diff(previous: prev, current: medium)?.severity == .notice,
                           "expected .notice for medium delta")
                try expect(TrustWatcher.diff(previous: prev, current: large)?.severity == .material,
                           "expected .material for large delta")
            }
        }

        TestHarness.suite("Trust Watcher — store") {

            let target = TrustWatchTarget(
                bundleID: "test.app",
                kind: .privacyPolicy,
                url: URL(string: "https://example.invalid/p")!,
                displayName: "Test App"
            )
            let alert = TrustWatchAlert(
                target: target,
                previousHash: "a", newHash: "b",
                previousLength: 100, newLength: 110,
                observedAt: "2026-05-09T00:00:00Z",
                severity: .info
            )

            TestHarness.test("recordAlert inserts at head") {
                var store = TrustWatchStore.empty
                store.recordAlert(alert)
                try expect(store.alerts.count == 1, "alert not inserted")
                try expect(store.alerts.first?.id == alert.id, "wrong alert at head")
            }

            TestHarness.test("recordAlert is idempotent on same id") {
                var store = TrustWatchStore.empty
                store.recordAlert(alert)
                store.recordAlert(alert)
                try expect(store.alerts.count == 1,
                           "duplicate insert should dedupe by id")
            }

            TestHarness.test("acknowledge marks alert acknowledged") {
                var store = TrustWatchStore.empty
                store.recordAlert(alert)
                store.acknowledge(alertID: alert.id)
                try expect(store.alerts.first?.acknowledged == true,
                           "acknowledge did not stick")
                try expect(store.pendingAlertCount == 0,
                           "pending count not zero after acknowledge")
            }

            TestHarness.test("acknowledgeAll clears every pending") {
                var store = TrustWatchStore.empty
                store.recordAlert(alert)
                let a2 = TrustWatchAlert(
                    target: target, previousHash: "x", newHash: "y",
                    previousLength: 100, newLength: 200,
                    observedAt: "2026-05-09T01:00:00Z", severity: .material
                )
                store.recordAlert(a2)
                try expect(store.pendingAlertCount == 2, "pending count wrong before ack")
                store.acknowledgeAll()
                try expect(store.pendingAlertCount == 0,
                           "acknowledgeAll left pending alerts: \(store.pendingAlertCount)")
            }

            TestHarness.test("alertCap bounds the alert log") {
                var store = TrustWatchStore.empty
                let cap = TrustWatchStore.alertCap
                // Use a distinct second per insertion so the alert IDs
                // don't collide via dedupe — the cap is the constraint
                // we're exercising, not the dedupe.
                for i in 0..<(cap + 20) {
                    let mins = String(format: "%02d", (i / 60) % 60)
                    let secs = String(format: "%02d", i % 60)
                    let hours = String(format: "%02d", i / 3600)
                    let a = TrustWatchAlert(
                        target: target,
                        previousHash: "a", newHash: "b",
                        previousLength: 100, newLength: 110 + i,
                        observedAt: "2026-05-09T\(hours):\(mins):\(secs)Z",
                        severity: .info
                    )
                    store.recordAlert(a)
                }
                try expect(store.alerts.count == cap,
                           "alert log not capped: count=\(store.alerts.count)")
            }
        }

        TestHarness.suite("Trust Watcher — catalog seed") {

            TestHarness.test("Catalog has at least 8 distinct apps") {
                let count = TrustWatchCatalog.watchedBundleIDs.count
                try expect(count >= 8,
                           "expected >= 8 distinct apps in seed, got \(count)")
            }

            TestHarness.test("Every catalog URL is https") {
                for t in TrustWatchCatalog.targets {
                    try expect(t.url.scheme?.lowercased() == "https",
                               "non-https URL in catalog: \(t.url)")
                }
            }

            TestHarness.test("Every app has at least one Privacy Policy URL") {
                let bundles = TrustWatchCatalog.watchedBundleIDs
                for bundle in bundles {
                    let kinds = Set(TrustWatchCatalog
                        .targets(for: bundle).map(\.kind))
                    try expect(kinds.contains(.privacyPolicy),
                               "\(bundle) missing privacyPolicy entry")
                }
            }

            TestHarness.test("targets(for:) returns the right entries") {
                let spotify = TrustWatchCatalog.targets(for: "com.spotify.client")
                try expect(spotify.count >= 1,
                           "Spotify not in seed: count=\(spotify.count)")
                for t in spotify {
                    try expect(t.bundleID == "com.spotify.client",
                               "wrong bundle: \(t.bundleID)")
                }
            }
        }
    }
}
