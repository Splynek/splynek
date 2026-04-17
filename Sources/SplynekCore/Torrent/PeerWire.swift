import Foundation
import Network

/// BitTorrent peer wire protocol (BEP 3) over TCP, with:
///   - Fast extension (BEP 6) — have_all / have_none / reject_request / allowed_fast / suggest_piece
///   - Extension protocol (BEP 10) for BEP 9 metadata exchange (magnet → info dict)
///
/// Still out of scope: uTP, MSE encryption, PEX.
///
/// This file has gotten dense enough that the message-framing layer
/// (PeerWire) and the orchestration layer (PeerSession) should probably
/// split. For v0.2 they live together but the public surface separates them.
final class PeerWire {

    static let protocolString = "BitTorrent protocol"
    static let blockSize: Int32 = 16 * 1024

    /// Reserved-bits byte-5 bit 0x10 advertises Extension Protocol (BEP 10).
    /// Reserved-bits byte-7 bit 0x04 advertises Fast Extension (BEP 6).
    /// Reserved-bits byte-7 bit 0x08 advertises BEP 52 v2 / hybrid support.
    /// BEP 52 itself doesn't standardise a reserved-bit value; this follows
    /// the libtorrent convention so hybrid peers can recognise us. Sending
    /// it is harmless to v1-only peers — they just ignore it.
    static let reservedBytes: Data = {
        var r = Data(count: 8)
        r[5] = 0x10   // BEP 10
        r[7] |= 0x04  // BEP 6
        r[7] |= 0x08  // BEP 52 (libtorrent convention)
        return r
    }()

    let peer: TorrentPeer
    let infoHash: Data
    let ourPeerID: Data
    let interface: NWInterface
    private let cancelFlag: CancelFlag
    private let dispatchQueue: DispatchQueue
    private var conn: NWConnection?

    /// Peer's advertised bitfield. Nil until first bitfield/have_all/have_none.
    private(set) var peerHas: BitSet?
    private(set) var chokingUs: Bool = true
    private(set) var peerInterested: Bool = false
    /// Pieces the peer explicitly allows-fast for us (BEP 6).
    private(set) var allowedFast: Set<Int> = []
    /// Set when peer's reserved bits advertise the capability.
    private(set) var peerSupportsFast: Bool = false
    private(set) var peerSupportsExtended: Bool = false
    /// Peer's extension message IDs (BEP 10), keyed by extension name.
    private(set) var peerExtensionIDs: [String: Int] = [:]
    /// Our local IDs we advertise in the handshake.
    static let ourExtensionIDs: [String: Int] = [
        "ut_metadata": 1,
        "ut_pex":      2
    ]

    /// Set by the engine to receive BEP 11 peer-exchange updates from this peer.
    var onPexPeers: (([TorrentPeer]) -> Void)?

    init(peer: TorrentPeer, infoHash: Data, ourPeerID: Data,
         interface: NWInterface, cancelFlag: CancelFlag) {
        self.peer = peer
        self.infoHash = infoHash
        self.ourPeerID = ourPeerID
        self.interface = interface
        self.cancelFlag = cancelFlag
        self.dispatchQueue = DispatchQueue(label: "splynek.peer.\(peer.ip):\(peer.port)")
    }

    enum WireError: Error, LocalizedError {
        case transport(String)
        case handshakeMismatch
        case chokedTooLong
        case peerClosed
        case rejected(Int32)

        var errorDescription: String? {
            switch self {
            case .transport(let s):    return "Peer transport: \(s)"
            case .handshakeMismatch:   return "Peer handshake info_hash mismatch."
            case .chokedTooLong:       return "Peer kept us choked past deadline."
            case .peerClosed:          return "Peer closed connection."
            case .rejected(let i):     return "Peer rejected request for piece \(i)."
            }
        }
    }

    // MARK: Connect + handshake

    func connectAndHandshake(numPieces: Int) async throws {
        try await open()
        try await sendHandshake()
        try await readHandshake()
        if peerHas == nil, numPieces > 0 {
            peerHas = BitSet(count: numPieces)
        }
        // If peer advertised extension protocol, send our extended handshake
        // immediately. Peer expects ours too, per BEP 10.
        if peerSupportsExtended {
            try await sendExtendedHandshake()
        }
    }

    /// Tell peer we're interested and wait for unchoke (or allowed_fast slots).
    func waitForUnchoke(timeout: TimeInterval = 20) async throws {
        try await sendSimple(id: 2)
        let deadline = Date().addingTimeInterval(timeout)
        while !cancelFlag.isCancelled {
            if Date() > deadline && !chokingUs == false && allowedFast.isEmpty {
                throw WireError.chokedTooLong
            }
            let msg = try await readMessage()
            try handle(msg: msg)
            if !chokingUs || !allowedFast.isEmpty { return }
            if Date() > deadline { throw WireError.chokedTooLong }
        }
        throw WireError.transport("cancelled")
    }

    // MARK: Piece download

    /// Download piece at `index` of length `pieceLength`. Returns the raw
    /// piece bytes. Caller verifies SHA-1.
    func downloadPiece(index: Int, pieceLength: Int64) async throws -> Data {
        guard (peerHas?.isSet(index) ?? false) || allowedFast.contains(index) else {
            throw WireError.transport("peer lacks piece \(index)")
        }
        var piece = Data(repeating: 0, count: Int(pieceLength))
        var nextBegin: Int32 = 0
        var inFlight = 0
        let maxInFlight = 12
        while nextBegin < Int32(pieceLength) || inFlight > 0 {
            if cancelFlag.isCancelled { throw WireError.transport("cancelled") }
            while nextBegin < Int32(pieceLength) && inFlight < maxInFlight {
                let blockLen = min(Self.blockSize, Int32(pieceLength) - nextBegin)
                try await sendRequest(index: Int32(index), begin: nextBegin, length: blockLen)
                nextBegin += blockLen
                inFlight += 1
            }
            let msg = try await readMessage()
            switch msg {
            case .piece(let pIdx, let begin, let data):
                if pIdx == Int32(index) {
                    let dstStart = Int(begin)
                    piece.replaceSubrange(dstStart..<(dstStart + data.count), with: data)
                    inFlight -= 1
                }
            case .choke:
                chokingUs = true
                if !allowedFast.contains(index) {
                    throw WireError.transport("peer choked during piece")
                }
            case .unchoke:                     chokingUs = false
            case .have(let p):                 peerHas?.set(Int(p))
            case .haveAll:                     peerHas = BitSet.allSet(count: peerHas?.count ?? 0)
            case .haveNone:                    peerHas = BitSet(count: peerHas?.count ?? 0)
            case .allowedFast(let p):          allowedFast.insert(Int(p))
            case .suggestPiece:                break
            case .rejectRequest(let p, _, _):
                if p == Int32(index) { throw WireError.rejected(p) }
                inFlight = max(0, inFlight - 1)
            case .bitfield(let bf):            peerHas = bf
            case .extended, .keepalive, .interested, .notInterested, .cancel, .other:
                continue
            }
        }
        return piece
    }

    func close() { conn?.cancel(); conn = nil }

    // MARK: BEP 9 metadata fetch (magnet → info dict)

    /// Download the info dict from this peer using ut_metadata (BEP 9).
    /// Requires the peer to have advertised `ut_metadata` + `metadata_size`
    /// in the extended handshake. Returns the raw info-dict bytes (the thing
    /// whose SHA-1 equals the info hash).
    func fetchMetadata() async throws -> Data {
        guard let peerMsgID = peerExtensionIDs["ut_metadata"] else {
            throw WireError.transport("peer doesn't support ut_metadata")
        }
        guard let totalSize = metadataSize else {
            throw WireError.transport("peer didn't send metadata_size")
        }
        let blockSize = 16 * 1024
        let pieceCount = (totalSize + blockSize - 1) / blockSize
        var acc = Data(count: totalSize)
        var received = 0
        var nextPiece = 0

        while received < totalSize && nextPiece < pieceCount {
            if cancelFlag.isCancelled { throw WireError.transport("cancelled") }
            // Request piece N
            let reqDict: Bencode.Value = .dict([
                Data("msg_type".utf8): .integer(0),   // request
                Data("piece".utf8):    .integer(Int64(nextPiece))
            ])
            let payload = Bencode.encode(reqDict)
            try await sendExtended(id: UInt8(peerMsgID), payload: payload)

            let msg = try await readMessage()
            switch msg {
            case .extended(let extID, let body):
                // Reply has bencoded dict at start, then raw data after.
                // Find where the dict ends via a partial decoder:
                guard let (dict, endOffset) = peekDict(body) else { continue }
                guard case .dict(let d) = dict else { continue }
                let msgType = Bencode.asInt(Bencode.lookup(d, "msg_type")) ?? -1
                let pieceNum = Int(Bencode.asInt(Bencode.lookup(d, "piece")) ?? -1)
                if msgType == 1 {  // data
                    let data = body.subdata(in: endOffset..<body.endIndex)
                    let offset = pieceNum * blockSize
                    let end = min(offset + data.count, totalSize)
                    let take = end - offset
                    if take > 0 {
                        let dataToWrite = data.prefix(take)
                        acc.replaceSubrange(offset..<end, with: Data(dataToWrite))
                        received += take
                        nextPiece += 1
                    }
                }
                // msgType == 2 => reject, just try next piece/peer
                _ = extID
            case .keepalive, .interested, .notInterested, .bitfield, .have, .haveAll, .haveNone,
                 .allowedFast, .suggestPiece, .choke, .unchoke, .piece, .cancel, .rejectRequest,
                 .other:
                continue
            }
        }
        guard received == totalSize else {
            throw WireError.transport("metadata incomplete: \(received)/\(totalSize)")
        }
        return acc
    }

    /// Parse a bencoded dict and return the length of consumed bytes.
    private func peekDict(_ data: Data) -> (Bencode.Value, Int)? {
        // We want the dict only, not trailing data — use a length-aware decode
        // by scanning the dict structure.
        var cursor = data.startIndex
        guard let v = try? _scan(&cursor, in: data) else { return nil }
        return (v, cursor)
    }

    private func _scan(_ c: inout Data.Index, in data: Data) throws -> Bencode.Value {
        // Re-use Bencode.decode by slicing progressively — simpler and safer:
        // scan to find a valid prefix that decodes, expand 1 KiB at a time.
        var span = min(256, data.count)
        while span <= data.count {
            if let v = try? Bencode.decode(data.prefix(span)) {
                c = data.startIndex + span
                return v
            }
            span = min(span * 2, data.count)
            if span == data.count {
                // Final try
                let v = try Bencode.decode(data)
                c = data.endIndex
                return v
            }
        }
        throw Bencode.DecodeError.unexpectedEOF
    }

    // MARK: Internals

    private var metadataSize: Int?

    private func open() async throws {
        let params: NWParameters = .tcp
        params.requiredInterface = interface
        let ip = peer.ip.hasPrefix("[") && peer.ip.hasSuffix("]")
            ? String(peer.ip.dropFirst().dropLast()) : peer.ip
        let endpoint = NWEndpoint.hostPort(
            host: .init(ip),
            port: .init(integerLiteral: peer.port)
        )
        let c = NWConnection(to: endpoint, using: params)
        conn = c
        cancelFlag.onCancel { [weak c] in c?.cancel() }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            c.stateUpdateHandler = { state in
                switch state {
                case .ready:    if gate.fire() { cont.resume() }
                case .failed(let e):
                    if gate.fire() { cont.resume(throwing: WireError.transport(e.localizedDescription)) }
                case .cancelled:
                    if gate.fire() { cont.resume(throwing: WireError.transport("cancelled")) }
                default: break
                }
            }
            c.start(queue: dispatchQueue)
            dispatchQueue.asyncAfter(deadline: .now() + 10) {
                if gate.fire() { c.cancel(); cont.resume(throwing: WireError.transport("connect timeout")) }
            }
        }
    }

    private func sendHandshake() async throws {
        var hs = Data()
        hs.append(UInt8(Self.protocolString.count))
        hs.append(Data(Self.protocolString.utf8))
        hs.append(Self.reservedBytes)
        hs.append(infoHash)
        hs.append(ourPeerID)
        try await send(hs)
    }

    private func readHandshake() async throws {
        let pstrlen = try await readBytes(1).first ?? 0
        let total = Int(pstrlen) + 8 + 20 + 20
        let rest = try await readBytes(total)
        // Reserved: bytes 0..<8 of rest, after pstr
        let reservedStart = Int(pstrlen)
        let reserved = rest.subdata(in: reservedStart..<(reservedStart + 8))
        peerSupportsExtended = (reserved[reserved.startIndex + 5] & 0x10) != 0
        peerSupportsFast = (reserved[reserved.startIndex + 7] & 0x04) != 0
        let infoStart = reservedStart + 8
        let peerInfoHash = rest.subdata(in: infoStart..<(infoStart + 20))
        guard peerInfoHash == infoHash else { throw WireError.handshakeMismatch }
    }

    private func sendExtendedHandshake() async throws {
        var mDict: [Data: Bencode.Value] = [:]
        for (name, id) in Self.ourExtensionIDs {
            mDict[Data(name.utf8)] = .integer(Int64(id))
        }
        let handshakeDict: Bencode.Value = .dict([
            Data("m".utf8): .dict(mDict),
            Data("v".utf8): .bytes(Data("Splynek/0.19".utf8))
        ])
        let payload = Bencode.encode(handshakeDict)
        try await sendExtended(id: 0, payload: payload)
    }

    // MARK: Message parsing

    enum Message {
        case keepalive
        case choke
        case unchoke
        case interested
        case notInterested
        case have(Int32)
        case bitfield(BitSet)
        case piece(Int32, Int32, Data)
        case cancel
        case haveAll
        case haveNone
        case rejectRequest(Int32, Int32, Int32)
        case suggestPiece(Int32)
        case allowedFast(Int32)
        case extended(UInt8, Data)
        case other
    }

    private func readMessage() async throws -> Message {
        let lenBytes = try await readBytes(4)
        let len = readU32(lenBytes, 0)
        if len == 0 { return .keepalive }
        let body = try await readBytes(Int(len))
        let id = body[body.startIndex]
        let payload = body.subdata(in: body.index(after: body.startIndex)..<body.endIndex)
        switch id {
        case 0:  return .choke
        case 1:  return .unchoke
        case 2:  return .interested
        case 3:  return .notInterested
        case 4:  return .have(Int32(readU32(payload, 0)))
        case 5:
            let count = peerHas?.count ?? (payload.count * 8)
            return .bitfield(BitSet(bytes: payload, count: count))
        case 7:
            let idx = Int32(readU32(payload, 0))
            let begin = Int32(readU32(payload, 4))
            let block = payload.subdata(in: (payload.startIndex + 8)..<payload.endIndex)
            return .piece(idx, begin, block)
        case 8:  return .cancel
        // Fast extension (BEP 6)
        case 0x0D: return .suggestPiece(Int32(readU32(payload, 0)))
        case 0x0E: return .haveAll
        case 0x0F: return .haveNone
        case 0x10:
            return .rejectRequest(
                Int32(readU32(payload, 0)),
                Int32(readU32(payload, 4)),
                Int32(readU32(payload, 8)))
        case 0x11: return .allowedFast(Int32(readU32(payload, 0)))
        case 20:
            // Extension protocol
            let extID = payload[payload.startIndex]
            let rest = payload.subdata(in: payload.index(after: payload.startIndex)..<payload.endIndex)
            if extID == 0, let dict = try? Bencode.decode(rest), case .dict(let d) = dict {
                // Extended handshake
                if let m = Bencode.asDict(Bencode.lookup(d, "m")) {
                    for (k, v) in m {
                        if let name = String(data: k, encoding: .utf8), let id = Bencode.asInt(v) {
                            peerExtensionIDs[name] = Int(id)
                        }
                    }
                }
                if let size = Bencode.asInt(Bencode.lookup(d, "metadata_size")) {
                    metadataSize = Int(size)
                }
            } else if extID == UInt8(Self.ourExtensionIDs["ut_pex"] ?? -1) {
                // BEP 11 PEX. Payload is a bencoded dict with `added` +
                // (optionally) `added6` compact peer blobs.
                if let dict = try? Bencode.decode(rest), case .dict(let d) = dict {
                    var newPeers: [TorrentPeer] = []
                    if let added = Bencode.asBytes(Bencode.lookup(d, "added")),
                       added.count % 6 == 0 {
                        var i = added.startIndex
                        while i < added.endIndex {
                            let ip = "\(added[i]).\(added[i+1]).\(added[i+2]).\(added[i+3])"
                            let port = (UInt16(added[i+4]) << 8) | UInt16(added[i+5])
                            if port > 0 { newPeers.append(TorrentPeer(ip: ip, port: port)) }
                            i = added.index(i, offsetBy: 6)
                        }
                    }
                    if let added6 = Bencode.asBytes(Bencode.lookup(d, "added6")),
                       added6.count % 18 == 0 {
                        var i = added6.startIndex
                        while i < added6.endIndex {
                            var parts: [String] = []
                            for k in 0..<8 {
                                let hi = added6[i + k * 2]
                                let lo = added6[i + k * 2 + 1]
                                parts.append(String(format: "%02x%02x", hi, lo))
                            }
                            let ip = "[" + parts.joined(separator: ":") + "]"
                            let port = (UInt16(added6[i + 16]) << 8) | UInt16(added6[i + 17])
                            if port > 0 { newPeers.append(TorrentPeer(ip: ip, port: port)) }
                            i = added6.index(i, offsetBy: 18)
                        }
                    }
                    if !newPeers.isEmpty { onPexPeers?(newPeers) }
                }
            }
            return .extended(extID, rest)
        default: return .other
        }
    }

    private func handle(msg: Message) throws {
        switch msg {
        case .choke:            chokingUs = true
        case .unchoke:          chokingUs = false
        case .interested:       peerInterested = true
        case .notInterested:    peerInterested = false
        case .have(let i):      peerHas?.set(Int(i))
        case .bitfield(let bf): peerHas = bf
        case .haveAll:          peerHas = BitSet.allSet(count: peerHas?.count ?? 0)
        case .haveNone:         peerHas = BitSet(count: peerHas?.count ?? 0)
        case .allowedFast(let p): allowedFast.insert(Int(p))
        case .keepalive, .piece, .cancel, .rejectRequest, .suggestPiece, .extended, .other:
            break
        }
    }

    // MARK: Outgoing

    private func sendSimple(id: UInt8) async throws {
        var d = Data()
        d.append(contentsOf: writeU32(1)); d.append(id)
        try await send(d)
    }

    private func sendRequest(index: Int32, begin: Int32, length: Int32) async throws {
        var d = Data()
        d.append(contentsOf: writeU32(13)); d.append(6)
        d.append(contentsOf: writeU32(UInt32(index)))
        d.append(contentsOf: writeU32(UInt32(begin)))
        d.append(contentsOf: writeU32(UInt32(length)))
        try await send(d)
    }

    private func sendExtended(id: UInt8, payload: Data) async throws {
        var d = Data()
        d.append(contentsOf: writeU32(UInt32(2 + payload.count)))
        d.append(20)
        d.append(id)
        d.append(payload)
        try await send(d)
    }

    // MARK: Low-level I/O

    private func send(_ data: Data) async throws {
        guard let c = conn else { throw WireError.transport("no connection") }
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: data, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: WireError.transport(e.localizedDescription)) }
                else { cont.resume() }
            })
        }
    }

    private var readBuffer = Data()

    private func readBytes(_ count: Int) async throws -> Data {
        while readBuffer.count < count {
            guard let c = conn else { throw WireError.transport("no connection") }
            let piece = try await withCheckedThrowingContinuation {
                (cont: CheckedContinuation<Data, Error>) in
                c.receive(minimumIncompleteLength: 1, maximumLength: 128 * 1024) { data, _, _, error in
                    if let e = error { cont.resume(throwing: WireError.transport(e.localizedDescription)); return }
                    cont.resume(returning: data ?? Data())
                }
            }
            if piece.isEmpty { throw WireError.peerClosed }
            readBuffer.append(piece)
        }
        let out = readBuffer.prefix(count)
        readBuffer = readBuffer.subdata(in: count..<readBuffer.count)
        return Data(out)
    }

    private func readU32(_ data: Data, _ offset: Int) -> UInt32 {
        let base = data.startIndex + offset
        return (UInt32(data[base]) << 24)
             | (UInt32(data[base + 1]) << 16)
             | (UInt32(data[base + 2]) << 8)
             |  UInt32(data[base + 3])
    }

    private func writeU32(_ v: UInt32) -> [UInt8] {
        [UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff),
         UInt8((v >> 8) & 0xff),  UInt8(v & 0xff)]
    }
}

/// Compact bitfield, one bit per piece.
struct BitSet {
    private(set) var bytes: Data
    let count: Int

    init(count: Int) {
        self.count = count
        self.bytes = Data(repeating: 0, count: (count + 7) / 8)
    }
    init(bytes: Data, count: Int) {
        self.count = count
        self.bytes = bytes
    }
    static func allSet(count: Int) -> BitSet {
        var b = BitSet(count: count)
        for i in 0..<((count + 7) / 8) { b.bytes[b.bytes.startIndex + i] = 0xff }
        return b
    }

    func isSet(_ index: Int) -> Bool {
        guard index >= 0, index < count else { return false }
        let byte = bytes[bytes.startIndex + (index / 8)]
        let bit = 7 - (index % 8)
        return (byte & (1 << bit)) != 0
    }

    mutating func set(_ index: Int) {
        guard index >= 0, index < count else { return }
        let i = bytes.startIndex + (index / 8)
        bytes[i] |= UInt8(1 << (7 - (index % 8)))
    }
}
