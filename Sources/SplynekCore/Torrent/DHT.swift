import Foundation
import Network

/// Minimal Kademlia-style DHT client (BEP 5, BEP 32 for IPv6-ish).
/// Scope: one-shot peer discovery for a given info hash.
///
/// Workflow:
///   1. Bootstrap against well-known nodes, send `find_node` for our own id.
///   2. From returned nodes, send `get_peers` for the target info hash.
///   3. Walk the closest responses (by XOR distance) until we collect peers,
///      bound by total time/round count.
///
/// Missing (on purpose):
///   - Routing-table persistence
///   - `announce_peer`
///   - Reply-to-inbound queries (we operate as a read-only client)
///   - Rate limiting, token management (we issue the token only if asked but
///     don't announce so we don't need to cache one)
///
/// Works well enough to bootstrap a magnet download. Enormously less code
/// than mainline DHT.
actor DHTState {
    var seenNodes: Set<String> = []
    var peers: Set<TorrentPeer> = []
    var pending: [(id: Data, ip: String, port: UInt16)] = []
    /// Nodes that returned values for our get_peers, keyed by
    /// "ip:port" → (token, id). Used for BEP 5 announce_peer.
    var tokens: [String: (token: Data, id: Data)] = [:]
    /// Every node we successfully got a reply from — fed into the persisted
    /// routing table so subsequent launches bootstrap faster.
    var goodNodes: [(id: Data, ip: String, port: UInt16)] = []

    func markSeenIfNew(_ key: String) -> Bool {
        if seenNodes.contains(key) { return false }
        seenNodes.insert(key); return true
    }
    func insertPeer(_ p: TorrentPeer) { peers.insert(p) }
    func addPending(_ entry: (Data, String, UInt16), target: Data) {
        pending.append(entry)
        pending.sort { DHT.xorLess($0.id, $1.id, target: target) }
    }
    func drainPending(limit: Int) -> [(id: Data, ip: String, port: UInt16)] {
        let take = Array(pending.prefix(limit))
        pending.removeFirst(min(limit, pending.count))
        return take
    }
    func peerSnapshot() -> [TorrentPeer] { Array(peers) }
    var peerCount: Int { peers.count }
    func recordToken(ip: String, port: UInt16, token: Data, id: Data) {
        tokens["\(ip):\(port)"] = (token, id)
    }
    func tokenSnapshot() -> [String: (token: Data, id: Data)] { tokens }
    func recordGood(id: Data, ip: String, port: UInt16) {
        goodNodes.append((id, ip, port))
    }
    func goodSnapshot() -> [(Data, String, UInt16)] { goodNodes }
    func seedPending(_ entries: [(Data, String, UInt16)], target: Data) {
        pending.append(contentsOf: entries)
        pending.sort { DHT.xorLess($0.id, $1.id, target: target) }
    }
}

/// JSON schema for the persisted DHT routing table.
struct DHTRoutingTableSnapshot: Codable {
    struct Node: Codable { var idHex: String; var ip: String; var port: UInt16 }
    var version: Int = 1
    var savedAt: Date
    var nodes: [Node]
}

enum DHTRoutingTable {
    static var storeURL: URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("dht-routing.json")
    }

    static func load() -> [(Data, String, UInt16)] {
        guard let data = try? Data(contentsOf: storeURL),
              let snap = try? JSONDecoder().decode(DHTRoutingTableSnapshot.self, from: data)
        else { return [] }
        return snap.nodes.compactMap { n in
            guard let id = Data(hexEncoded: n.idHex) else { return nil }
            return (id, n.ip, n.port)
        }
    }

    static func save(_ nodes: [(Data, String, UInt16)]) {
        // Cap at 200 most-recent good nodes so the file doesn't grow without bound.
        let tail = nodes.suffix(200)
        let snap = DHTRoutingTableSnapshot(
            savedAt: Date(),
            nodes: tail.map { .init(idHex: $0.0.hexEncodedString, ip: $0.1, port: $0.2) }
        )
        if let data = try? JSONEncoder().encode(snap) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }
}

final class DHT {

    static let bootstrapNodes: [(String, UInt16)] = [
        ("router.bittorrent.com", 6881),
        ("router.utorrent.com", 6881),
        ("dht.transmissionbt.com", 6881),
        ("dht.libtorrent.org", 25401)
    ]

    let infoHash: Data
    let interface: NWInterface
    let ourNodeID: Data
    private let state = DHTState()

    init(infoHash: Data, interface: NWInterface) {
        self.infoHash = infoHash
        self.interface = interface
        var id = Data(count: 20)
        for i in 0..<20 { id[i] = UInt8.random(in: 0...255) }
        self.ourNodeID = id
    }

    static func xorLess(_ a: Data, _ b: Data, target: Data) -> Bool {
        let len = min(a.count, b.count, target.count)
        for i in 0..<len {
            let da = a[a.startIndex + i] ^ target[target.startIndex + i]
            let db = b[b.startIndex + i] ^ target[target.startIndex + i]
            if da != db { return da < db }
        }
        return false
    }

    /// Discover peers for the configured info hash. Bounded by `timeout`.
    func getPeers(timeout: Double) async throws -> [TorrentPeer] {
        // Seed from persisted routing table first — this often short-circuits
        // the bootstrap resolution step, which is slow on cold networks.
        let persisted = DHTRoutingTable.load()
        if !persisted.isEmpty {
            await state.seedPending(persisted, target: infoHash)
        }

        var resolved: [(String, UInt16)] = []
        for (host, port) in Self.bootstrapNodes {
            if let ip = await resolve(host: host) {
                resolved.append((ip, port))
            }
        }

        let deadline = Date().addingTimeInterval(timeout)

        // Initial flood: get_peers to every bootstrap node + persisted nodes.
        await withTaskGroup(of: Void.self) { group in
            for (ip, port) in resolved {
                group.addTask { [weak self] in
                    await self?.queryGetPeers(ip: ip, port: port)
                }
            }
            // Kick off persisted nodes too (up to 8 in parallel).
            for (_, ip, port) in persisted.prefix(8) {
                group.addTask { [weak self] in
                    await self?.queryGetPeers(ip: ip, port: port)
                }
            }
        }

        while Date() < deadline {
            let batch = await state.drainPending(limit: 16)
            if batch.isEmpty { break }
            await withTaskGroup(of: Void.self) { group in
                for item in batch {
                    group.addTask { [weak self] in
                        await self?.queryGetPeers(ip: item.ip, port: item.port)
                    }
                }
            }
            let count = await state.peerCount
            if count >= 50 { break }
        }
        // Persist everything we learned for next launch.
        let good = await state.goodSnapshot()
        if !good.isEmpty { DHTRoutingTable.save(good) }
        return await state.peerSnapshot()
    }

    /// BEP 5 announce_peer — tell the nodes that returned values for our
    /// info hash that we *also* have it (or soon will), so that future
    /// get_peers callers find us. Call after a torrent starts seeding (or
    /// at least after it has a file to serve).
    func announcePeerToKnownNodes(port: UInt16) async {
        let tokens = await state.tokenSnapshot()
        for (key, entry) in tokens {
            let parts = key.split(separator: ":")
            guard parts.count == 2,
                  let remotePort = UInt16(parts[1]) else { continue }
            let ip = String(parts[0])
            let query: Bencode.Value = .dict([
                Data("t".utf8): .bytes(Data((0..<2).map { _ in UInt8.random(in: 0...255) })),
                Data("y".utf8): .bytes(Data("q".utf8)),
                Data("q".utf8): .bytes(Data("announce_peer".utf8)),
                Data("a".utf8): .dict([
                    Data("id".utf8):         .bytes(ourNodeID),
                    Data("info_hash".utf8):  .bytes(infoHash),
                    Data("port".utf8):       .integer(Int64(port)),
                    Data("token".utf8):      .bytes(entry.token),
                    Data("implied_port".utf8): .integer(0)
                ])
            ])
            _ = try? await send(to: ip, port: remotePort,
                                data: Bencode.encode(query), timeout: 2.0)
        }
    }

    private func queryGetPeers(ip: String, port: UInt16) async {
        let key = "\(ip):\(port)"
        let fresh = await state.markSeenIfNew(key)
        if !fresh { return }

        let txn = Data((0..<2).map { _ in UInt8.random(in: 0...255) })
        let query: Bencode.Value = .dict([
            Data("t".utf8): .bytes(txn),
            Data("y".utf8): .bytes(Data("q".utf8)),
            Data("q".utf8): .bytes(Data("get_peers".utf8)),
            Data("a".utf8): .dict([
                Data("id".utf8):        .bytes(ourNodeID),
                Data("info_hash".utf8): .bytes(infoHash)
            ])
        ])
        guard let resp = try? await send(to: ip, port: port, data: Bencode.encode(query), timeout: 3.0) else {
            return
        }
        await handleResponse(resp, remoteIP: ip, remotePort: port)
    }

    private func handleResponse(_ data: Data, remoteIP: String, remotePort: UInt16) async {
        guard let v = try? Bencode.decode(data), case .dict(let d) = v else { return }
        guard case .bytes(let y)? = Bencode.lookup(d, "y"),
              y == Data("r".utf8),
              case .dict(let r)? = Bencode.lookup(d, "r") else { return }

        // Remote responded — record them as a good node for persistence.
        if case .bytes(let rid)? = Bencode.lookup(r, "id"), rid.count == 20 {
            await state.recordGood(id: rid, ip: remoteIP, port: remotePort)
        }
        // Store any token so we can announce_peer later.
        if case .bytes(let token)? = Bencode.lookup(r, "token"),
           case .bytes(let rid)? = Bencode.lookup(r, "id") {
            await state.recordToken(ip: remoteIP, port: remotePort, token: token, id: rid)
        }

        if case .list(let values)? = Bencode.lookup(r, "values") {
            for v in values {
                if case .bytes(let b) = v, b.count == 6 {
                    let ip = "\(b[0]).\(b[1]).\(b[2]).\(b[3])"
                    let port = (UInt16(b[4]) << 8) | UInt16(b[5])
                    if port > 0 {
                        await state.insertPeer(TorrentPeer(ip: ip, port: port))
                    }
                }
            }
        }
        if case .bytes(let nodes)? = Bencode.lookup(r, "nodes") {
            var i = nodes.startIndex
            while i + 26 <= nodes.endIndex {
                let id = Data(nodes[i..<(i + 20)])
                let ip = "\(nodes[i + 20]).\(nodes[i + 21]).\(nodes[i + 22]).\(nodes[i + 23])"
                let port = (UInt16(nodes[i + 24]) << 8) | UInt16(nodes[i + 25])
                if port > 0 {
                    await state.addPending((id, ip, port), target: infoHash)
                }
                i += 26
            }
        }
    }

    // MARK: UDP transport

    private func send(to ip: String, port: UInt16, data: Data, timeout: Double) async throws -> Data {
        let params: NWParameters = .udp
        params.requiredInterface = interface
        let conn = NWConnection(
            to: .hostPort(host: .init(ip), port: .init(integerLiteral: port)),
            using: params
        )
        let queue = DispatchQueue(label: "splynek.dht.\(ip)")
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:    if gate.fire() { cont.resume() }
                case .failed(let e):
                    if gate.fire() { cont.resume(throwing: NSError(domain: "DHT", code: 1, userInfo: [NSLocalizedDescriptionKey: e.localizedDescription])) }
                case .cancelled:
                    if gate.fire() { cont.resume(throwing: NSError(domain: "DHT", code: 2)) }
                default: break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 3) {
                if gate.fire() { conn.cancel(); cont.resume(throwing: NSError(domain: "DHT", code: 3)) }
            }
        }
        defer { conn.cancel() }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: e) } else { cont.resume() }
            })
        }
        return try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    conn.receiveMessage { data, _, _, error in
                        if let e = error { cont.resume(throwing: e); return }
                        cont.resume(returning: data ?? Data())
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw NSError(domain: "DHT", code: 4)
            }
            defer { group.cancelAll() }
            return try await group.next() ?? Data()
        }
    }

    // MARK: Helpers

    private func resolve(host: String) async -> String? {
        // Use low-level NWEndpoint resolution via a quick NWConnection dance
        // so the DNS obeys our required interface.
        await withCheckedContinuation { cont in
            let params: NWParameters = .udp
            params.requiredInterface = interface
            let conn = NWConnection(
                to: .hostPort(host: .init(host), port: 6881),
                using: params
            )
            let gate = ResumeGate()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready, .failed, .cancelled, .waiting:
                    if gate.fire() {
                        if case let .hostPort(h, _) = conn.currentPath?.remoteEndpoint ?? conn.endpoint,
                           case let .ipv4(addr) = h {
                            cont.resume(returning: "\(addr)")
                        } else {
                            cont.resume(returning: nil)
                        }
                        conn.cancel()
                    }
                default: break
                }
            }
            conn.start(queue: DispatchQueue(label: "splynek.dht.resolve.\(host)"))
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                if gate.fire() { conn.cancel(); cont.resume(returning: nil) }
            }
        }
    }

}
