import Foundation
@testable import SplynekCore

/// Strategy Bet S5 — HLS pre-buffer manifest-parser tests.
///
/// Real HLS manifests, copy-pasted from the public Apple Sample Streams
/// + the IETF spec.  The parser is the testable core of the HLS
/// pre-buffer feature; the fetch/proxy/buffer layers come later and
/// are integration-tested at runtime.
enum HLSManifestTests {

    static func run() {
        TestHarness.suite("HLSManifest — kind detection") {

            TestHarness.test("Master playlist detected") {
                let body = """
                #EXTM3U
                #EXT-X-VERSION:3
                #EXT-X-STREAM-INF:BANDWIDTH=1280000,RESOLUTION=640x360
                low.m3u8
                #EXT-X-STREAM-INF:BANDWIDTH=2560000,RESOLUTION=1280x720
                high.m3u8
                """
                if case .master(let pl) = HLSManifest.parse(body) {
                    try expect(pl.variants.count == 2, "Got \(pl.variants.count)")
                } else {
                    try expect(false, "Expected .master")
                }
            }

            TestHarness.test("Media playlist detected") {
                let body = """
                #EXTM3U
                #EXT-X-VERSION:3
                #EXT-X-TARGETDURATION:10
                #EXT-X-MEDIA-SEQUENCE:0
                #EXTINF:10.0,
                seg0.ts
                #EXTINF:10.0,
                seg1.ts
                #EXT-X-ENDLIST
                """
                if case .media(let pl) = HLSManifest.parse(body) {
                    try expectEqual(pl.targetDuration, 10)
                    try expectEqual(pl.mediaSequence, 0)
                    try expect(pl.endlist)
                    try expectEqual(pl.segments.count, 2)
                    try expectEqual(pl.segments[0].uri, "seg0.ts")
                    try expectEqual(pl.segments[0].durationSeconds, 10.0)
                } else {
                    try expect(false, "Expected .media")
                }
            }

            TestHarness.test("Non-HLS body returns notHLS") {
                try expectEqual(HLSManifest.parse("hello"), .notHLS)
                try expectEqual(HLSManifest.parse(""), .notHLS)
                try expectEqual(HLSManifest.parse("# Not a manifest"), .notHLS)
                try expectEqual(HLSManifest.parse("<html>"), .notHLS)
            }

            TestHarness.test("EXTM3U-only file is notHLS (no variants, no segments)") {
                try expectEqual(HLSManifest.parse("#EXTM3U\n"), .notHLS)
            }
        }

        TestHarness.suite("HLSManifest — master playlist parser") {

            TestHarness.test("Quoted CODECS attribute with embedded comma") {
                let body = """
                #EXTM3U
                #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,CODECS="avc1.640028,mp4a.40.2"
                http://example.com/720p.m3u8
                """
                if case .master(let pl) = HLSManifest.parse(body) {
                    try expectEqual(pl.variants.count, 1)
                    try expectEqual(pl.variants[0].codecs, "avc1.640028,mp4a.40.2")
                    try expectEqual(pl.variants[0].uri, "http://example.com/720p.m3u8")
                } else {
                    try expect(false, "Expected .master")
                }
            }

            TestHarness.test("Multiple variants, sorted by bandwidth via pickVariant") {
                let body = """
                #EXTM3U
                #EXT-X-STREAM-INF:BANDWIDTH=500000,RESOLUTION=480x270
                low.m3u8
                #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720
                med.m3u8
                #EXT-X-STREAM-INF:BANDWIDTH=8000000,RESOLUTION=1920x1080
                high.m3u8
                """
                if case .master(let pl) = HLSManifest.parse(body) {
                    // Pick at 3 Mbps → med.m3u8 (highest <= 3M)
                    let p = HLSManifest.pickVariant(from: pl, targetBandwidth: 3_000_000)
                    try expectEqual(p?.uri, "med.m3u8")
                    // Pick at 100 Kbps → low.m3u8 (lowest, even though >target)
                    let p2 = HLSManifest.pickVariant(from: pl, targetBandwidth: 100_000)
                    try expectEqual(p2?.uri, "low.m3u8")
                    // Pick at 100 Mbps → high.m3u8 (highest)
                    let p3 = HLSManifest.pickVariant(from: pl, targetBandwidth: 100_000_000)
                    try expectEqual(p3?.uri, "high.m3u8")
                } else {
                    try expect(false, "Expected .master")
                }
            }
        }

        TestHarness.suite("HLSManifest — media playlist parser") {

            TestHarness.test("Live playlist (no ENDLIST)") {
                let body = """
                #EXTM3U
                #EXT-X-VERSION:6
                #EXT-X-TARGETDURATION:6
                #EXT-X-MEDIA-SEQUENCE:42
                #EXTINF:5.984,
                seg42.ts
                #EXTINF:6.000,
                seg43.ts
                """
                if case .media(let pl) = HLSManifest.parse(body) {
                    try expect(!pl.endlist)
                    try expectEqual(pl.mediaSequence, 42)
                    try expectEqual(pl.segments.count, 2)
                    let delta = abs(pl.segments[0].durationSeconds - 5.984)
                    try expect(delta < 0.001, "Got \(pl.segments[0].durationSeconds)")
                } else {
                    try expect(false, "Expected .media")
                }
            }

            TestHarness.test("Byte-range segments (fragmented MP4)") {
                let body = """
                #EXTM3U
                #EXT-X-TARGETDURATION:10
                #EXT-X-MEDIA-SEQUENCE:0
                #EXT-X-BYTERANGE:524288@1024
                #EXTINF:9.5,
                init.mp4
                #EXT-X-BYTERANGE:524288
                #EXTINF:10.0,
                init.mp4
                #EXT-X-ENDLIST
                """
                if case .media(let pl) = HLSManifest.parse(body) {
                    try expectEqual(pl.segments.count, 2)
                    try expect(pl.segments[0].byteRange?.offset == 1024)
                    try expect(pl.segments[0].byteRange?.length == 524288)
                    try expect(pl.segments[1].byteRange?.offset == 0)
                    try expect(pl.segments[1].byteRange?.length == 524288)
                } else {
                    try expect(false, "Expected .media")
                }
            }
        }

        TestHarness.suite("HLSManifest — looksLikeManifestURL pre-filter") {

            TestHarness.test("Standard .m3u8 path") {
                let url = URL(string: "https://example.com/stream/master.m3u8")!
                try expect(HLSManifest.looksLikeManifestURL(url))
            }

            TestHarness.test(".m3u variant accepted (older HLS)") {
                let url = URL(string: "https://example.com/stream/old.m3u")!
                try expect(HLSManifest.looksLikeManifestURL(url))
            }

            TestHarness.test("Query-string after .m3u8 OK") {
                let url = URL(string: "https://example.com/stream/master.m3u8?t=token123")!
                try expect(HLSManifest.looksLikeManifestURL(url))
            }

            TestHarness.test("Non-manifest paths reject") {
                try expect(!HLSManifest.looksLikeManifestURL(URL(string: "https://example.com/file.ts")!))
                try expect(!HLSManifest.looksLikeManifestURL(URL(string: "https://example.com/page.html")!))
                try expect(!HLSManifest.looksLikeManifestURL(URL(string: "https://example.com/")!))
            }

            TestHarness.test("Case-insensitive on extension") {
                let url = URL(string: "https://example.com/MASTER.M3U8")!
                try expect(HLSManifest.looksLikeManifestURL(url))
            }
        }

        TestHarness.suite("HLSManifest — attribute-list parser") {

            TestHarness.test("Mixed quoted + unquoted attributes") {
                let line = "#EXT-X-STREAM-INF:BANDWIDTH=1500000,RESOLUTION=1024x576,CODECS=\"avc1.64,mp4a\",NAME=\"med\""
                let attrs = HLSManifest.parseAttributeList(after: "#EXT-X-STREAM-INF:", in: line)
                try expectEqual(attrs["BANDWIDTH"], "1500000")
                try expectEqual(attrs["RESOLUTION"], "1024x576")
                try expectEqual(attrs["CODECS"], "avc1.64,mp4a")
                try expectEqual(attrs["NAME"], "med")
            }
        }

        TestHarness.suite("HLSManifest — DRM detection") {

            TestHarness.test("Plain manifest is not flagged") {
                let body = """
                #EXTM3U
                #EXT-X-TARGETDURATION:6
                #EXTINF:5.0,
                seg0.ts
                #EXT-X-ENDLIST
                """
                try expect(!HLSManifest.hasDRM(body))
            }

            TestHarness.test("AES-128 segment encryption flagged") {
                let body = """
                #EXTM3U
                #EXT-X-KEY:METHOD=AES-128,URI="https://example.com/key.bin"
                #EXT-X-TARGETDURATION:6
                #EXTINF:5.0,
                seg0.ts
                """
                try expect(HLSManifest.hasDRM(body))
            }

            TestHarness.test("FairPlay session-key flagged at master level") {
                let body = """
                #EXTM3U
                #EXT-X-SESSION-KEY:METHOD=SAMPLE-AES,URI="skd://key",KEYFORMAT="com.apple.streamingkeydelivery"
                #EXT-X-STREAM-INF:BANDWIDTH=2000000
                main.m3u8
                """
                try expect(HLSManifest.hasDRM(body))
            }

            TestHarness.test("METHOD=NONE explicitly NOT flagged") {
                // Spec quirk: an explicit "no encryption" tag exists.
                // Pre-buffer is fine for these.
                let body = """
                #EXTM3U
                #EXT-X-KEY:METHOD=NONE
                #EXTINF:5.0,
                seg0.ts
                """
                try expect(!HLSManifest.hasDRM(body))
            }
        }

        TestHarness.suite("HLSManifest — URL rewriter") {

            TestHarness.test("Master playlist variants get rewritten through proxy") {
                let body = """
                #EXTM3U
                #EXT-X-STREAM-INF:BANDWIDTH=500000
                low.m3u8
                #EXT-X-STREAM-INF:BANDWIDTH=2000000
                high.m3u8
                """
                guard case .master(let pl) = HLSManifest.parse(body) else {
                    try expect(false, "Expected master")
                    return
                }
                let baseURL = URL(string: "https://cdn.example.com/stream/master.m3u8")!
                let proxy = URL(string: "http://127.0.0.1:64267/hls")!
                let sid = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
                let rewritten = HLSManifest.rewriteMasterURIs(
                    body, variants: pl.variants,
                    baseURL: baseURL, proxyBase: proxy, sessionID: sid
                )
                try expect(rewritten.contains("http://127.0.0.1:64267/hls/11111111-1111-1111-1111-111111111111/v?u="),
                           "Expected proxy redirect, got: \(rewritten)")
                // The pre-existing #EXT-X-STREAM-INF tags must be
                // preserved verbatim — the player relies on them.
                try expect(rewritten.contains("#EXT-X-STREAM-INF:BANDWIDTH=500000"))
                // The original variant URIs must be GONE.
                try expect(!rewritten.contains("\nlow.m3u8"))
                try expect(!rewritten.contains("\nhigh.m3u8"))
            }

            TestHarness.test("Media playlist segments get rewritten through proxy") {
                let body = """
                #EXTM3U
                #EXT-X-TARGETDURATION:6
                #EXT-X-MEDIA-SEQUENCE:0
                #EXTINF:5.0,
                seg0.ts
                #EXTINF:5.0,
                seg1.ts
                #EXT-X-ENDLIST
                """
                guard case .media(let pl) = HLSManifest.parse(body) else {
                    try expect(false, "Expected media")
                    return
                }
                let baseURL = URL(string: "https://cdn.example.com/720p/v.m3u8")!
                let proxy = URL(string: "http://127.0.0.1:64267/hls")!
                let sid = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
                let rewritten = HLSManifest.rewriteMediaURIs(
                    body, segments: pl.segments,
                    baseURL: baseURL, proxyBase: proxy, sessionID: sid
                )
                try expect(rewritten.contains("/hls/22222222-2222-2222-2222-222222222222/s?u="),
                           "Expected segment proxy, got: \(rewritten)")
                try expect(rewritten.contains("#EXT-X-TARGETDURATION:6"))
                try expect(rewritten.contains("#EXT-X-ENDLIST"))
            }

            TestHarness.test("Base64URL roundtrip — no padding, URL-safe charset") {
                let cases = [
                    "https://cdn.example.com/720p/seg42.ts",
                    "https://cdn.example.com/path?with=query&and=ampersand",
                    "https://example.com/",
                ]
                for original in cases {
                    let encoded = HLSManifest.base64URL(original)
                    try expect(!encoded.contains("+"), "Got + in: \(encoded)")
                    try expect(!encoded.contains("/"), "Got / in: \(encoded)")
                    try expect(!encoded.contains("="), "Got = in: \(encoded)")
                    let decoded = HLSManifest.decodeBase64URL(encoded)
                    try expectEqual(decoded, original)
                }
            }

            TestHarness.test("Relative URI resolution against base URL") {
                let base = URL(string: "https://cdn.example.com/stream/dir/master.m3u8")!
                let abs1 = HLSManifest.absoluteURL(forRelative: "seg.ts", baseURL: base)
                try expectEqual(abs1.absoluteString, "https://cdn.example.com/stream/dir/seg.ts")
                let abs2 = HLSManifest.absoluteURL(forRelative: "../other.ts", baseURL: base)
                try expectEqual(abs2.absoluteString, "https://cdn.example.com/stream/other.ts")
                let abs3 = HLSManifest.absoluteURL(forRelative: "https://other.host/x.ts", baseURL: base)
                try expectEqual(abs3.absoluteString, "https://other.host/x.ts")
            }
        }
    }
}
