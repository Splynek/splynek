import Foundation
import SplynekCompanionCore

/// S4 iOS Companion (2026-05-07): tests for `ShareExtractor`, the
/// pure URL-extraction layer the Share Extension hands NSItemProvider
/// payloads to.  Pure Swift; no extension host required.
enum CompanionShareExtractorTests {

    static func run() {
        TestHarness.suite("ShareExtractor — single payload") {

            TestHarness.test("URL payload extracts directly") {
                let u = URL(string: "https://example.com/article")!
                let got = ShareExtractor.url(from: u)
                try expect(got?.host == "example.com")
            }

            TestHarness.test("NSURL payload extracts via cast") {
                let u = NSURL(string: "https://example.com/x")!
                let got = ShareExtractor.url(from: u)
                try expect(got?.scheme == "https")
            }

            TestHarness.test("String payload — bare URL") {
                let got = ShareExtractor.url(from: "https://splynek.app/path")
                try expect(got?.host == "splynek.app")
            }

            TestHarness.test("String payload — embedded URL extracted by NSDataDetector") {
                let got = ShareExtractor.url(from: "Check out https://example.com/foo bar")
                try expect(got?.host == "example.com")
            }

            TestHarness.test("Empty string returns nil") {
                try expect(ShareExtractor.url(from: "") == nil)
            }

            TestHarness.test("Non-URL types return nil") {
                try expect(ShareExtractor.url(from: 42) == nil)
                try expect(ShareExtractor.url(from: nil) == nil)
            }
        }

        TestHarness.suite("ShareExtractor — bestURL preference order") {

            TestHarness.test("Prefers https over http") {
                let payloads: [Any?] = [
                    URL(string: "http://insecure.example")!,
                    URL(string: "https://secure.example")!,
                ]
                let got = ShareExtractor.bestURL(from: payloads)
                try expect(got?.scheme == "https")
            }

            TestHarness.test("Prefers http over file://") {
                let payloads: [Any?] = [
                    URL(string: "file:///tmp/foo")!,
                    URL(string: "http://example.com")!,
                ]
                let got = ShareExtractor.bestURL(from: payloads)
                try expect(got?.scheme == "http")
            }

            TestHarness.test("Returns first when no https/http present") {
                let payloads: [Any?] = [URL(string: "file:///tmp/a")!]
                let got = ShareExtractor.bestURL(from: payloads)
                try expect(got?.scheme == "file")
            }

            TestHarness.test("Empty list returns nil") {
                try expect(ShareExtractor.bestURL(from: []) == nil)
            }
        }

        TestHarness.suite("ShareExtractor — canonicalize strips tracking") {

            TestHarness.test("Strips utm_* params") {
                let raw = URL(string:
                    "https://example.com/x?utm_source=newsletter&utm_medium=email&id=42")!
                let canon = ShareExtractor.canonicalize(raw)
                let q = URLComponents(url: canon, resolvingAgainstBaseURL: false)?.queryItems ?? []
                try expect(q.contains { $0.name == "id" })
                try expect(!q.contains { $0.name.hasPrefix("utm_") })
            }

            TestHarness.test("Strips fbclid + gclid") {
                let raw = URL(string:
                    "https://example.com/?fbclid=ABC&gclid=DEF")!
                let canon = ShareExtractor.canonicalize(raw)
                try expect((URLComponents(url: canon, resolvingAgainstBaseURL: false)?.queryItems ?? []).isEmpty)
            }

            TestHarness.test("Leaves non-tracking params intact") {
                let raw = URL(string: "https://example.com/?page=2&q=hello")!
                let canon = ShareExtractor.canonicalize(raw)
                let q = URLComponents(url: canon, resolvingAgainstBaseURL: false)?.queryItems ?? []
                try expect(q.count == 2)
            }

            TestHarness.test("Idempotent — canonicalize twice yields identical URL") {
                let raw = URL(string: "https://example.com/?utm_source=x&id=42")!
                let once = ShareExtractor.canonicalize(raw)
                let twice = ShareExtractor.canonicalize(once)
                try expect(once == twice)
            }
        }
    }
}
