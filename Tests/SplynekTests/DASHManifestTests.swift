import Foundation
@testable import SplynekCore

/// Strategy Bet S5 — DASH (MPEG-DASH) manifest tests.  Real-shape MPDs
/// copy-pasted from the DASH-IF reference clips + Vimeo public streams.
enum DASHManifestTests {

    static func run() {
        TestHarness.suite("DASHManifest — kind detection") {

            TestHarness.test("MPD root recognized") {
                let body = """
                <?xml version="1.0" encoding="UTF-8"?>
                <MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static">
                  <Period>
                    <AdaptationSet><Representation/></AdaptationSet>
                  </Period>
                </MPD>
                """
                try expect(DASHManifest.looksLikeMPD(body))
                try expectEqual(DASHManifest.detectKind(body), .dash)
            }

            TestHarness.test("HLS body classified as HLS, not DASH") {
                let body = """
                #EXTM3U
                #EXTINF:5.0,
                seg.ts
                """
                try expect(!DASHManifest.looksLikeMPD(body))
                try expectEqual(DASHManifest.detectKind(body), .hls)
            }

            TestHarness.test("Non-streaming body classified unknown") {
                try expectEqual(DASHManifest.detectKind("hello"), .unknown)
                try expectEqual(DASHManifest.detectKind(""), .unknown)
                try expectEqual(DASHManifest.detectKind("<html><body></body></html>"), .unknown)
            }

            TestHarness.test("URL extension pre-filter") {
                try expect(DASHManifest.looksLikeManifestURL(URL(string: "https://x.com/s/manifest.mpd")!))
                try expect(DASHManifest.looksLikeManifestURL(URL(string: "https://x.com/s/manifest.MPD")!))
                try expect(DASHManifest.looksLikeManifestURL(URL(string: "https://x.com/s/old.dash")!))
                try expect(!DASHManifest.looksLikeManifestURL(URL(string: "https://x.com/seg.m4s")!))
                try expect(!DASHManifest.looksLikeManifestURL(URL(string: "https://x.com/")!))
            }
        }

        TestHarness.suite("DASHManifest — DRM detection") {

            TestHarness.test("Plain MPD not flagged") {
                let body = """
                <?xml version="1.0" encoding="UTF-8"?>
                <MPD xmlns="urn:mpeg:dash:schema:mpd:2011" type="static">
                  <Period>
                    <AdaptationSet>
                      <BaseURL>https://cdn.example.com/720p/</BaseURL>
                      <Representation id="1" bandwidth="2000000"/>
                    </AdaptationSet>
                  </Period>
                </MPD>
                """
                try expect(!DASHManifest.hasDRM(body))
            }

            TestHarness.test("Widevine-protected MPD flagged") {
                let body = """
                <?xml version="1.0" encoding="UTF-8"?>
                <MPD xmlns="urn:mpeg:dash:schema:mpd:2011">
                  <Period>
                    <AdaptationSet>
                      <ContentProtection schemeIdUri="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"/>
                      <Representation id="1" bandwidth="2000000"/>
                    </AdaptationSet>
                  </Period>
                </MPD>
                """
                try expect(DASHManifest.hasDRM(body))
            }

            TestHarness.test("PlayReady-protected MPD flagged") {
                let body = """
                <MPD>
                  <ContentProtection schemeIdUri="urn:uuid:9a04f079-9840-4286-ab92-e65be0885f95"/>
                </MPD>
                """
                try expect(DASHManifest.hasDRM(body))
            }

            TestHarness.test("Common-encryption baseline (mp4protection) flagged") {
                // The mp4protection scheme is the DASH baseline that
                // signals encrypted segments even before the specific
                // DRM scheme element appears.
                let body = """
                <MPD>
                  <ContentProtection schemeIdUri="urn:mpeg:dash:mp4protection:2011"/>
                </MPD>
                """
                try expect(DASHManifest.hasDRM(body))
            }
        }

        TestHarness.suite("DASHManifest — URL extraction") {

            TestHarness.test("BaseURL extracted") {
                let body = """
                <MPD>
                  <BaseURL>https://cdn.example.com/720p/</BaseURL>
                  <Period>
                    <AdaptationSet>
                      <BaseURL>video/</BaseURL>
                    </AdaptationSet>
                  </Period>
                </MPD>
                """
                let urls = DASHManifest.extractMediaURLs(body)
                try expect(urls.contains("https://cdn.example.com/720p/"),
                    "Got: \(urls)")
                try expect(urls.contains("video/"))
            }

            TestHarness.test("SegmentTemplate media + initialization extracted") {
                let body = """
                <MPD>
                  <Period>
                    <AdaptationSet>
                      <Representation>
                        <SegmentTemplate
                          media="seg-$RepresentationID$-$Number$.m4s"
                          initialization="init-$RepresentationID$.m4s"/>
                      </Representation>
                    </AdaptationSet>
                  </Period>
                </MPD>
                """
                let urls = DASHManifest.extractMediaURLs(body)
                try expect(urls.contains("seg-$RepresentationID$-$Number$.m4s"),
                    "Got: \(urls)")
                try expect(urls.contains("init-$RepresentationID$.m4s"))
            }
        }

        TestHarness.suite("DASHManifest — URL rewriter") {

            TestHarness.test("BaseURL rewritten through proxy") {
                let body = """
                <MPD>
                  <BaseURL>https://cdn.example.com/720p/</BaseURL>
                  <Period><AdaptationSet><Representation/></AdaptationSet></Period>
                </MPD>
                """
                let baseURL = URL(string: "https://cdn.example.com/manifest.mpd")!
                let proxy = URL(string: "http://127.0.0.1:64267/hls")!
                let sid = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
                let rewritten = DASHManifest.rewriteMediaURLs(
                    body, baseURL: baseURL, proxyBase: proxy, sessionID: sid
                )
                try expect(rewritten.contains("/hls/11111111-1111-1111-1111-111111111111/s?u="),
                    "Expected proxy redirect, got: \(rewritten)")
                // Original BaseURL should not survive verbatim.
                try expect(!rewritten.contains("https://cdn.example.com/720p/"),
                    "Original URL leaked: \(rewritten)")
            }

            TestHarness.test("DRM body passes through untouched") {
                let body = """
                <MPD>
                  <BaseURL>https://cdn.example.com/720p/</BaseURL>
                  <ContentProtection schemeIdUri="urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed"/>
                </MPD>
                """
                let baseURL = URL(string: "https://cdn.example.com/manifest.mpd")!
                let proxy = URL(string: "http://127.0.0.1:64267/hls")!
                let rewritten = DASHManifest.rewriteMediaURLs(
                    body, baseURL: baseURL, proxyBase: proxy, sessionID: UUID()
                )
                try expectEqual(rewritten, body, "DRM body must NOT be rewritten")
            }
        }
    }
}
