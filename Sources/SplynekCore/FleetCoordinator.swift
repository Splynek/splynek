import Foundation
import Network
import SwiftUI
import CryptoKit

/// Bonjour-advertised per-device fleet orchestration.
///
/// Each Splynek install on a LAN advertises itself via
/// `_splynek-fleet._tcp` with a TXT record carrying a stable device UUID +
/// the local HTTP port it serves on. The coordinator browses the same
/// service so every Splynek sees every other Splynek.
///
/// Split of responsibility vs. LANPeerAdvertiser (which is per-file):
///   - LANPeer exists per *completed* file and advertises a content hash.
///     Peers looking for that specific hash find it.
///   - Fleet exists once per *device* and advertises the device. Peers
///     then query `/splynek/v1/status` to learn what the device has
///     in flight + what it has completed — a smarter, unified directory
///     that supports cooperative downloads, not just finished-file reuse.
///
/// HTTP endpoints the coordinator serves on its local port:
///   - `GET  /splynek/v1/status`  → JSON of device + active + completed
///   - `GET  /splynek/v1/fetch?url=<percent-encoded>` →
///       Range GET; serves bytes from the matching active/completed
///       output file. Requests for ranges whose underlying 4 MiB chunks
///       aren't yet flushed return `416 Range Not Satisfiable`; the
///       downstream Splynek's lane picks a different mirror and retries.
///
/// Security posture (matches LANPeer):
///   - No authentication. A LAN adversary who hijacks Bonjour can serve
///     garbage. The downstream engine verifies every byte via its
///     existing SHA-256 (whole-file) or Merkle manifest (per-chunk)
///     integrity checks, so poisoning manifests as a failed integrity
///     verdict, not silent corruption. Fleet is strictly additive: an
///     adversarial peer causes retries, not wrong output.

@MainActor
public final class FleetCoordinator: ObservableObject {

    // MARK: Shared state

    /// This device's stable UUID, minted once and persisted to
    /// UserDefaults. Other Splyneks use it to identify us.
    let deviceUUID: String
    /// Human-friendly device name used in the UI + TXT record.
    let deviceName: String
    /// 16-byte random token required on every mutating endpoint. The
    /// mobile dashboard URL embeds it as a query param (QR code
    /// carries it); read endpoints expose the same data the fleet
    /// protocol already shares. Persisted to UserDefaults. **Can be
    /// regenerated** by the user from About → Security to invalidate
    /// an accidentally-shared QR.
    @Published private(set) var webToken: String
    /// HTTP port we bound to. Zero until the listener is live.
    @Published private(set) var port: UInt16 = 0
    /// Discovered peers, keyed by UUID. Keyed to dedupe mDNS flaps.
    @Published private(set) var peers: [FleetPeer] = []
    /// Active downloads on *this* device, snapshotted from the VM.
    /// The VM pushes updates via `updateLocalState(activeJobs:)`.
    @Published private(set) var local: LocalState = .empty

    /// Snapshot of local download state, exposed to fleet peers over
    /// HTTP + shown in the UI. `LocalState` is value-typed so the
    /// server task can publish it over a CheckedSendable without
    /// reaching back into the main actor.
    struct LocalState: Sendable, Codable {
        struct ActiveJob: Sendable, Codable, Hashable {
            var url: String
            var filename: String
            var outputPath: String
            var totalBytes: Int64
            var downloaded: Int64
            var chunkSize: Int64
            var completedChunks: [Int]
        }
        struct CompletedFile: Sendable, Codable, Hashable {
            var url: String
            var filename: String
            var outputPath: String
            var totalBytes: Int64
            var finishedAt: Date
            /// Content-addressed key — hex SHA-256 of the bytes on disk.
            /// Every v0.20+ completion computes this; legacy history
            /// entries may be absent (`nil`) and won't be content-
            /// addressable until re-indexed.
            var sha256: String?
        }
        var active: [ActiveJob]
        var completed: [CompletedFile]
        static let empty = LocalState(active: [], completed: [])
    }

    // MARK: Internals

    private var listener: NWListener?
    private var browser: NWBrowser?
    private let serverQueue = DispatchQueue(label: "splynek.fleet.server")
    private let stateLock = NSLock()
    private var publishedState: LocalState = .empty
    /// How long a peer can be silent before we drop it from the roster.
    private static let peerTTL: TimeInterval = 60

    init() {
        let defaults = UserDefaults.standard
        if let saved = defaults.string(forKey: "fleetDeviceUUID") {
            self.deviceUUID = saved
        } else {
            let fresh = UUID().uuidString
            defaults.set(fresh, forKey: "fleetDeviceUUID")
            self.deviceUUID = fresh
        }
        if let saved = defaults.string(forKey: "fleetWebToken"), !saved.isEmpty {
            self.webToken = saved
        } else {
            var bytes = Data(count: 16)
            _ = bytes.withUnsafeMutableBytes { buf in
                SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
            }
            let token = bytes.map { String(format: "%02x", $0) }.joined()
            defaults.set(token, forKey: "fleetWebToken")
            self.webToken = token
        }
        self.deviceName = Host.current().localizedName ?? ProcessInfo.processInfo.hostName
    }

    /// Regenerate the shared secret used by the web dashboard + CLI +
    /// Raycast/Alfred. Any previously-handed-out QR code is
    /// immediately invalid. Writes both to UserDefaults and the fleet
    /// descriptor file so every consumer picks up the new token on
    /// next request.
    public func regenerateWebToken() {
        var bytes = Data(count: 16)
        _ = bytes.withUnsafeMutableBytes { buf in
            SecRandomCopyBytes(kSecRandomDefault, 16, buf.baseAddress!)
        }
        let token = bytes.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(token, forKey: "fleetWebToken")
        self.webToken = token
        persistDescriptor()
    }

    // MARK: Privacy mode

    /// When true, fleet peers on the LAN see an empty `/status` and
    /// can't discover what this Mac has downloaded / is downloading.
    /// The web dashboard served locally is still fully populated —
    /// this only gates what other hosts on the network can read.
    @Published public var privacyMode: Bool = UserDefaults.standard.bool(forKey: "fleetPrivacyMode") {
        didSet {
            UserDefaults.standard.set(privacyMode, forKey: "fleetPrivacyMode")
        }
    }

    /// When true, the fleet HTTP listener binds only to 127.0.0.1
    /// instead of all interfaces. The web dashboard + API work only
    /// from this machine; LAN peers cannot reach them. Takes effect
    /// at next launch; the setting is surfaced in About → Security.
    @Published public var loopbackOnly: Bool = UserDefaults.standard.bool(forKey: "fleetLoopbackOnly") {
        didSet {
            UserDefaults.standard.set(loopbackOnly, forKey: "fleetLoopbackOnly")
        }
    }

    // MARK: Rate limiting

    /// Sliding-window rate limiter per remote address. Prevents a
    /// hostile LAN peer from opening thousands of sockets to starve
    /// the fleet coordinator. Cap: 60 requests per 10-second window
    /// per address. Requests past the cap get a 429.
    // Rate-limiter state: serialised by the NSLock, not by @MainActor,
    // so the accept path can rate-check off the main thread. The
    // `nonisolated(unsafe)` annotation tells Swift's actor-isolation
    // checker that we've taken responsibility for concurrency here.
    private let rateLock = NSLock()
    nonisolated(unsafe) private var rateHits: [String: [Date]] = [:]
    private static let rateWindow: TimeInterval = 10
    private static let rateMaxPerWindow = 60

    /// Returns true iff the request should be served; false iff we
    /// should respond with 429. Thread-safe.
    fileprivate nonisolated func allowRequest(from remote: String?) -> Bool {
        guard let remote else { return true }
        rateLock.lock(); defer { rateLock.unlock() }
        let now = Date()
        let cutoff = now.addingTimeInterval(-Self.rateWindow)
        var hits = (rateHits[remote] ?? []).filter { $0 > cutoff }
        if hits.count >= Self.rateMaxPerWindow {
            rateHits[remote] = hits     // keep the compacted list
            return false
        }
        hits.append(now)
        rateHits[remote] = hits
        // Opportunistic GC — prune stale entries occasionally to keep
        // the dict from growing without bound.
        if rateHits.count > 256 {
            for (k, v) in rateHits where v.allSatisfy({ $0 < cutoff }) {
                rateHits.removeValue(forKey: k)
            }
        }
        return true
    }

    /// Called by the web UI's submit endpoint. Routes through the VM
    /// exactly the way the `splynek://` scheme + drag-drop + menu-bar
    /// popover do — one ingest contract for every surface.
    var onWebIngest: ((_ action: String, _ url: String) -> Void)?
    /// Called when a token-authorised client POSTs `/api/cancel`.
    /// Binds to `vm.cancelAll()` — we keep the closure shape simple so
    /// the coordinator doesn't need to see the VM type.
    var onCancelAll: (() -> Void)?

    /// LAN-visible base URL a mobile device can open to reach the web
    /// dashboard. Uses the first non-loopback IPv4 address the OS has
    /// assigned — good enough for the same-Wi-Fi handoff case which is
    /// 99% of the use. Returns `nil` until the listener binds.
    func webDashboardURL() -> URL? {
        guard port > 0 else { return nil }
        let host = Self.firstLANAddress() ?? "localhost"
        return URL(string: "http://\(host):\(port)/splynek/v1/ui?t=\(webToken)")
    }

    /// First non-loopback IPv4 interface address. Enough for the QR code
    /// + AboutView pill — we don't need a full multi-address panel.
    private static func firstLANAddress() -> String? {
        var ifap: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifap) == 0, let first = ifap else { return nil }
        defer { freeifaddrs(ifap) }
        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        var candidates: [String] = []
        while let cur = ptr {
            let flags = Int32(cur.pointee.ifa_flags)
            let addr = cur.pointee.ifa_addr
            if (flags & IFF_UP) != 0, (flags & IFF_LOOPBACK) == 0,
               let addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var buf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(
                    addr, socklen_t(addr.pointee.sa_len),
                    &buf, socklen_t(buf.count),
                    nil, 0, NI_NUMERICHOST
                ) == 0 {
                    candidates.append(String(cString: buf))
                }
            }
            ptr = cur.pointee.ifa_next
        }
        // Prefer 10.*/172.16–31.*/192.168.* (RFC 1918) so the QR code
        // carries an address that actually works on the local network,
        // not, say, a VPN-assigned public IP.
        return candidates.first(where: isPrivateIPv4) ?? candidates.first
    }

    private static func isPrivateIPv4(_ ip: String) -> Bool {
        let parts = ip.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 192, parts[1] == 168 { return true }
        if parts[0] == 172, (16...31).contains(parts[1]) { return true }
        return false
    }

    /// Start the Bonjour advertiser, the local HTTP server, and the
    /// browser. Idempotent — safe to call from `restoreSession()`.
    func start() {
        guard listener == nil else { return }
        do {
            // Loopback-only mode: the user opted into running the
            // dashboard + fleet protocol strictly on-device. No LAN
            // peer (hostile or friendly) can reach us. Setting
            // `requiredLocalEndpoint` to 127.0.0.1 makes NWListener
            // bind there; Bonjour advertisement becomes a no-op.
            let params: NWParameters = .tcp
            if loopbackOnly {
                params.requiredLocalEndpoint = NWEndpoint.hostPort(
                    host: "127.0.0.1",
                    port: .any
                )
            }
            let listener = try NWListener(using: params)
            self.listener = listener
            listener.newConnectionHandler = { [weak self] conn in
                guard let self else { conn.cancel(); return }
                Task { @MainActor in
                    self.accept(conn)
                }
            }
            listener.stateUpdateHandler = { [weak self] state in
                guard case .ready = state else { return }
                // Capture self STRONGLY in the Task — a nested [weak
                // self] race lets the optimizer in release builds drop
                // the ready handler's Task before it runs. Strong
                // capture is fine: self is retained by the VM which
                // lives for the app's lifetime, so "leaks" are a
                // non-issue.
                guard let coordinator = self else { return }
                Task { @MainActor in
                    guard let port = listener.port?.rawValue else { return }
                    coordinator.port = UInt16(port)
                    coordinator.advertiseBonjour(port: UInt16(port))
                    coordinator.persistDescriptor()
                }
            }
            listener.start(queue: serverQueue)
            startBrowser()
        } catch {
            // Fleet failure is silent — the app still works standalone.
            return
        }
    }

    func stop() {
        listener?.cancel(); listener = nil
        browser?.cancel(); browser = nil
        port = 0
        peers = []
    }

    /// Replace the locally-advertised state. Called from the VM whenever
    /// activeJobs or history mutates.
    func updateLocalState(_ state: LocalState) {
        self.local = state
        stateLock.lock()
        publishedState = state
        stateLock.unlock()
        // Re-persist the descriptor on every VM state publish so
        // auxiliary surfaces (CLI, Raycast, Alfred) always see a
        // current `fleet.json` — robust to any race between listener
        // .ready and the first descriptor write. We write even when
        // port is 0 (the CLI will see port=0 and retry) so the file
        // exists as early as possible.
        persistDescriptor()
    }

    /// Return any fleet-mirror URLs that claim to be serving `url`. Draws
    /// from both peers who have the URL *completed* (gigabit full serve)
    /// and peers who are *actively* downloading the same URL and have at
    /// least one chunk on disk (cooperative partial-chunk trading — the
    /// engine survives 416s on a per-chunk basis now, so it's safe to
    /// include partial mirrors here).
    func mirrors(for url: URL) -> [URL] {
        let match = url.absoluteString
        var out: [URL] = []
        for p in peers {
            let completed = p.state.completed.contains { $0.url == match }
            let activePartial = p.state.active.contains {
                $0.url == match && !$0.completedChunks.isEmpty
            }
            if (completed || activePartial),
               let resolved = p.fetchURL(original: url) {
                out.append(resolved)
            }
        }
        return out
    }

    /// Return fleet-mirror URLs that can serve the bytes matching a known
    /// content hash. Lets the VM's `start()` short-circuit a download
    /// whose integrity field names a SHA-256 the fleet already has, even
    /// if the origin URL differs (mirror change, CDN swap, etc.).
    func contentMirrors(for sha256: String) -> [URL] {
        let want = sha256.lowercased()
        var out: [URL] = []
        for p in peers {
            let hit = p.state.completed.first { ($0.sha256 ?? "").lowercased() == want }
            if hit != nil, let host = p.host, let port = p.resolvedPort {
                if let u = URL(string: "http://\(host):\(port)/splynek/v1/content/\(want)") {
                    out.append(u)
                }
            }
        }
        return out
    }

    /// Number of distinct content-addressable files this Mac can serve
    /// (i.e. completed-with-SHA). Surfaced in the UI.
    var sharedByHashCount: Int {
        Set(local.completed.compactMap { $0.sha256?.lowercased() }).count
    }

    // MARK: Fleet descriptor (for the CLI, Raycast, Alfred, etc.)

    /// Path other Splynek-adjacent binaries (the CLI, Raycast extension,
    /// Alfred workflow) read to discover the running app's local HTTP
    /// port + submit token. Chosen to be in the standard Application
    /// Support directory so it survives across launches without
    /// polluting a config directory a normal user would care about.
    public nonisolated static var fleetDescriptorURL: URL {
        let appSupport = (try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? FileManager.default.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir, withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("fleet.json")
    }

    public struct FleetDescriptor: Codable, Sendable {
        public var port: UInt16
        public var token: String
        public var deviceName: String
        public var deviceUUID: String
        public var schemeVersion: Int = 1
    }

    private func persistDescriptor() {
        let descriptor = FleetDescriptor(
            port: port,
            token: webToken,
            deviceName: deviceName,
            deviceUUID: deviceUUID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(descriptor) {
            try? data.write(to: Self.fleetDescriptorURL, options: .atomic)
        }
    }

    // MARK: Bonjour

    private func advertiseBonjour(port: UInt16) {
        let txt: [String: String] = [
            "uuid": deviceUUID,
            "name": deviceName,
            "ver":  "0.19"
        ]
        let record = NWTXTRecord(txt)
        listener?.service = NWListener.Service(
            name: "Splynek-\(String(deviceUUID.prefix(8)))",
            type: "_splynek-fleet._tcp",
            domain: nil,
            txtRecord: record.data
        )
    }

    private func startBrowser() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let browser = NWBrowser(
            for: .bonjourWithTXTRecord(type: "_splynek-fleet._tcp", domain: nil),
            using: params
        )
        self.browser = browser
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.ingest(results: Array(results))
            }
        }
        browser.start(queue: serverQueue)
    }

    private func ingest(results: [NWBrowser.Result]) {
        var fresh: [FleetPeer] = []
        for r in results {
            guard case let .service(name, _, _, _) = r.endpoint,
                  case .bonjour(let txt) = r.metadata else { continue }
            // Skip ourselves.
            if txt["uuid"] == deviceUUID { continue }
            guard let uuid = txt["uuid"] else { continue }
            let peer = FleetPeer(
                uuid: uuid,
                name: txt["name"] ?? String(name),
                endpoint: r.endpoint,
                discoveredAt: Date(),
                state: .empty
            )
            fresh.append(peer)
        }
        // Replace peer list, preserving previously resolved host:port +
        // state to avoid blanking the UI between Bonjour flaps.
        let existing = Dictionary(
            uniqueKeysWithValues: peers.map { ($0.uuid, $0) }
        )
        self.peers = fresh.map { newPeer in
            var p = newPeer
            if let prev = existing[p.uuid] {
                p.state = prev.state
                p.host  = prev.host
                p.resolvedPort = prev.resolvedPort
                p.lastOK = prev.lastOK
            }
            return p
        }
        // For any peer that doesn't yet have a resolved ip:port, open a
        // throwaway NWConnection to the service endpoint to learn its
        // hostPort. This is cheap — one syscall + a state change.
        for peer in self.peers where peer.host == nil {
            Task { @MainActor [weak self] in
                await self?.resolve(peerUUID: peer.uuid, endpoint: peer.endpoint)
            }
        }
    }

    /// Open a short-lived NWConnection to the service endpoint just long
    /// enough to read the resolved host:port via `currentPath`. Caches
    /// the result on the peer so subsequent `/status` + range GETs use
    /// plain URLSession / URL-based calls.
    private func resolve(peerUUID: String, endpoint: NWEndpoint) async {
        let c = NWConnection(to: endpoint, using: .tcp)
        let gate = ResumeGate()
        let pair: (String, UInt16)? = await withCheckedContinuation {
            (cont: CheckedContinuation<(String, UInt16)?, Never>) in
            c.stateUpdateHandler = { state in
                switch state {
                case .ready, .waiting, .failed, .cancelled:
                    guard gate.fire() else { return }
                    let resolved: (String, UInt16)?
                    if case let .hostPort(host, port) = c.currentPath?.remoteEndpoint ?? endpoint {
                        switch host {
                        case .ipv4(let a):      resolved = (String(describing: a), port.rawValue)
                        case .ipv6(let a):      resolved = ("[\(String(describing: a))]", port.rawValue)
                        case .name(let n, _):   resolved = (n, port.rawValue)
                        @unknown default:       resolved = nil
                        }
                    } else {
                        resolved = nil
                    }
                    c.cancel()
                    cont.resume(returning: resolved)
                default: break
                }
            }
            c.start(queue: serverQueue)
            serverQueue.asyncAfter(deadline: .now() + 3) {
                if gate.fire() { c.cancel(); cont.resume(returning: nil) }
            }
        }
        guard let (host, port) = pair else { return }
        if let i = peers.firstIndex(where: { $0.uuid == peerUUID }) {
            peers[i].host = host
            peers[i].resolvedPort = port
        }
        if let refreshed = peers.first(where: { $0.uuid == peerUUID }) {
            await refresh(peer: refreshed)
        }
    }

    /// Fetch `/splynek/v1/status` from a peer and update its cached state.
    /// Non-blocking errors (peer went offline, corrupt JSON) just leave
    /// the previous state in place.
    func refresh(peer: FleetPeer) async {
        guard let url = peer.statusURL else { return }
        var req = URLRequest(url: url)
        req.timeoutInterval = 3
        guard let (data, _) = try? await URLSession.shared.data(for: req),
              let state = try? JSONDecoder().decode(LocalState.self, from: data) else {
            return
        }
        if let i = self.peers.firstIndex(where: { $0.uuid == peer.uuid }) {
            self.peers[i].state = state
            self.peers[i].lastOK = Date()
        }
    }

    /// Manual refresh triggered by the UI "refresh" button.
    func refreshAll() {
        for peer in peers {
            Task { @MainActor [weak self] in
                await self?.refresh(peer: peer)
            }
        }
    }

    // MARK: Server

    private func accept(_ conn: NWConnection) {
        conn.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state {
                // Rate-limit by remote host. A hostile LAN peer
                // opening 1000 sockets can't DoS us; they hit the
                // 429 cap after the first ~60 in a 10-second window.
                let remote = Self.remoteHostString(conn)
                if !self.allowRequest(from: remote) {
                    let head = Data(
                        ("HTTP/1.1 429 Too Many Requests\r\n" +
                         "Retry-After: 10\r\n" +
                         "Content-Length: 0\r\nConnection: close\r\n\r\n").utf8
                    )
                    conn.send(content: head, completion: .contentProcessed { _ in
                        conn.cancel()
                    })
                    return
                }
                Task { await self.serveRequest(conn) }
            } else if case .failed = state {
                conn.cancel()
            }
        }
        conn.start(queue: serverQueue)
    }

    /// Extract the remote host string from a live NWConnection.
    /// Used as a rate-limit key; loopback connections key on
    /// "127.0.0.1" regardless of port.
    nonisolated private static func remoteHostString(_ conn: NWConnection) -> String? {
        if case let .hostPort(host, _) = conn.currentPath?.remoteEndpoint
            ?? conn.endpoint {
            switch host {
            case .ipv4(let a): return "\(a)"
            case .ipv6(let a): return "\(a)"
            case .name(let n, _): return n
            @unknown default: return nil
            }
        }
        return nil
    }

    /// Read one HTTP request, dispatch to the appropriate handler.
    private func serveRequest(_ conn: NWConnection) async {
        var buffer = Data()
        let terminator = Data("\r\n\r\n".utf8)
        while buffer.range(of: terminator) == nil, buffer.count < 16 * 1024 {
            guard let piece = try? await fleetRecv(conn), !piece.isEmpty else {
                conn.cancel(); return
            }
            buffer.append(piece)
        }
        guard let end = buffer.range(of: terminator)?.upperBound,
              let header = String(data: buffer.prefix(end), encoding: .isoLatin1) else {
            conn.cancel(); return
        }
        let lines = header.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { conn.cancel(); return }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { conn.cancel(); return }
        let method = String(parts[0]).uppercased()
        let path = String(parts[1])
        var rangeHeader: String?
        var contentLength: Int = 0
        for line in lines.dropFirst() {
            let lower = line.lowercased()
            if lower.hasPrefix("range:") {
                rangeHeader = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
            } else if lower.hasPrefix("content-length:") {
                contentLength = Int(line.dropFirst("content-length:".count)
                    .trimmingCharacters(in: .whitespaces)) ?? 0
            }
        }

        // If this is a POST, pull the body bytes out of what we've read
        // (already past the header terminator) and receive any remainder.
        var body = Data()
        if method == "POST", contentLength > 0 {
            body = Data(buffer.suffix(from: end))
            while body.count < contentLength {
                guard let piece = try? await fleetRecv(conn), !piece.isEmpty else { break }
                body.append(piece)
            }
            body = body.prefix(contentLength)
        }

        if path == "/splynek/v1/status" {
            await serveStatus(conn)
        } else if path.hasPrefix("/splynek/v1/openapi") {
            await serveOpenAPI(conn)
        } else if path.hasPrefix("/splynek/v1/api/jobs") {
            await serveAPIJobs(conn)
        } else if path.hasPrefix("/splynek/v1/api/history") {
            await serveAPIHistory(conn, path: path)
        } else if path.hasPrefix("/splynek/v1/api/download") {
            await serveAPISubmit(conn, path: path, body: body, method: method, action: "download")
        } else if path.hasPrefix("/splynek/v1/api/queue") {
            await serveAPISubmit(conn, path: path, body: body, method: method, action: "queue")
        } else if path.hasPrefix("/splynek/v1/api/cancel") {
            await serveAPICancel(conn, path: path, method: method)
        } else if path.hasPrefix("/splynek/v1/fetch") {
            await serveFetch(conn, path: path, rangeHeader: rangeHeader)
        } else if path.hasPrefix("/splynek/v1/content/") {
            let hex = String(path.dropFirst("/splynek/v1/content/".count))
            let clean = hex.split(separator: "?").first.map(String.init) ?? hex
            await serveContent(conn, sha256: clean, rangeHeader: rangeHeader)
        } else if path.hasPrefix("/splynek/v1/ui/state") {
            await serveWebState(conn)
        } else if path.hasPrefix("/splynek/v1/ui/submit") {
            await serveWebSubmit(conn, path: path, body: body, method: method)
        } else if path.hasPrefix("/splynek/v1/ui") {
            await serveWebDashboard(conn)
        } else if path == "/" || path.isEmpty {
            // Courtesy redirect so http://mac:port/ on the phone just works.
            let redirect =
                "HTTP/1.1 302 Found\r\n" +
                "Location: /splynek/v1/ui?t=\(webToken)\r\n" +
                "Content-Length: 0\r\nConnection: close\r\n\r\n"
            try? await fleetSend(conn, Data(redirect.utf8))
            conn.cancel()
        } else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel()
        }
    }

    // MARK: Web UI endpoints

    private func serveWebDashboard(_ conn: NWConnection) async {
        let html = WebDashboard.html
        let data = Data(html.utf8)
        let head =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: text/html; charset=utf-8\r\n" +
            "Content-Length: \(data.count)\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        try? await fleetSend(conn, Data(head.utf8) + data)
        conn.cancel()
    }

    private func serveWebState(_ conn: NWConnection) async {
        stateLock.lock()
        let snapshot = publishedState
        stateLock.unlock()
        let dashboard = WebDashboard.State(
            device: deviceName,
            uuid: deviceUUID,
            port: port,
            peerCount: peers.count,
            active: snapshot.active,
            completed: Array(snapshot.completed.prefix(25))
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(dashboard) else {
            conn.cancel(); return
        }
        let head =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        try? await fleetSend(conn, Data(head.utf8) + body)
        conn.cancel()
    }

    /// POST /splynek/v1/ui/submit?t=<token>
    /// Body: JSON `{ "url": "...", "action": "download"|"queue" }`
    private func serveWebSubmit(
        _ conn: NWConnection, path: String, body: Data, method: String
    ) async {
        guard method == "POST" else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 405 Method Not Allowed\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        // Token check — the dashboard URL hands it back in the query
        // string; mobile clients read it from their loaded page URL
        // and echo it on submit. This is not cryptographic auth; it's
        // "you've been handed the keys by someone with physical access
        // to the Mac" — same posture as LAN Bonjour generally.
        guard let q = path.split(separator: "?").dropFirst().first else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        let presented: String = {
            for pair in q.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2, kv[0] == "t" {
                    return kv[1]
                }
            }
            return ""
        }()
        guard presented == webToken else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 401 Unauthorized\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        // Parse body.
        struct Submit: Decodable { let url: String; let action: String? }
        guard let decoded = try? JSONDecoder().decode(Submit.self, from: body),
              !decoded.url.trimmingCharacters(in: .whitespaces).isEmpty else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        let action = (decoded.action ?? "download").lowercased()
        // Hand off to the VM on the main actor via the injected closure.
        let handler = self.onWebIngest
        await MainActor.run {
            handler?(action, decoded.url)
        }
        let response = "HTTP/1.1 202 Accepted\r\nContent-Length: 0\r\nConnection: close\r\n\r\n"
        try? await fleetSend(conn, Data(response.utf8))
        conn.cancel()
    }

    private func serveContent(_ conn: NWConnection, sha256: String, rangeHeader: String?) async {
        stateLock.lock()
        let snapshot = publishedState
        stateLock.unlock()
        let want = sha256.lowercased()
        guard let match = snapshot.completed.first(where: {
            ($0.sha256 ?? "").lowercased() == want
        }) else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        let total = match.totalBytes
        var start: Int64 = 0, end: Int64 = total - 1
        if let r = rangeHeader, r.hasPrefix("bytes=") {
            let spec = String(r.dropFirst("bytes=".count))
            let parts = spec.split(separator: "-", maxSplits: 1).map(String.init)
            if parts.count >= 1, let s = Int64(parts[0]) { start = s }
            if parts.count == 2, let e = Int64(parts[1]) { end = e }
        }
        guard start >= 0, end < total, start <= end else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        let length = end - start + 1
        let head =
            "HTTP/1.1 206 Partial Content\r\n" +
            "Content-Type: application/octet-stream\r\n" +
            "Content-Length: \(length)\r\n" +
            "Content-Range: bytes \(start)-\(end)/\(total)\r\n" +
            "X-Splynek-Content-Sha256: \(want)\r\n" +
            "Connection: close\r\n\r\n"
        try? await fleetSend(conn, Data(head.utf8))
        do {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: match.outputPath))
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(start))
            var remaining = length
            while remaining > 0 {
                let take = Int(min(remaining, 64 * 1024))
                let chunk = try handle.read(upToCount: take) ?? Data()
                if chunk.isEmpty { break }
                try await fleetSend(conn, chunk)
                remaining -= Int64(chunk.count)
            }
        } catch {
            // Best effort
        }
        conn.cancel()
    }

    private func serveStatus(_ conn: NWConnection) async {
        stateLock.lock()
        var snapshot = publishedState
        stateLock.unlock()
        // Privacy mode: hide active + completed from LAN peers. The
        // fleet protocol itself is still reachable (peers still know
        // this Mac exists) but they can't enumerate what we've got.
        if privacyMode {
            snapshot = LocalState(active: [], completed: [])
        }
        guard let body = try? JSONEncoder().encode(snapshot) else {
            conn.cancel(); return
        }
        let head =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Connection: close\r\n\r\n"
        try? await fleetSend(conn, Data(head.utf8) + body)
        conn.cancel()
    }

    private func serveFetch(_ conn: NWConnection, path: String, rangeHeader: String?) async {
        // Parse ?url=<percent-encoded>
        guard let qIdx = path.firstIndex(of: "?") else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 400 Bad Request\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        let query = String(path[path.index(after: qIdx)...])
        var target: String = ""
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0] == "url" {
                target = kv[1].removingPercentEncoding ?? kv[1]
            }
        }
        // Locate matching job (prefer completed, fall back to active).
        stateLock.lock()
        let snapshot = publishedState
        stateLock.unlock()

        let outputPath: String
        let totalBytes: Int64
        let chunkSize: Int64
        let completedChunks: Set<Int>
        if let done = snapshot.completed.first(where: { $0.url == target }) {
            outputPath = done.outputPath
            totalBytes = done.totalBytes
            chunkSize = DownloadEngine.chunkBytes
            let n = Int((done.totalBytes + chunkSize - 1) / chunkSize)
            completedChunks = Set(0..<n)
        } else if let active = snapshot.active.first(where: { $0.url == target }) {
            outputPath = active.outputPath
            totalBytes = active.totalBytes
            chunkSize = active.chunkSize
            completedChunks = Set(active.completedChunks)
        } else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 404 Not Found\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }

        // Parse range header (bytes=start-end).
        var start: Int64 = 0, end: Int64 = totalBytes - 1
        if let r = rangeHeader, r.hasPrefix("bytes=") {
            let spec = String(r.dropFirst("bytes=".count))
            let parts = spec.split(separator: "-", maxSplits: 1).map(String.init)
            if parts.count >= 1, let s = Int64(parts[0]) { start = s }
            if parts.count == 2, let e = Int64(parts[1]) { end = e }
        }
        guard start >= 0, end < totalBytes, start <= end else {
            try? await fleetSend(conn,
                Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        // Every chunk the requested range touches must be completed.
        let firstChunk = Int(start / chunkSize)
        let lastChunk = Int(end / chunkSize)
        for idx in firstChunk...lastChunk {
            if !completedChunks.contains(idx) {
                try? await fleetSend(conn,
                    Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
                conn.cancel(); return
            }
        }

        // Stream.
        let length = end - start + 1
        let head =
            "HTTP/1.1 206 Partial Content\r\n" +
            "Content-Type: application/octet-stream\r\n" +
            "Content-Length: \(length)\r\n" +
            "Content-Range: bytes \(start)-\(end)/\(totalBytes)\r\n" +
            "Connection: close\r\n\r\n"
        try? await fleetSend(conn, Data(head.utf8))
        do {
            let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: outputPath))
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(start))
            var remaining = length
            while remaining > 0 {
                let take = Int(min(remaining, 64 * 1024))
                let chunk = try handle.read(upToCount: take) ?? Data()
                if chunk.isEmpty { break }
                try await fleetSend(conn, chunk)
                remaining -= Int64(chunk.count)
            }
        } catch {
            // Best effort
        }
        conn.cancel()
    }

    // MARK: Documented REST API (v0.27)

    private func serveOpenAPI(_ conn: NWConnection) async {
        let body = Data(OpenAPI.yaml.utf8)
        let head =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/yaml; charset=utf-8\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        try? await fleetSend(conn, Data(head.utf8) + body)
        conn.cancel()
    }

    private func serveAPIJobs(_ conn: NWConnection) async {
        stateLock.lock()
        let snapshot = publishedState
        stateLock.unlock()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(snapshot.active) else {
            conn.cancel(); return
        }
        try? await respondJSON(conn, body: body)
    }

    private func serveAPIHistory(_ conn: NWConnection, path: String) async {
        stateLock.lock()
        let snapshot = publishedState
        stateLock.unlock()
        let limit: Int = {
            guard let q = path.split(separator: "?").dropFirst().first else { return 25 }
            for pair in q.split(separator: "&") {
                let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
                if kv.count == 2, kv[0] == "limit", let n = Int(kv[1]) {
                    return max(1, min(500, n))
                }
            }
            return 25
        }()
        let slice = Array(snapshot.completed.prefix(limit))
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let body = try? encoder.encode(slice) else {
            conn.cancel(); return
        }
        try? await respondJSON(conn, body: body)
    }

    private func serveAPISubmit(
        _ conn: NWConnection, path: String, body: Data, method: String, action: String
    ) async {
        guard method == "POST" else {
            try? await respond(conn, status: "405 Method Not Allowed")
            return
        }
        guard tokenFromQuery(path) == webToken else {
            try? await respond(conn, status: "401 Unauthorized")
            return
        }
        struct Submit: Decodable { let url: String }
        guard let decoded = try? JSONDecoder().decode(Submit.self, from: body),
              !decoded.url.trimmingCharacters(in: .whitespaces).isEmpty else {
            try? await respond(conn, status: "400 Bad Request")
            return
        }
        let handler = self.onWebIngest
        await MainActor.run { handler?(action, decoded.url) }
        try? await respond(conn, status: "202 Accepted")
    }

    private func serveAPICancel(_ conn: NWConnection, path: String, method: String) async {
        guard method == "POST" else {
            try? await respond(conn, status: "405 Method Not Allowed"); return
        }
        guard tokenFromQuery(path) == webToken else {
            try? await respond(conn, status: "401 Unauthorized"); return
        }
        let handler = self.onCancelAll
        await MainActor.run { handler?() }
        try? await respond(conn, status: "202 Accepted")
    }

    // MARK: Response helpers

    private func respond(_ conn: NWConnection, status: String) async throws {
        let head =
            "HTTP/1.1 \(status)\r\n" +
            "Content-Length: 0\r\nConnection: close\r\n\r\n"
        try await fleetSend(conn, Data(head.utf8))
        conn.cancel()
    }

    private func respondJSON(_ conn: NWConnection, body: Data) async throws {
        let head =
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: application/json\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Cache-Control: no-store\r\n" +
            "Connection: close\r\n\r\n"
        try await fleetSend(conn, Data(head.utf8) + body)
        conn.cancel()
    }

    private func tokenFromQuery(_ path: String) -> String? {
        guard let q = path.split(separator: "?").dropFirst().first else { return nil }
        for pair in q.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2, kv[0] == "t" { return kv[1] }
        }
        return nil
    }
}

// MARK: - Fleet peer

struct FleetPeer: Identifiable, Hashable {
    let uuid: String
    let name: String
    let endpoint: NWEndpoint
    let discoveredAt: Date
    var lastOK: Date?
    var state: FleetCoordinator.LocalState
    /// Host string resolved from the Bonjour endpoint via NWConnection.
    /// `nil` until the first `resolve()` succeeds.
    var host: String?
    var resolvedPort: UInt16?

    var id: String { uuid }
    var isResolved: Bool { host != nil && (resolvedPort ?? 0) > 0 }

    func hash(into hasher: inout Hasher) { hasher.combine(uuid) }
    static func == (lhs: FleetPeer, rhs: FleetPeer) -> Bool { lhs.uuid == rhs.uuid }

    /// Peer status URL (`/splynek/v1/status`). Nil until resolved.
    var statusURL: URL? {
        guard let host, let port = resolvedPort else { return nil }
        return URL(string: "http://\(host):\(port)/splynek/v1/status")
    }

    /// Translate an original download URL into the fleet mirror URL that
    /// this peer would serve it on. Returns nil until the peer has been
    /// resolved to a real host:port.
    func fetchURL(original: URL) -> URL? {
        guard let host, let port = resolvedPort else { return nil }
        let encoded = original.absoluteString
            .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)
            ?? original.absoluteString
        return URL(string: "http://\(host):\(port)/splynek/v1/fetch?url=\(encoded)")
    }
}

// MARK: - Low-level NWConnection helpers

@inline(__always)
private func fleetRecv(_ c: NWConnection, max: Int = 64 * 1024) async throws -> Data {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
        c.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, err in
            if let e = err { cont.resume(throwing: e); return }
            cont.resume(returning: data ?? Data())
        }
    }
}

@inline(__always)
private func fleetSend(_ c: NWConnection, _ data: Data) async throws {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
        c.send(content: data, completion: .contentProcessed { err in
            if let e = err { cont.resume(throwing: e) } else { cont.resume() }
        })
    }
}
