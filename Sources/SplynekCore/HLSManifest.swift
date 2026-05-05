import Foundation

/// Strategy Bet S5 — HLS pre-buffer support.
///
/// HLS (HTTP Live Streaming) is the streaming protocol most large
/// video sites use today (YouTube DRM-free streams, Vimeo public,
/// Twitch live + VOD, Plex, most HLS-on-CDN deployments).  A stream
/// is a tree of text manifests:
///
/// 1. **Master playlist** (`.m3u8`) — lists *variants* (different
///    bitrate/resolution renditions of the same content).  Each
///    variant points at its own media playlist.
/// 2. **Media playlist** (`.m3u8`) — lists *segments* (typically
///    2-10 second .ts or .mp4 chunks).  The browser's player picks
///    a variant + sequentially requests segments.
///
/// Splynek's HLS pre-buffer accelerates streaming by:
///
/// - Fetching segments via Splynek's bonded multi-interface engine
///   (Wi-Fi + Ethernet + iPhone tether at the same time)
/// - Pre-fetching N segments ahead of the player's playhead
/// - Storing them in a per-stream ring buffer, served back to the
///   player via a local HTTP proxy
///
/// The browser sees: every segment request returns instantly from
/// localhost.  Buffering disappears.
///
/// **This file ships the manifest-parsing layer only** — the smallest
/// piece that's testable in isolation.  The fetch + ring-buffer + HTTP
/// proxy layers come in subsequent commits (see HLS-DESIGN.md).
public enum HLSManifest {

    /// One variant in a master playlist.  We extract just enough to
    /// pick a variant and rewrite the master with our local proxy
    /// pointing at the chosen variant's media playlist.
    public struct Variant: Equatable, Sendable {
        public let bandwidth: Int        // bits/sec
        public let resolution: String?   // "1920x1080" or nil
        public let codecs: String?       // "avc1.640028,mp4a.40.2" etc.
        public let uri: String           // relative or absolute URL
    }

    /// One segment in a media playlist.
    public struct Segment: Equatable, Sendable {
        public let durationSeconds: Double
        public let uri: String
        public let byteRange: (offset: Int64, length: Int64)?

        public static func == (a: Segment, b: Segment) -> Bool {
            a.durationSeconds == b.durationSeconds
                && a.uri == b.uri
                && a.byteRange?.offset == b.byteRange?.offset
                && a.byteRange?.length == b.byteRange?.length
        }
    }

    public struct MasterPlaylist: Equatable, Sendable {
        public let variants: [Variant]
    }

    public struct MediaPlaylist: Equatable, Sendable {
        public let targetDuration: Int   // max segment length, seconds
        public let mediaSequence: Int    // first segment's index
        public let endlist: Bool          // true = VOD, false = live
        public let segments: [Segment]
    }

    /// Sniff a freshly-fetched manifest body and decide which kind
    /// it is.  Same heuristic browsers use: presence of #EXT-X-STREAM-INF
    /// → master, presence of #EXTINF → media, neither → not HLS.
    public enum Kind: Equatable, Sendable {
        case master(MasterPlaylist)
        case media(MediaPlaylist)
        case notHLS
    }

    /// Parse a manifest body.  Returns `.notHLS` for anything that
    /// doesn't start with `#EXTM3U` (HLS's mandatory leading line).
    public static func parse(_ body: String) -> Kind {
        let lines = body.split(separator: "\n", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let first = lines.first, first == "#EXTM3U" else {
            return .notHLS
        }
        if lines.contains(where: { $0.hasPrefix("#EXT-X-STREAM-INF") }) {
            return .master(parseMaster(lines: lines))
        }
        if lines.contains(where: { $0.hasPrefix("#EXTINF") }) {
            return .media(parseMedia(lines: lines))
        }
        return .notHLS
    }

    // MARK: - Master playlist parser

    /// Parse a master playlist.  Each variant is a 2-line pair:
    ///   #EXT-X-STREAM-INF:BANDWIDTH=2000000,RESOLUTION=1280x720,...
    ///   variant1.m3u8
    static func parseMaster(lines: [String]) -> MasterPlaylist {
        var variants: [Variant] = []
        var pendingAttrs: [String: String]?
        for line in lines {
            if line.hasPrefix("#EXT-X-STREAM-INF:") {
                pendingAttrs = parseAttributeList(after: "#EXT-X-STREAM-INF:", in: line)
            } else if !line.hasPrefix("#"), let attrs = pendingAttrs, !line.isEmpty {
                let bw = Int(attrs["BANDWIDTH"] ?? "") ?? 0
                let v = Variant(
                    bandwidth: bw,
                    resolution: attrs["RESOLUTION"],
                    codecs: attrs["CODECS"]?.trimmingCharacters(in: CharacterSet(charactersIn: "\"")),
                    uri: line
                )
                variants.append(v)
                pendingAttrs = nil
            }
        }
        return MasterPlaylist(variants: variants)
    }

    // MARK: - Media playlist parser

    static func parseMedia(lines: [String]) -> MediaPlaylist {
        var targetDuration = 0
        var mediaSequence = 0
        var endlist = false
        var segments: [Segment] = []
        var pendingDuration: Double?
        var pendingByteRange: (Int64, Int64)?
        for line in lines {
            if line.hasPrefix("#EXT-X-TARGETDURATION:") {
                targetDuration = Int(line.dropFirst("#EXT-X-TARGETDURATION:".count)) ?? 0
            } else if line.hasPrefix("#EXT-X-MEDIA-SEQUENCE:") {
                mediaSequence = Int(line.dropFirst("#EXT-X-MEDIA-SEQUENCE:".count)) ?? 0
            } else if line == "#EXT-X-ENDLIST" {
                endlist = true
            } else if line.hasPrefix("#EXTINF:") {
                // "#EXTINF:9.009,Title" — we want the leading float.
                let body = line.dropFirst("#EXTINF:".count)
                let durStr = body.split(separator: ",", maxSplits: 1).first.map(String.init) ?? ""
                pendingDuration = Double(durStr)
            } else if line.hasPrefix("#EXT-X-BYTERANGE:") {
                // "#EXT-X-BYTERANGE:524288@0" or "#EXT-X-BYTERANGE:524288"
                let body = line.dropFirst("#EXT-X-BYTERANGE:".count)
                let parts = body.split(separator: "@")
                let length = Int64(parts.first.map(String.init) ?? "") ?? 0
                let offset: Int64 = parts.count > 1
                    ? (Int64(parts[1]) ?? 0)
                    : 0
                pendingByteRange = (offset, length)
            } else if !line.hasPrefix("#"), let dur = pendingDuration, !line.isEmpty {
                segments.append(Segment(
                    durationSeconds: dur,
                    uri: line,
                    byteRange: pendingByteRange
                ))
                pendingDuration = nil
                pendingByteRange = nil
            }
        }
        return MediaPlaylist(
            targetDuration: targetDuration,
            mediaSequence: mediaSequence,
            endlist: endlist,
            segments: segments
        )
    }

    // MARK: - Attribute-list parser

    /// Parse a comma-separated `KEY=VALUE` list, handling double-
    /// quoted values that may themselves contain commas.  Used for
    /// the attributes after #EXT-X-STREAM-INF: and similar tags.
    static func parseAttributeList(after prefix: String, in line: String) -> [String: String] {
        let body = line.dropFirst(prefix.count)
        var result: [String: String] = [:]
        var i = body.startIndex
        while i < body.endIndex {
            // Skip leading whitespace + commas
            while i < body.endIndex, [",", " "].contains(body[i]) { i = body.index(after: i) }
            guard i < body.endIndex else { break }
            // Read key up to '='
            let keyStart = i
            while i < body.endIndex, body[i] != "=" { i = body.index(after: i) }
            guard i < body.endIndex else { break }  // unterminated attribute
            let key = String(body[keyStart..<i])
            i = body.index(after: i)  // skip '='
            // Read value: quoted (until closing ") or unquoted (until ',')
            var value = ""
            if i < body.endIndex, body[i] == "\"" {
                i = body.index(after: i)
                while i < body.endIndex, body[i] != "\"" {
                    value.append(body[i])
                    i = body.index(after: i)
                }
                if i < body.endIndex { i = body.index(after: i) }
            } else {
                while i < body.endIndex, body[i] != "," {
                    value.append(body[i])
                    i = body.index(after: i)
                }
            }
            result[key] = value
        }
        return result
    }

    // MARK: - URL classification

    /// Probe whether a URL's path is likely an HLS manifest based on
    /// extension alone.  Cheap pre-filter before fetching the body.
    /// We also fetch + sniff the body via `parse(_:)` to confirm.
    public static func looksLikeManifestURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        return path.hasSuffix(".m3u8") || path.hasSuffix(".m3u")
    }

    /// Pick the variant a player would prefer for a given target
    /// bandwidth.  Highest variant whose bandwidth doesn't exceed
    /// the target.  If all variants exceed, returns the lowest.
    public static func pickVariant(
        from master: MasterPlaylist,
        targetBandwidth: Int
    ) -> Variant? {
        guard !master.variants.isEmpty else { return nil }
        let sorted = master.variants.sorted { $0.bandwidth < $1.bandwidth }
        if let lastUnder = sorted.last(where: { $0.bandwidth <= targetBandwidth }) {
            return lastUnder
        }
        return sorted.first
    }

    // MARK: - DRM detection

    /// Returns true if the manifest has any encryption tag indicating
    /// DRM (Widevine / FairPlay / Sample-AES / etc.).  Splynek MUST
    /// pass these manifests through unchanged; pre-buffering DRM'd
    /// content is technically possible but legally fraught and
    /// undesirable for Splynek's positioning.
    ///
    /// HLS encryption is signalled by `#EXT-X-KEY:METHOD=...` for
    /// segment encryption (any non-NONE method) or by
    /// `#EXT-X-SESSION-KEY` at the master level.
    public static func hasDRM(_ body: String) -> Bool {
        for raw in body.split(separator: "\n", omittingEmptySubsequences: true) {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("#EXT-X-KEY:") || line.hasPrefix("#EXT-X-SESSION-KEY:") {
                let attrs = parseAttributeList(after: line.contains("SESSION-KEY")
                    ? "#EXT-X-SESSION-KEY:"
                    : "#EXT-X-KEY:", in: line)
                if let method = attrs["METHOD"], method != "NONE" {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - URL rewriting (proxy redirect)

    /// Rewrite a master playlist's variant URIs so they go through
    /// Splynek's local HLS proxy.  Each variant URI becomes a
    /// proxy URL that encodes the original variant's host + path so
    /// the proxy can re-resolve it.
    ///
    /// Format of rewritten URL:
    ///   <proxyBase>/<sessionID>/v?u=<base64-url-encoded-original-uri>
    ///
    /// The `v` (= variant) path differentiates from `s` (= segment)
    /// + `m` (= sub-playlist for direct media) so the proxy router
    /// can dispatch quickly without re-parsing.
    ///
    /// Lines other than variant URIs are passed through unchanged
    /// — preserves all #EXT-X-STREAM-INF attribute lines + extension
    /// tags Apple may add in future schema versions.
    public static func rewriteMasterURIs(
        _ body: String,
        variants: [Variant],
        baseURL: URL,
        proxyBase: URL,
        sessionID: UUID
    ) -> String {
        let variantURIs = Set(variants.map(\.uri))
        var rewritten: [String] = []
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.hasPrefix("#") && variantURIs.contains(trimmed) && !trimmed.isEmpty {
                let absoluteURI = absoluteURL(forRelative: trimmed, baseURL: baseURL)
                let encoded = base64URL(absoluteURI.absoluteString)
                let proxied = "\(proxyBase.absoluteString)/\(sessionID.uuidString)/v?u=\(encoded)"
                rewritten.append(proxied)
            } else {
                rewritten.append(line)
            }
        }
        return rewritten.joined(separator: "\n")
    }

    /// Same shape but for media playlists: rewrite each segment URI
    /// to point at the proxy's `/s` path (segment).
    public static func rewriteMediaURIs(
        _ body: String,
        segments: [Segment],
        baseURL: URL,
        proxyBase: URL,
        sessionID: UUID
    ) -> String {
        let segmentURIs = Set(segments.map(\.uri))
        var rewritten: [String] = []
        for raw in body.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw)
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.hasPrefix("#") && segmentURIs.contains(trimmed) && !trimmed.isEmpty {
                let absoluteURI = absoluteURL(forRelative: trimmed, baseURL: baseURL)
                let encoded = base64URL(absoluteURI.absoluteString)
                let proxied = "\(proxyBase.absoluteString)/\(sessionID.uuidString)/s?u=\(encoded)"
                rewritten.append(proxied)
            } else {
                rewritten.append(line)
            }
        }
        return rewritten.joined(separator: "\n")
    }

    /// Resolve a relative URI in a manifest against its baseURL.
    /// Absolute URIs (starting with http(s)://) pass through.
    static func absoluteURL(forRelative uri: String, baseURL: URL) -> URL {
        if uri.hasPrefix("http://") || uri.hasPrefix("https://") {
            return URL(string: uri) ?? baseURL
        }
        return URL(string: uri, relativeTo: baseURL)?.absoluteURL ?? baseURL
    }

    /// URL-safe base64 (no `+/=`, just `-_`).  Used to embed the
    /// original variant/segment URI inside our proxy URL's query
    /// string without escape-encoding pain.
    static func base64URL(_ s: String) -> String {
        let data = Data(s.utf8)
        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    /// Inverse of `base64URL` — decode a URI from a proxy URL's
    /// `?u=` query parameter.  Returns nil on malformed input.
    public static func decodeBase64URL(_ s: String) -> String? {
        var b64 = s
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Re-pad to a multiple of 4.
        while b64.count % 4 != 0 { b64 += "=" }
        guard let data = Data(base64Encoded: b64) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
