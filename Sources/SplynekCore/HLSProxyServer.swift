import Foundation

/// Strategy Bet S5 — HLS pre-buffer local proxy.
///
/// HTTP route handler that the FleetCoordinator's localhost server
/// dispatches to when the request path matches `/hls/...`.  See
/// `docs/HLS-DESIGN.md` for the full architecture.
///
/// Routes:
///   GET /hls/<sessionID>/v?u=<base64-url>
///       → fetch the variant playlist at <decoded URL>, parse it,
///         rewrite each segment URI through `/s` proxy, return
///         the rewritten body
///   GET /hls/<sessionID>/s?u=<base64-url>
///       → serve the segment bytes from the session's ring buffer
///         (or fetch on-demand if not yet pre-fetched), and trigger
///         pre-fetching of the next N segments
///   GET /hls/<sessionID>/master?u=<base64-url>
///       → fetch the master playlist, parse, rewrite all variant
///         URIs through `/v`, return the rewritten body
///
/// All three routes return their body verbatim if the upstream
/// response indicates DRM (#EXT-X-KEY:METHOD=...).  Splynek does
/// NOT pre-buffer DRM streams.
///
/// `pendingFetches` tracks in-flight segment fetches so multiple
/// pre-fetch waves don't double-fetch the same URL.
@MainActor
public final class HLSProxyServer {

    /// Per-session state.  Sessions are created on first /v request
    /// (variant playlist fetch) and persist for the duration of the
    /// playback.  Pruned by `prune(olderThan:)` periodically.
    public struct Session: Sendable {
        public let id: UUID
        public let masterURL: URL
        public var ringBuffer: HLSRingBuffer
        public var lastTouchedAt: Date
    }

    private(set) var sessions: [UUID: Session] = [:]
    private var pendingFetches: Set<URL> = []

    /// Number of segments to pre-fetch ahead of the playhead.  5 is
    /// a starting point (~30 s of buffer at typical 6 s segments);
    /// bigger wastes bandwidth, smaller re-introduces buffering.
    public var prefetchDepth: Int = 5

    public init() {}

    /// True if a path looks like an HLS proxy route the server should
    /// handle.  Cheap pre-filter for the FleetCoordinator dispatcher.
    /// `nonisolated` because it's a pure string-input check.
    nonisolated public static func handlesPath(_ path: String) -> Bool {
        path.hasPrefix("/hls/")
    }

    // MARK: - Route parser

    /// One of the three HLS proxy route shapes.
    public enum Route: Equatable, Sendable {
        case master(sessionID: UUID, upstreamURL: URL)
        case variant(sessionID: UUID, upstreamURL: URL)
        case segment(sessionID: UUID, upstreamURL: URL)
    }

    /// Parse a `/hls/<sid>/<kind>?u=<base64>` URL into a typed route.
    /// Returns nil for malformed input — the caller should respond
    /// 400 Bad Request.  `nonisolated` because it's pure URL parsing.
    nonisolated public static func parseRoute(_ url: URL) -> Route? {
        // Path components: [/, hls, <sid>, <kind>]
        let parts = url.pathComponents
        guard parts.count >= 4, parts[1] == "hls" else { return nil }
        let sidStr = parts[2]
        guard let sid = UUID(uuidString: sidStr) else { return nil }
        let kind = parts[3]
        let comps = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard let uParam = comps?.queryItems?.first(where: { $0.name == "u" })?.value
        else { return nil }
        guard let decoded = HLSManifest.decodeBase64URL(uParam),
              let upstream = URL(string: decoded)
        else { return nil }
        switch kind {
        case "master":  return .master(sessionID: sid, upstreamURL: upstream)
        case "v":       return .variant(sessionID: sid, upstreamURL: upstream)
        case "s":       return .segment(sessionID: sid, upstreamURL: upstream)
        default:        return nil
        }
    }

    // MARK: - Session lifecycle

    /// Find or create a session for the given ID + master URL.
    /// `lastTouchedAt` updates on every lookup so prune-by-age works.
    public func session(
        for id: UUID,
        masterURL: URL,
        ringCapacity: Int64 = 256 * 1024 * 1024
    ) -> Session {
        if let existing = sessions[id] {
            var updated = existing
            updated.lastTouchedAt = Date()
            sessions[id] = updated
            return updated
        }
        let fresh = Session(
            id: id,
            masterURL: masterURL,
            ringBuffer: HLSRingBuffer(capacity: ringCapacity),
            lastTouchedAt: Date()
        )
        sessions[id] = fresh
        return fresh
    }

    /// Drop sessions whose `lastTouchedAt` is older than `cutoff`.
    /// Caller should call this periodically (every 5 minutes) to
    /// reclaim memory from abandoned playbacks.
    public func prune(olderThan cutoff: Date) {
        sessions = sessions.filter { _, s in s.lastTouchedAt >= cutoff }
    }

    // MARK: - Upstream fetch + rewrite

    /// Fetch the upstream playlist body.  `URLSession` with no proxy
    /// override — the upstream fetch goes out the user's normal
    /// network path.  We don't need bonded multi-interface here;
    /// playlist fetches are tiny.
    static func fetchUpstream(_ url: URL, session: URLSession = .shared) async -> Data? {
        var req = URLRequest(url: url)
        req.timeoutInterval = 10
        guard let (data, resp) = try? await session.data(for: req),
              let http = resp as? HTTPURLResponse,
              http.statusCode < 400
        else { return nil }
        return data
    }

    /// Handle a `/master` route: fetch upstream, rewrite variant URIs
    /// to point at `/v` proxy paths, return rewritten body.  DRM
    /// passes through unchanged.
    public func handleMaster(
        sessionID: UUID,
        upstream: URL,
        proxyBase: URL
    ) async -> (body: Data, contentType: String) {
        _ = self.session(for: sessionID, masterURL: upstream)
        guard let raw = await Self.fetchUpstream(upstream),
              let body = String(data: raw, encoding: .utf8)
        else {
            return (Data(), "application/vnd.apple.mpegurl")
        }
        if HLSManifest.hasDRM(body) {
            return (raw, "application/vnd.apple.mpegurl")
        }
        guard case .master(let pl) = HLSManifest.parse(body) else {
            return (raw, "application/vnd.apple.mpegurl")
        }
        let rewritten = HLSManifest.rewriteMasterURIs(
            body,
            variants: pl.variants,
            baseURL: upstream,
            proxyBase: proxyBase,
            sessionID: sessionID
        )
        return (Data(rewritten.utf8), "application/vnd.apple.mpegurl")
    }

    /// Handle a `/v` route: fetch upstream variant playlist, rewrite
    /// segment URIs to point at `/s` proxy paths, kick off pre-fetch
    /// for the first N segments, return rewritten body.
    public func handleVariant(
        sessionID: UUID,
        upstream: URL,
        proxyBase: URL,
        fetchSegment: @escaping @Sendable (URL) async -> Data?
    ) async -> (body: Data, contentType: String) {
        var sess: Session
        if let existing = sessions[sessionID] {
            sess = existing
        } else {
            // Caller didn't initialize via /master first — be permissive
            // and create a fresh session keyed off the variant URL.
            sess = self.session(for: sessionID, masterURL: upstream)
        }
        guard let raw = await Self.fetchUpstream(upstream),
              let body = String(data: raw, encoding: .utf8)
        else {
            return (Data(), "application/vnd.apple.mpegurl")
        }
        if HLSManifest.hasDRM(body) {
            return (raw, "application/vnd.apple.mpegurl")
        }
        guard case .media(let pl) = HLSManifest.parse(body) else {
            return (raw, "application/vnd.apple.mpegurl")
        }
        let rewritten = HLSManifest.rewriteMediaURIs(
            body,
            segments: pl.segments,
            baseURL: upstream,
            proxyBase: proxyBase,
            sessionID: sessionID
        )
        // Kick off pre-fetch of first N segments — fire-and-forget.
        let prefetch = pl.segments.prefix(prefetchDepth)
        for seg in prefetch {
            let absURL = HLSManifest.absoluteURL(forRelative: seg.uri, baseURL: upstream)
            if !sess.ringBuffer.contains(absURL),
               !pendingFetches.contains(absURL) {
                pendingFetches.insert(absURL)
                Task { [weak self] in
                    let data = await fetchSegment(absURL)
                    await MainActor.run {
                        guard let self else { return }
                        self.pendingFetches.remove(absURL)
                        if let data, var session = self.sessions[sessionID] {
                            session.ringBuffer.insert(url: absURL, data: data)
                            session.lastTouchedAt = Date()
                            self.sessions[sessionID] = session
                        }
                    }
                }
            }
        }
        return (Data(rewritten.utf8), "application/vnd.apple.mpegurl")
    }

    /// Handle a `/s` (segment) route: serve from the ring buffer,
    /// or fetch on-demand if not pre-fetched yet.  After serving,
    /// no automatic pre-fetch chain — the variant playlist's
    /// pre-fetch already covers the first N segments, and the
    /// player's segment GETs are dense enough that on-demand
    /// + ring-buffer-LRU keeps up.
    public func handleSegment(
        sessionID: UUID,
        upstream: URL,
        fetchSegment: @escaping @Sendable (URL) async -> Data?
    ) async -> (body: Data, contentType: String) {
        // Mutate the session in-place: get() touches LRU.
        if var sess = sessions[sessionID],
           let cached = sess.ringBuffer.get(upstream) {
            sess.lastTouchedAt = Date()
            sessions[sessionID] = sess
            return (cached, segmentContentType(for: upstream))
        }
        // Cache miss — fetch on-demand and insert.
        guard let data = await fetchSegment(upstream) else {
            return (Data(), segmentContentType(for: upstream))
        }
        if var sess = sessions[sessionID] {
            sess.ringBuffer.insert(url: upstream, data: data)
            sess.lastTouchedAt = Date()
            sessions[sessionID] = sess
        }
        return (data, segmentContentType(for: upstream))
    }

    /// Best-effort Content-Type inference from the segment's
    /// extension.  HLS players don't strictly require this — they
    /// trust the manifest's hints — but we set it so the
    /// browser's NetworkInspector shows sensible types.
    func segmentContentType(for url: URL) -> String {
        let path = url.path.lowercased()
        if path.hasSuffix(".ts")  { return "video/mp2t" }
        if path.hasSuffix(".m4s") { return "video/iso.segment" }
        if path.hasSuffix(".mp4") { return "video/mp4" }
        if path.hasSuffix(".aac") { return "audio/aac" }
        if path.hasSuffix(".vtt") { return "text/vtt" }
        return "application/octet-stream"
    }
}
