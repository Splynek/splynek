import Foundation
import Network

@MainActor
final class SeedingProgress: ObservableObject {
    @Published var listening: Bool = false
    @Published var port: UInt16 = 0
    @Published var connectedPeers: Int = 0
    @Published var piecesServed: Int = 0
    @Published var bytesServed: Int64 = 0
    @Published var started: Date = .distantPast

    var uptime: TimeInterval {
        started == .distantPast ? 0 : Date().timeIntervalSince(started)
    }
}

enum SeedError: Error {
    case listenFailed(String)
    case closed
    case badHandshake
    case timeout
}

/// BitTorrent seeder.
///
/// Accepts inbound peer connections on a TCP port (optionally pinned to a
/// specific interface), validates the BEP 3 handshake, sends our complete
/// bitfield, and serves piece requests from disk via `TorrentWriter.readAt`.
///
/// In scope:
///   - One torrent per instance
///   - Pure seed: no tit-for-tat, we unchoke every interested peer up to
///     `maxConnectedPeers`; pieces are served in request order
///   - BEP 3 + BEP 6 + BEP 10 reserved bits advertised (though we don't
///     use them beyond passive compatibility)
///   - Multi-file torrents (via TorrentWriter)
///
/// Out of scope:
///   - Rate limiting, choking rotation, optimistic unchoke
///   - Super-seeding (BEP 16)
///   - Partial-seed while still leeching
final class SeedingService {

    static let maxConnectedPeers = 20
    static let pieceReadBudget = 1 * 1024 * 1024   // 1 MiB max per request block

    let info: TorrentInfo
    let storage: TorrentWriter
    let ourPeerID: Data
    let interface: NWInterface?
    let progress: SeedingProgress

    private var listener: NWListener?
    private let cancelFlag = CancelFlag()
    private var running = false
    private var keepaliveTask: Task<Void, Never>?

    /// BT keepalive is a 4-byte zero-length message. Peers' 120s read
    /// deadline would otherwise tear down long-idle connections.
    static let keepaliveMessage = Data([0, 0, 0, 0])
    static let keepaliveInterval: TimeInterval = 90

    /// Maximum number of peers we'll unchoke at once. BEP 3 suggests 4.
    static let maxUnchoked = 4
    /// How often the rotation timer reassesses the unchoked set.
    static let chokingInterval: TimeInterval = 10

    /// Choke message (id=0, length=1)
    static let chokeMessage   = Data([0, 0, 0, 1, 0])
    /// Unchoke message (id=1, length=1)
    static let unchokeMessage = Data([0, 0, 0, 1, 1])

    private var chokingTask: Task<Void, Never>?

    /// Our dynamic "have" bitfield. Mutated by the engine as pieces complete,
    /// so that partial-seed-while-leech peers see the latest snapshot.
    private var haveBits: BitSet
    /// Peers currently connected, tracked so we can broadcast `have` messages
    /// when a new piece completes during partial seeding.
    private var liveSeeders: [SeedPeer] = []
    private let liveLock = NSLock()

    var boundPort: UInt16 {
        UInt16(truncatingIfNeeded: listener?.port?.rawValue ?? 0)
    }

    /// Mark a piece complete. Updates our bitfield and, if there are already
    /// connected peers, broadcasts a `have` message to each.
    func markPieceComplete(_ index: Int) {
        liveLock.lock()
        haveBits.set(index)
        let peers = liveSeeders
        liveLock.unlock()
        let msg = Self.haveMessage(index: Int32(index))
        for peer in peers {
            Task { try? await peer.send(msg) }
        }
    }

    private static func haveMessage(index: Int32) -> Data {
        var d = Data()
        // <len=5><id=4><index>
        d.append(contentsOf: [0, 0, 0, 5, 4])
        d.append(UInt8((UInt32(index) >> 24) & 0xff))
        d.append(UInt8((UInt32(index) >> 16) & 0xff))
        d.append(UInt8((UInt32(index) >> 8)  & 0xff))
        d.append(UInt8(UInt32(index) & 0xff))
        return d
    }

    init(info: TorrentInfo, storage: TorrentWriter, ourPeerID: Data,
         interface: NWInterface?, progress: SeedingProgress,
         initiallyComplete: Bool = true) {
        self.info = info
        self.storage = storage
        self.ourPeerID = ourPeerID
        self.interface = interface
        self.progress = progress
        if initiallyComplete {
            self.haveBits = BitSet.allSet(count: info.numPieces)
        } else {
            self.haveBits = BitSet(count: info.numPieces)
        }
    }

    func start() throws {
        guard !running else { return }
        let params: NWParameters = .tcp
        if let iface = interface { params.requiredInterface = iface }
        let l: NWListener
        do {
            l = try NWListener(using: params)
        } catch {
            throw SeedError.listenFailed(error.localizedDescription)
        }
        l.newConnectionHandler = { [weak self] conn in
            guard let self else { conn.cancel(); return }
            Task { await self.accept(conn) }
        }
        l.stateUpdateHandler = { [weak self] state in
            guard let self else { return }
            if case .ready = state {
                let port = UInt16(truncatingIfNeeded: l.port?.rawValue ?? 0)
                Task { @MainActor in
                    self.progress.listening = true
                    self.progress.port = port
                    self.progress.started = Date()
                }
            }
        }
        l.start(queue: DispatchQueue(label: "splynek.seed.listener"))
        self.listener = l
        self.running = true
        startKeepalives()
        startChokingRotation()
    }

    func stop() {
        cancelFlag.cancel()
        keepaliveTask?.cancel()
        keepaliveTask = nil
        chokingTask?.cancel()
        chokingTask = nil
        listener?.cancel()
        listener = nil
        running = false
        Task { @MainActor in progress.listening = false }
    }

    /// Reassess the unchoked set every `chokingInterval` seconds. Policy
    /// is a pure-seeder approximation of BEP 3:
    ///   - up to `maxUnchoked - 1` regular slots go to the interested
    ///     peers we've unchoked *least recently* (LRU rotation so every
    ///     peer gets a turn)
    ///   - 1 remaining "optimistic" slot goes to a random interested
    ///     peer the LRU set didn't already pick
    /// Everyone else is choked. Interest-state changes during the slot
    /// period are observed at the next tick — no need to race the timer.
    private func startChokingRotation() {
        chokingTask?.cancel()
        chokingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(Self.chokingInterval * 1_000_000_000)
                )
                guard let self, !self.cancelFlag.isCancelled else { return }
                await self.reassessChoking()
            }
        }
    }

    private func reassessChoking() async {
        liveLock.lock()
        let interested = liveSeeders.filter { $0.interested }
        let others     = liveSeeders.filter { !$0.interested }
        liveLock.unlock()

        // Rank interested peers. Tit-for-tat: peers that have sent us data
        // (non-zero `bytesReceivedFromPeer`) come first, ordered by how
        // much they've contributed. Peers with zero contribution fall
        // back to LRU so they still get rotation fairness.
        let ranked = interested.sorted { a, b in
            let aContrib = a.bytesReceivedFromPeer
            let bContrib = b.bytesReceivedFromPeer
            if aContrib != bContrib { return aContrib > bContrib }
            // Tiebreak / fallback: LRU (oldest unchoke first, nil first).
            switch (a.lastUnchokedAt, b.lastUnchokedAt) {
            case (nil, nil): return false
            case (nil, _):   return true
            case (_, nil):   return false
            case let (.some(t1), .some(t2)): return t1 < t2
            }
        }
        let regular = Array(ranked.prefix(max(0, Self.maxUnchoked - 1)))
        let regularIDs = Set(regular.map(ObjectIdentifier.init))
        // Optimistic slot: random interested peer not already selected.
        var toUnchoke = regular
        let remainder = ranked.filter { !regularIDs.contains(ObjectIdentifier($0)) }
        if let optimistic = remainder.randomElement() {
            toUnchoke.append(optimistic)
        }
        let unchokeIDs = Set(toUnchoke.map(ObjectIdentifier.init))

        // Apply state transitions: send choke / unchoke messages only on edges.
        for peer in interested {
            let shouldBeUnchoked = unchokeIDs.contains(ObjectIdentifier(peer))
            if shouldBeUnchoked && peer.choked {
                peer.choked = false
                peer.lastUnchokedAt = Date()
                Task { try? await peer.send(Self.unchokeMessage) }
            } else if !shouldBeUnchoked && !peer.choked {
                peer.choked = true
                Task { try? await peer.send(Self.chokeMessage) }
            }
        }
        // Peers that dropped from interested → choke them.
        for peer in others where !peer.choked {
            peer.choked = true
            Task { try? await peer.send(Self.chokeMessage) }
        }
    }

    /// Periodically send a 4-byte zero keepalive to every connected peer.
    /// Fires every `keepaliveInterval` seconds while the service is live.
    private func startKeepalives() {
        keepaliveTask?.cancel()
        keepaliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(
                    nanoseconds: UInt64(Self.keepaliveInterval * 1_000_000_000)
                )
                guard let self, !self.cancelFlag.isCancelled else { return }
                self.liveLock.lock()
                let peers = self.liveSeeders
                self.liveLock.unlock()
                for peer in peers {
                    Task { try? await peer.send(Self.keepaliveMessage) }
                }
            }
        }
    }

    // MARK: Per-connection

    private func accept(_ conn: NWConnection) async {
        await MainActor.run { progress.connectedPeers += 1 }
        defer {
            Task { @MainActor in
                self.progress.connectedPeers = max(0, self.progress.connectedPeers - 1)
            }
        }

        let peer = SeedPeer(conn: conn)
        peer.start()
        defer { peer.close() }

        do {
            try await peer.waitReady(timeout: 10)
            let shake = try await peer.readHandshake(timeout: 10)
            guard shake.infoHash == info.infoHash else { return }
            try await peer.sendHandshake(
                infoHash: info.infoHash,
                ourPeerID: ourPeerID
            )
            // Snapshot the current bitfield so the peer sees exactly what we
            // have right now; subsequent newly-completed pieces are delivered
            // via live `have` broadcasts from markPieceComplete.
            liveLock.lock()
            let snapshot = haveBits
            liveSeeders.append(peer)
            liveLock.unlock()
            defer {
                liveLock.lock()
                liveSeeders.removeAll { $0 === peer }
                liveLock.unlock()
            }
            try await peer.sendBitfield(haveBits: snapshot, numPieces: info.numPieces)
            try await peer.sendExtendedHandshake()
            try await messageLoop(peer)
        } catch {
            return
        }
    }

    private func messageLoop(_ peer: SeedPeer) async throws {
        while !cancelFlag.isCancelled {
            let msg = try await peer.readMessage()
            // Tit-for-tat signal: credit every non-keepalive byte this peer
            // sent to us (header + payload) toward their unchoke priority.
            if msg.id >= 0 {
                peer.bytesReceivedFromPeer += Int64(5 + msg.payload.count)
            }
            switch msg.id {
            case -1:   // keepalive
                continue
            case 2:    // interested
                peer.interested = true
                // No auto-unchoke: the rotation timer decides who gets a slot.
            case 3:    // not interested
                peer.interested = false
            case 6:    // request
                // Only honour requests from peers we've actually unchoked.
                // A well-behaved peer won't send requests while choked, but
                // don't reward one that does.
                guard !peer.choked else { continue }
                try await handleRequest(peer, payload: msg.payload)
            case 8:    // cancel — we serve requests synchronously, nothing to cancel
                continue
            case 20:   // extended (ut_pex etc.) — ignore
                continue
            default:
                continue
            }
        }
    }

    private func handleRequest(_ peer: SeedPeer, payload: Data) async throws {
        guard payload.count >= 12 else { return }
        let idx = readU32(payload, 0)
        let begin = readU32(payload, 4)
        let length = readU32(payload, 8)
        guard length > 0, length <= UInt32(Self.pieceReadBudget) else { return }
        guard Int(idx) < info.numPieces else { return }

        // Compute virtual-file offset and clamp to piece bounds.
        let pieceRange = TorrentFile.pieceByteRange(info: info, index: Int(idx))
        let wantStart = pieceRange.lowerBound + Int64(begin)
        let wantEnd = wantStart + Int64(length)
        guard wantEnd <= pieceRange.upperBound else { return }

        let data: Data
        do {
            data = try storage.readAt(virtualOffset: wantStart, length: Int64(length))
        } catch {
            return
        }

        // Piece message: <4-byte len><id=7><index><begin><block>
        var out = Data()
        out.append(contentsOf: writeU32(UInt32(9 + data.count)))
        out.append(7)
        out.append(contentsOf: writeU32(idx))
        out.append(contentsOf: writeU32(begin))
        out.append(data)
        try await peer.send(out)

        let byteCount = Int64(data.count)
        await MainActor.run {
            self.progress.bytesServed += byteCount
            // A "piece served" is counted once per complete block of the
            // wire-protocol sense; treat each request as one served block.
            self.progress.piecesServed += 1
        }
    }

    // MARK: Bit helpers

    private func readU32(_ d: Data, _ off: Int) -> UInt32 {
        let b = d.startIndex + off
        return (UInt32(d[b]) << 24) | (UInt32(d[b + 1]) << 16) |
               (UInt32(d[b + 2]) << 8) |  UInt32(d[b + 3])
    }
    private func writeU32(_ v: UInt32) -> [UInt8] {
        [UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff),
         UInt8((v >> 8) & 0xff),  UInt8(v & 0xff)]
    }
}

// MARK: Per-peer wire helper

final class SeedPeer {
    let conn: NWConnection
    var buffer = Data()
    var interested = false
    /// Our choke state *toward this peer*. New peers start choked; the
    /// SeedingService's rotation loop promotes them.
    var choked = true
    /// When we last unchoked this peer. Nil == never. Used as LRU sort
    /// key so peers get fair rotation instead of endless unchoke.
    var lastUnchokedAt: Date?
    /// Bytes received from this peer (payload only, excluding our own
    /// sends). BEP 3's tit-for-tat signal: higher upload-rate-to-us ⇒
    /// preferred unchoke.
    var bytesReceivedFromPeer: Int64 = 0
    private let queue = DispatchQueue(label: "splynek.seed.peer")

    init(conn: NWConnection) { self.conn = conn }

    func start() {
        conn.stateUpdateHandler = { _ in }
        conn.start(queue: queue)
    }

    func close() { conn.cancel() }

    func waitReady(timeout: TimeInterval) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:    if gate.fire() { cont.resume() }
                case .failed(let e):
                    if gate.fire() { cont.resume(throwing: SeedError.listenFailed(e.localizedDescription)) }
                case .cancelled:
                    if gate.fire() { cont.resume(throwing: SeedError.closed) }
                default: break
                }
            }
            queue.asyncAfter(deadline: .now() + timeout) {
                if gate.fire() { cont.resume(throwing: SeedError.timeout) }
            }
        }
    }

    struct Handshake { let infoHash: Data; let peerID: Data; let reserved: Data }

    func readHandshake(timeout: TimeInterval) async throws -> Handshake {
        let pstrlenData = try await readBytes(1, timeout: timeout)
        let pstrlen = Int(pstrlenData.first ?? 0)
        let rest = try await readBytes(pstrlen + 8 + 20 + 20, timeout: timeout)
        let reservedStart = pstrlen
        let reserved = rest.subdata(in: reservedStart..<(reservedStart + 8))
        let infoHashStart = reservedStart + 8
        let infoHash = rest.subdata(in: infoHashStart..<(infoHashStart + 20))
        let peerID = rest.subdata(in: (infoHashStart + 20)..<(infoHashStart + 40))
        return Handshake(infoHash: infoHash, peerID: peerID, reserved: reserved)
    }

    func sendHandshake(infoHash: Data, ourPeerID: Data) async throws {
        var d = Data()
        let pstr = "BitTorrent protocol"
        d.append(UInt8(pstr.count))
        d.append(Data(pstr.utf8))
        d.append(PeerWire.reservedBytes)
        d.append(infoHash)
        d.append(ourPeerID)
        try await send(d)
    }

    func sendBitfield(haveBits: BitSet, numPieces: Int) async throws {
        // Serialise the caller-provided bitfield. BitSet already stores
        // big-endian bytes with MSB = piece 0, so we can ship its `bytes`
        // directly.
        let bitfield = haveBits.bytes
        var msg = Data()
        let total = UInt32(1 + bitfield.count)
        msg.append(contentsOf: [
            UInt8((total >> 24) & 0xff),
            UInt8((total >> 16) & 0xff),
            UInt8((total >> 8)  & 0xff),
            UInt8(total & 0xff)
        ])
        msg.append(5)
        msg.append(bitfield)
        try await send(msg)
    }

    func sendExtendedHandshake() async throws {
        var mDict: [Data: Bencode.Value] = [:]
        for (name, id) in PeerWire.ourExtensionIDs {
            mDict[Data(name.utf8)] = .integer(Int64(id))
        }
        let handshakeDict: Bencode.Value = .dict([
            Data("m".utf8): .dict(mDict),
            Data("v".utf8): .bytes(Data("Splynek/0.1".utf8))
        ])
        let payload = Bencode.encode(handshakeDict)
        var msg = Data()
        let totalLen = UInt32(2 + payload.count)
        msg.append(contentsOf: [UInt8((totalLen >> 24) & 0xff),
                                UInt8((totalLen >> 16) & 0xff),
                                UInt8((totalLen >> 8) & 0xff),
                                UInt8(totalLen & 0xff)])
        msg.append(20)  // extended
        msg.append(0)   // extended handshake
        msg.append(payload)
        try await send(msg)
    }

    struct WireMessage { let id: Int; let payload: Data }

    func readMessage() async throws -> WireMessage {
        let header = try await readBytes(4, timeout: 120)  // keepalive interval
        let len = (UInt32(header[0]) << 24) | (UInt32(header[1]) << 16) |
                  (UInt32(header[2]) << 8) | UInt32(header[3])
        if len == 0 { return WireMessage(id: -1, payload: Data()) }
        guard len < 2 * 1024 * 1024 else { throw SeedError.badHandshake }
        let body = try await readBytes(Int(len), timeout: 60)
        let id = Int(body[body.startIndex])
        let payload = body.subdata(in: body.index(after: body.startIndex)..<body.endIndex)
        return WireMessage(id: id, payload: payload)
    }

    func sendSimple(id: UInt8) async throws {
        let d = Data([0, 0, 0, 1, id])
        try await send(d)
    }

    func send(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            conn.send(content: data, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: e) } else { cont.resume() }
            })
        }
    }

    // MARK: Low-level read

    private func readBytes(_ count: Int, timeout: TimeInterval) async throws -> Data {
        while buffer.count < count {
            let piece = try await recvOnce(timeout: timeout)
            if piece.isEmpty { throw SeedError.closed }
            buffer.append(piece)
        }
        let out = buffer.prefix(count)
        buffer = buffer.subdata(in: count..<buffer.count)
        return Data(out)
    }

    private func recvOnce(timeout: TimeInterval) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask { [weak self] in
                guard let self else { return Data() }
                return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    self.conn.receive(minimumIncompleteLength: 1, maximumLength: 128 * 1024) { data, _, _, error in
                        if let e = error { cont.resume(throwing: e); return }
                        cont.resume(returning: data ?? Data())
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw SeedError.timeout
            }
            defer { group.cancelAll() }
            return try await group.next() ?? Data()
        }
    }
}
