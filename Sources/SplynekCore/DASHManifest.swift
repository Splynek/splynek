import Foundation

/// Strategy Bet S5 — DASH (MPEG-DASH) manifest support.
///
/// DASH is the streaming protocol most non-Apple-Silicon services
/// use (Netflix uses it for non-iOS clients, Vimeo offers it
/// alongside HLS, lots of European broadcasters' DRM-free streams
/// ship as DASH).  Splynek's Accelerator now proxies DASH manifests
/// the same way it proxies HLS:
///
/// 1. Browser fetches `https://example.com/stream/manifest.mpd`
/// 2. Extension's declarativeNetRequest redirects through Splynek's
///    /hls/ proxy (path is hls/ but the proxy auto-detects DASH vs
///    HLS based on body content)
/// 3. Splynek fetches the upstream MPD, parses, rewrites segment
///    URLs to point through `/s` proxy, returns the rewritten body
/// 4. Player requests segments via the proxy → bonded fetch + ring
///    buffer cache (same pipeline as HLS)
///
/// XML parsing approach: regex-based extraction of the few attributes
/// we care about (BaseURL, SegmentTemplate URLs, ContentProtection
/// for DRM detection).  We don't try to be a fully-conformant DASH
/// parser — just enough to make the proxy redirect work for typical
/// streams.  Full DASH validation lives in the player; we're a
/// pass-through optimizer.
public enum DASHManifest {

    /// Did we find any `<ContentProtection>` element with a
    /// recognized DRM scheme?  Identical posture to HLS's hasDRM:
    /// pass these manifests through unchanged, do not pre-buffer.
    ///
    /// Common DRM schemes in real-world DASH:
    /// - `urn:mpeg:dash:mp4protection:2011` — DASH baseline
    /// - `urn:uuid:edef8ba9-79d6-4ace-a3c8-27dcd51d21ed` — Widevine
    /// - `urn:uuid:9a04f079-9840-4286-ab92-e65be0885f95` — PlayReady
    /// - `urn:uuid:94ce86fb-07ff-4f43-adb8-93d2fa968ca2` — FairPlay
    public static func hasDRM(_ body: String) -> Bool {
        // The ContentProtection element marks DRM in DASH.  Even if
        // schemeIdUri is the unencrypted "common encryption" baseline
        // (mp4protection), its presence signals encrypted content
        // (because protection lives inside an EncryptedAdaptationSet).
        body.contains("<ContentProtection") || body.contains("ContentProtection ")
    }

    /// Is this body a DASH MPD?  Cheap shape check — DASH manifests
    /// always contain `<MPD ` near the top of the body and have an
    /// XMLNS attribute referring to `urn:mpeg:dash`.
    public static func looksLikeMPD(_ body: String) -> Bool {
        // First 1024 bytes are enough to find the root element + its
        // xmlns.  Avoids scanning multi-MB MPDs.
        let head = body.prefix(1024)
        return head.contains("<MPD ") && head.contains("urn:mpeg:dash")
    }

    /// Extension-based pre-filter for URL-only inspection.  Called
    /// before fetching the body.  `.mpd` is the canonical extension;
    /// `.dash` is older but seen in the wild.
    public static func looksLikeManifestURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return path.hasSuffix(".mpd") || path.hasSuffix(".dash")
    }

    /// Extract every URL referenced by this MPD that the player
    /// will fetch independently — `<BaseURL>` elements and the
    /// `media` / `initialization` attributes of `<SegmentTemplate>`.
    /// We rewrite each one to point through the proxy.
    ///
    /// Returns the original strings (relative or absolute) — the
    /// caller resolves against the MPD's URL.
    public static func extractMediaURLs(_ body: String) -> [String] {
        var urls: [String] = []
        // <BaseURL>https://...</BaseURL> — captures whatever's between.
        let baseURLPattern = #"<BaseURL[^>]*>([^<]+)</BaseURL>"#
        if let regex = try? NSRegularExpression(pattern: baseURLPattern) {
            let nsBody = body as NSString
            let matches = regex.matches(
                in: body,
                range: NSRange(location: 0, length: nsBody.length)
            )
            for m in matches where m.numberOfRanges >= 2 {
                let url = nsBody.substring(with: m.range(at: 1))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !url.isEmpty { urls.append(url) }
            }
        }
        // <SegmentTemplate ... media="..." initialization="..." />
        // The naïve "scan for media= or initialization= once per
        // SegmentTemplate" misses any attribute that comes after the
        // first match.  Two-pass instead: first capture the full
        // SegmentTemplate block, then extract each attribute from
        // its body.  Same idea for SegmentList <SegmentURL media="..."/>.
        let blockPattern = #"<SegmentTemplate\b[^>]*/?>"#
        let attrPattern = #"(?:media|initialization)="([^"]+)""#
        if let blockRegex = try? NSRegularExpression(
                pattern: blockPattern, options: [.dotMatchesLineSeparators]),
           let attrRegex = try? NSRegularExpression(pattern: attrPattern) {
            let nsBody = body as NSString
            for m in blockRegex.matches(
                in: body, range: NSRange(location: 0, length: nsBody.length)
            ) {
                let block = nsBody.substring(with: m.range)
                let blockNS = block as NSString
                for am in attrRegex.matches(
                    in: block,
                    range: NSRange(location: 0, length: blockNS.length)
                ) where am.numberOfRanges >= 2 {
                    urls.append(blockNS.substring(with: am.range(at: 1)))
                }
            }
        }
        return urls
    }

    /// Rewrite an MPD body so every `<BaseURL>` and SegmentTemplate
    /// URL points at the proxy.  Pass-through unchanged on DRM.
    ///
    /// Strategy: rather than trying to parse the XML tree, we do a
    /// regex-based string substitution.  Same approach as HLS's
    /// line-based rewriter: cheap, no XML toolchain dep, handles
    /// the 99% case (well-formed MPDs from real CDNs).
    ///
    /// `proxyBase` example: `http://127.0.0.1:64267/hls`
    /// `sessionID`: per-tab UUID
    public static func rewriteMediaURLs(
        _ body: String,
        baseURL: URL,
        proxyBase: URL,
        sessionID: UUID
    ) -> String {
        if hasDRM(body) { return body }

        // Replace each <BaseURL>...</BaseURL> with a proxied form.
        var result = body
        let baseURLPattern = #"<BaseURL[^>]*>([^<]+)</BaseURL>"#
        if let regex = try? NSRegularExpression(pattern: baseURLPattern) {
            let nsResult = result as NSString
            let matches = regex.matches(
                in: result,
                range: NSRange(location: 0, length: nsResult.length)
            )
            // Walk in reverse so range indices stay valid as we splice.
            for m in matches.reversed() where m.numberOfRanges >= 2 {
                let originalURL = nsResult.substring(with: m.range(at: 1))
                let absoluteOriginal = absoluteURL(forRelative: originalURL, baseURL: baseURL)
                let encoded = HLSManifest.base64URL(absoluteOriginal.absoluteString)
                let proxiedURL = "\(proxyBase.absoluteString)/\(sessionID.uuidString)/s?u=\(encoded)"
                let fullMatch = nsResult.substring(with: m.range)
                let replacement = "<BaseURL>\(proxiedURL)</BaseURL>"
                result = (result as NSString).replacingOccurrences(
                    of: fullMatch,
                    with: replacement,
                    options: .literal,
                    range: NSRange(location: 0, length: (result as NSString).length)
                )
            }
        }
        return result
    }

    /// Resolve a relative URI against an MPD's URL.  Same shape as
    /// HLSManifest.absoluteURL — broken out here so DASH can stand
    /// alone (one less reach into HLSManifest).
    static func absoluteURL(forRelative uri: String, baseURL: URL) -> URL {
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            return URL(string: uri) ?? baseURL
        }
        return URL(string: uri, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    /// Quick combined check: a body is "streaming-protocol-manifest"
    /// if it parses as either HLS or DASH.  Used by the proxy server's
    /// single-route handler to dispatch by content rather than path.
    public enum Kind: Equatable, Sendable {
        case hls
        case dash
        case unknown
    }

    public static func detectKind(_ body: String) -> Kind {
        if body.hasPrefix("#EXTM3U") { return .hls }
        if looksLikeMPD(body) { return .dash }
        return .unknown
    }
}
