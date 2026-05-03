import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// SwarmAnnouncementObserver issues GET requests to LAN peers'
// `/splynek/v1/swarm/list?t=<token>` endpoint and parses the JSON
// response through `Codable` Swift structs.  No code is downloaded
// or executed; the observer only learns *which jobs a peer has
// available* and surfaces that to the VM via a callback.  The
// decision to actually join a swarm + pull bytes lives one layer up
// (in the VM, gated by content-digest matching against a local
// in-flight download).
// =====================================================================

/// v1.9.5: periodic poller that asks every fleet peer "what swarms
/// are you running?" and surfaces the answers to a callback.
///
/// **Trigger model.**  A `Timer` fires every `interval` seconds
/// (default 10 s).  At each tick the observer:
///
///   1. Snapshots the FleetCoordinator's current peer list via the
///      injected `peersProvider` closure.
///   2. Filters to peers whose TXT records advertise `swarm=1`
///      (the v1.9.5 capability flag).
///   3. For each, issues a GET to `/splynek/v1/swarm/list?t=<token>`
///      with a 5 s timeout.
///   4. Decodes the response through `{jobs: [Listing, …]}`.
///   5. Calls `onUpdate` with the merged map of `(peerUUID,
///      [Listing])`.
///
/// **Cancellation.**  `stop()` invalidates the timer.  In-flight
/// requests are short (5 s timeout) and self-terminate.
///
/// **Bounded concurrency.**  Per-tick, requests are issued
/// sequentially.  A 30-peer LAN with 5 s timeouts in worst case
/// takes 150 s per tick; in practice peers respond in <50 ms over
/// loopback / LAN.  An optimisation pass could parallelise via
/// `withTaskGroup` if anyone hits the 150 s ceiling.
///
/// **No new entitlements.**  Uses `URLSession.shared` for HTTP over
/// LAN, identical to the existing fleet REST plumbing.
final class SwarmAnnouncementObserver: @unchecked Sendable {

    /// Closure providing the current list of swarm-capable peers.
    /// Injected so tests can drop in a fixture and so the observer
    /// doesn't form a back-edge dependency on FleetCoordinator.
    typealias PeersProvider = @Sendable () -> [PeerInfo]

    /// One peer in the snapshot.  Lighter than `FleetPeer` because
    /// the observer doesn't need the full Bonjour endpoint shape —
    /// just the URL prefix + auth token.
    struct PeerInfo: Sendable, Hashable {
        let uuid: String
        let name: String
        let baseURL: URL
        let token: String
    }

    /// Output emitted at each tick.  Map keyed by peerUUID so the
    /// VM can correlate against the existing fleet UI.
    typealias Update = [String: [FleetChunkSwarm.Listing]]

    private let interval: TimeInterval
    private let peersProvider: PeersProvider
    private let onUpdate: @Sendable (Update) -> Void
    private let session: URLSession
    private var timer: DispatchSourceTimer?
    private var task: Task<Void, Never>?
    private let queue = DispatchQueue(label: "app.splynek.SwarmAnnouncementObserver")

    init(
        interval: TimeInterval = 10,
        peersProvider: @escaping PeersProvider,
        onUpdate: @escaping @Sendable (Update) -> Void,
        session: URLSession = .shared
    ) {
        self.interval = max(2, interval)  // sanity floor
        self.peersProvider = peersProvider
        self.onUpdate = onUpdate
        self.session = session
    }

    deinit { stop() }

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in self?.tick() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        task?.cancel()
        task = nil
    }

    /// Run a single poll pass on demand (e.g. from a UI refresh
    /// button or a "test connection" check).  Awaitable so callers
    /// can chain a UI update on completion.
    @discardableResult
    func runOnce() async -> Update {
        let peers = peersProvider()
        let update = await fetchAll(peers: peers)
        onUpdate(update)
        return update
    }

    // MARK: - Internals

    private func tick() {
        task?.cancel()
        task = Task { [weak self] in
            guard let self else { return }
            _ = await self.runOnce()
        }
    }

    /// Fetch every peer's swarm list, sequentially.  Per-peer errors
    /// drop the peer from the result without aborting the pass.
    private func fetchAll(peers: [PeerInfo]) async -> Update {
        var out: Update = [:]
        for peer in peers {
            if Task.isCancelled { break }
            if let listings = try? await fetch(peer: peer) {
                out[peer.uuid] = listings
            }
        }
        return out
    }

    /// One HTTP GET against `/splynek/v1/swarm/list?t=<token>`.
    /// Times out at 5 s.  Throws on transport failure / non-200 /
    /// decode failure — caller treats throw as "this peer has no
    /// swarms right now" (semantically equivalent for the VM).
    func fetch(peer: PeerInfo) async throws -> [FleetChunkSwarm.Listing] {
        var components = URLComponents(
            url: peer.baseURL, resolvingAgainstBaseURL: false
        ) ?? URLComponents()
        components.path = "/splynek/v1/swarm/list"
        components.queryItems = [URLQueryItem(name: "t", value: peer.token)]
        guard let url = components.url else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }
        struct Envelope: Decodable {
            let jobs: [FleetChunkSwarm.Listing]
        }
        let envelope = try JSONDecoder().decode(Envelope.self, from: data)
        return envelope.jobs
    }
}
