import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// SwarmCoordinator is the seeder-side state machine for v1.9 LAN
// peer-cache.  It holds an in-memory registry of active swarms (one
// per in-flight download), serves chunk bytes from the seeder's
// local on-disk staging, and accepts contribution offers from peers.
//
// Trust boundary: every swarm RPC requires the same fleet-token
// query-string auth as the existing FleetCoordinator REST routes.
// LAN-only enforcement is inherited from FleetCoordinator's binding
// (RFC1918 / link-local interfaces; rejects public-address peers).
//
// No code execution on incoming bytes — the coordinator only stores
// chunk metadata + serves chunk ranges from already-on-disk files.
// =====================================================================

/// v1.9: in-memory state machine for an active LAN-swarm seeder.
///
/// One `SwarmCoordinator` lives per Mac and tracks every in-flight
/// download Splynek has registered as swarm-able.  Peers (other
/// Splynek instances on the LAN, paired via the fleet token) can:
///
///   - GET  /splynek/v1/swarm/{job}/manifest      — pull the chunk list
///   - GET  /splynek/v1/swarm/{job}/chunks/{n}    — pull chunk N
///   - POST /splynek/v1/swarm/{job}/contribute    — claim chunks to fetch
///   - POST /splynek/v1/swarm/{job}/leave         — clean exit
///
/// The seeder also broadcasts `Announce` records via Bonjour TXT
/// records (driven by `FleetCoordinator`); the `register(...)` /
/// `unregister(...)` calls below are how the VM tells the
/// coordinator a job started / finished.
///
/// **What this does NOT do (yet):**
///   - Bonjour announce/discover wiring — lives in `FleetCoordinator`
///   - Participant side (peer that joins someone else's swarm) —
///     comes in a v1.9.x follow-up
///   - Chunk-store on-disk layout — currently re-reads the in-progress
///     download file; v1.9.x adds a content-addressed cache so
///     completed downloads stay swarm-able after the job ends.
final class SwarmCoordinator: @unchecked Sendable {

    /// Bonjour-paired token used to authenticate every swarm RPC.
    /// Same string the rest of the fleet REST API uses.
    private let token: String

    /// Active swarms, keyed by jobID.  Mutations go through `lock`.
    private var states: [UUID: FleetChunkSwarm.State] = [:]
    private let lock = NSLock()

    /// Filesystem URL the coordinator reads chunk bytes from.  The
    /// caller (typically the VM via `FleetCoordinator.setSwarm
    /// PayloadResolver`) supplies this so the coordinator doesn't
    /// need to know about output-directory resolution — that lives
    /// in the download engine.  Mutable so the VM can inject a
    /// closure that captures `[weak self]` post-init (the closure
    /// can't form a reference to `self` from inside `init()`).
    private var payloadResolver: @Sendable (UUID) -> URL?
    private let payloadResolverLock = NSLock()

    /// v1.9.2: completed-download cache.  When the active-job
    /// resolver returns nil (because the download already finished
    /// and the job rolled out of activeJobs), the chunk-fetch
    /// handler falls back to the content cache, looking up the
    /// chunk's parent file by the swarm state's `contentDigest`.
    /// Off by default — the VM enables it by handing in a non-
    /// empty cache.  See `SwarmContentCache.swift`.
    private(set) var contentCache: SwarmContentCache?

    /// Map of registered `jobID` → publisher's content digest.  Set
    /// by `register(...)` and used by the chunk-fetch fallback to
    /// look the file up in the cache after the active-job resolver
    /// misses.  Kept under `lock` for the same reasons as `states`.
    private var contentDigestByJob: [UUID: String] = [:]

    init(
        token: String,
        payloadResolver: @escaping @Sendable (UUID) -> URL?
    ) {
        self.token = token
        self.payloadResolver = payloadResolver
    }

    /// Replace the payload resolver.  v1.9.1: the VM calls this once
    /// at startup with a closure that maps jobID → in-progress
    /// outputURL via `activeJobs.first(where:).outputURL`.  Until
    /// then the resolver returns nil and chunk fetches surface 500
    /// "Could not open job payload."
    func setPayloadResolver(_ resolver: @escaping @Sendable (UUID) -> URL?) {
        payloadResolverLock.lock()
        payloadResolver = resolver
        payloadResolverLock.unlock()
    }

    /// v1.9.2: enable post-completion chunk serving via the content
    /// cache.  Called once at startup with the VM's shared cache
    /// instance — chunk fetches against jobs that finished mid-
    /// flight will fall back to the cache instead of 500ing.
    func setContentCache(_ cache: SwarmContentCache) {
        lock.lock()
        contentCache = cache
        lock.unlock()
    }

    /// Snapshot the resolver under lock — the chunk-fetch handler
    /// captures the closure once per request to avoid holding the
    /// lock across the I/O.
    private func currentResolver() -> @Sendable (UUID) -> URL? {
        payloadResolverLock.lock()
        defer { payloadResolverLock.unlock() }
        return payloadResolver
    }

    // MARK: - State management

    /// Called by the VM when a download starts swarm-mode.  Builds
    /// the chunk manifest from the supplied chunk-list and pre-
    /// populates `seederCompleted` with whatever chunks are already
    /// on disk.
    func register(
        jobID: UUID,
        chunks: [FleetChunkSwarm.ChunkRef],
        chunkSize: Int64,
        seederCompleted: Set<Int>,
        contentDigest: String? = nil
    ) {
        let manifest = FleetChunkSwarm.Manifest(
            protocolVersion: FleetChunkSwarm.protocolVersion,
            jobID: jobID,
            chunkSize: chunkSize,
            chunks: chunks,
            seederCompleted: seederCompleted
        )
        let state = FleetChunkSwarm.State(
            jobID: jobID,
            manifest: manifest,
            contributions: [:],
            peerHoldings: [:]
        )
        lock.lock()
        states[jobID] = state
        if let digest = contentDigest, !digest.isEmpty {
            contentDigestByJob[jobID] = digest.lowercased()
        }
        lock.unlock()
    }

    /// Update the seeder's "I have these chunks" set as the seeder
    /// itself completes pulls from the WAN.  Peers polling the
    /// manifest endpoint see freshly-completed chunks immediately.
    func markSeederCompleted(jobID: UUID, chunkIndex: Int) {
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[jobID] else { return }
        var newSet = state.manifest.seederCompleted
        newSet.insert(chunkIndex)
        let bumped = FleetChunkSwarm.Manifest(
            protocolVersion: state.manifest.protocolVersion,
            jobID: state.manifest.jobID,
            chunkSize: state.manifest.chunkSize,
            chunks: state.manifest.chunks,
            seederCompleted: newSet
        )
        state = FleetChunkSwarm.State(
            jobID: state.jobID,
            manifest: bumped,
            contributions: state.contributions,
            peerHoldings: state.peerHoldings
        )
        states[jobID] = state
    }

    /// Called when the job finishes / cancels / fails.  Removes the
    /// swarm so subsequent peer requests get 404.
    func unregister(jobID: UUID) {
        lock.lock()
        states.removeValue(forKey: jobID)
        lock.unlock()
    }

    /// Snapshot — used by the FleetView UI to surface "this Mac
    /// is swarming N jobs" + "M peers contributing".
    func snapshot() -> [FleetChunkSwarm.State] {
        lock.lock()
        defer { lock.unlock() }
        return Array(states.values)
    }

    // MARK: - REST handlers

    /// Top-level dispatch for `/splynek/v1/swarm/...` paths.  Returns
    /// the HTTP response body bytes the FleetCoordinator should write
    /// out, plus the wire status line.  Pure: testable without a
    /// network listener.
    func handle(
        path: String,
        method: String,
        body: Data,
        token presentedToken: String
    ) -> Response {
        guard presentedToken == token else {
            return .unauthorized
        }
        // Strip query string, then walk the path components.
        let cleanPath = path.split(separator: "?").first.map(String.init) ?? path
        let prefix = "/splynek/v1/swarm/"
        guard cleanPath.hasPrefix(prefix) else { return .notFound }
        let suffix = String(cleanPath.dropFirst(prefix.count))
        let parts = suffix.split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)

        // Routes:
        //   announce                    — POST  (broadcast, no jobID)
        //   {jobID}/manifest            — GET
        //   {jobID}/chunks/{n}          — GET
        //   {jobID}/contribute          — POST
        //   {jobID}/leave               — POST
        switch parts.first {
        case "announce":
            return handleAnnounce(method: method, body: body)
        default:
            guard parts.count >= 2,
                  let jobID = UUID(uuidString: parts[0])
            else { return .notFound }
            switch parts[1] {
            case "manifest":
                return handleManifest(method: method, jobID: jobID)
            case "chunks":
                guard parts.count == 3, let n = Int(parts[2]) else { return .notFound }
                return handleChunkFetch(method: method, jobID: jobID, chunkIndex: n)
            case "contribute":
                return handleContribute(method: method, jobID: jobID, body: body)
            case "leave":
                return handleLeave(method: method, jobID: jobID, body: body)
            default:
                return .notFound
            }
        }
    }

    // MARK: - Per-verb handlers (file-private; exposed for tests)

    func handleAnnounce(method: String, body: Data) -> Response {
        guard method == "POST" else { return .methodNotAllowed }
        // For now Announce is a broadcast (no state mutation here);
        // FleetCoordinator's Bonjour TXT integration calls register(...)
        // separately.  We still validate the body shape so peers get
        // a clean 400 on garbage input.
        guard let _ = try? JSONDecoder().decode(FleetChunkSwarm.Announce.self, from: body)
        else { return .badRequest("Announce body must decode as FleetChunkSwarm.Announce.") }
        return .ok(Data("{\"acknowledged\":true}".utf8), contentType: "application/json")
    }

    func handleManifest(method: String, jobID: UUID) -> Response {
        guard method == "GET" else { return .methodNotAllowed }
        lock.lock()
        let state = states[jobID]
        lock.unlock()
        guard let state = state else { return .notFound }
        guard let body = try? JSONEncoder().encode(state.manifest)
        else { return .internalError("Could not encode manifest.") }
        return .ok(body, contentType: "application/json")
    }

    func handleChunkFetch(method: String, jobID: UUID, chunkIndex: Int) -> Response {
        guard method == "GET" else { return .methodNotAllowed }
        lock.lock()
        let state = states[jobID]
        lock.unlock()
        guard let state = state else { return .notFound }
        guard chunkIndex >= 0, chunkIndex < state.manifest.chunks.count else {
            return .notFound
        }
        // Refuse to serve chunks the seeder hasn't finished pulling
        // — peers should pick a chunk that's `seederCompleted`.
        // Returning 404 here keeps the wire contract simple
        // (peer retries against another seeder or waits).
        guard state.manifest.seederCompleted.contains(chunkIndex) else {
            return .notFound
        }
        let chunk = state.manifest.chunks[chunkIndex]

        // v1.9.2: try the active-job resolver first, then fall back
        // to the content cache for jobs that already completed but
        // whose file is still on disk.
        let resolver = currentResolver()
        var payloadURL: URL? = resolver(jobID)
        if payloadURL == nil {
            lock.lock()
            let digest = contentDigestByJob[jobID]
            let cache = contentCache
            lock.unlock()
            if let digest = digest, let cache = cache {
                payloadURL = cache.url(forDigest: digest)
            }
        }

        guard let payloadURL,
              let handle = try? FileHandle(forReadingFrom: payloadURL) else {
            return .internalError("Could not open job payload for chunk-serving.")
        }
        defer { try? handle.close() }
        do {
            try handle.seek(toOffset: UInt64(chunk.offset))
            let bytes = try handle.read(upToCount: Int(chunk.length)) ?? Data()
            return .ok(bytes, contentType: "application/octet-stream")
        } catch {
            return .internalError("Read error: \(error.localizedDescription)")
        }
    }

    func handleContribute(method: String, jobID: UUID, body: Data) -> Response {
        guard method == "POST" else { return .methodNotAllowed }
        guard let offer = try? JSONDecoder().decode(
            FleetChunkSwarm.ContributionOffer.self, from: body
        ) else {
            return .badRequest("Body must decode as FleetChunkSwarm.ContributionOffer.")
        }
        guard offer.jobID == jobID else {
            return .badRequest("Offer's jobID doesn't match the URL's jobID.")
        }
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[jobID] else { return .notFound }
        state.contributions[offer.peerToken, default: []].formUnion(offer.chunks)
        states[jobID] = state
        return .ok(Data("{\"accepted\":true}".utf8), contentType: "application/json")
    }

    func handleLeave(method: String, jobID: UUID, body: Data) -> Response {
        guard method == "POST" else { return .methodNotAllowed }
        // Body shape: `{"peerToken": "..."}` — drop the peer's
        // claimed chunks back into the seeder's own scheduling pool.
        struct Leave: Decodable { let peerToken: String }
        guard let leave = try? JSONDecoder().decode(Leave.self, from: body) else {
            return .badRequest("Leave body must include peerToken.")
        }
        lock.lock()
        defer { lock.unlock() }
        guard var state = states[jobID] else { return .notFound }
        state.contributions.removeValue(forKey: leave.peerToken)
        state.peerHoldings.removeValue(forKey: leave.peerToken)
        states[jobID] = state
        return .ok(Data("{\"acknowledged\":true}".utf8), contentType: "application/json")
    }

    // MARK: - Wire response

    /// Tagged HTTP response.  FleetCoordinator's existing `fleetSend`
    /// helper turns this into a wire-formatted response.
    enum Response: Sendable {
        case ok(Data, contentType: String)
        case notFound
        case unauthorized
        case methodNotAllowed
        case badRequest(String)
        case internalError(String)

        /// The HTTP status line for this response.
        var statusLine: String {
            switch self {
            case .ok:                return "HTTP/1.1 200 OK"
            case .notFound:          return "HTTP/1.1 404 Not Found"
            case .unauthorized:      return "HTTP/1.1 401 Unauthorized"
            case .methodNotAllowed:  return "HTTP/1.1 405 Method Not Allowed"
            case .badRequest:        return "HTTP/1.1 400 Bad Request"
            case .internalError:     return "HTTP/1.1 500 Internal Server Error"
            }
        }

        /// The body bytes (empty for non-OK).  For .badRequest /
        /// .internalError we surface the message as text/plain so a
        /// curl peer can read it.
        var body: Data {
            switch self {
            case .ok(let d, _):                return d
            case .badRequest(let m):           return Data(m.utf8)
            case .internalError(let m):        return Data(m.utf8)
            case .notFound, .unauthorized,
                 .methodNotAllowed:            return Data()
            }
        }

        var contentType: String {
            switch self {
            case .ok(_, let t):                return t
            case .badRequest, .internalError:  return "text/plain; charset=utf-8"
            default:                           return "text/plain"
            }
        }
    }
}
