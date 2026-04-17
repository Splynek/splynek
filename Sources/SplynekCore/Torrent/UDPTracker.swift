import Foundation
import Network

/// BEP 15 — UDP tracker protocol.
///
/// Two-step dance: connect (get a connection id valid for ~2 min) then
/// announce. Response formats are defined bit-for-bit in BEP 15.
/// No retransmission schedule (the BEP mandates n*15s backoff); we do one
/// round with a 5-second timeout and fail through.
enum UDPTracker {

    struct AnnounceParams {
        let announceURL: URL
        let infoHash: Data
        let peerID: Data
        let port: UInt16
        let uploaded: Int64
        let downloaded: Int64
        let left: Int64
        let event: Event
    }
    enum Event: Int32 { case none = 0, completed = 1, started = 2, stopped = 3 }

    enum UDPError: Error, LocalizedError {
        case transport(String)
        case badResponse(String)
        case timeout
        case trackerError(String)

        var errorDescription: String? {
            switch self {
            case .transport(let s):     return "UDP tracker: \(s)"
            case .badResponse(let s):   return "UDP tracker: \(s)"
            case .timeout:              return "UDP tracker: timeout"
            case .trackerError(let s):  return "UDP tracker error: \(s)"
            }
        }
    }

    static func announce(_ p: AnnounceParams, interface: NWInterface? = nil) async throws -> AnnounceResponse {
        guard let host = p.announceURL.host,
              let port = p.announceURL.port.map(UInt16.init) ?? nil else {
            throw UDPError.transport("URL missing host/port")
        }

        let params: NWParameters = .udp
        if let iface = interface { params.requiredInterface = iface }
        let conn = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integerLiteral: port)),
            using: params
        )
        let q = DispatchQueue(label: "splynek.udptracker")
        try await startConn(conn, on: q)
        defer { conn.cancel() }

        // Connect request: magic 0x41727101980 + action=0 + random transaction
        let txn1 = UInt32.random(in: 0..<UInt32.max)
        var conRequest = Data()
        conRequest.append(writeU64(0x41727101980))     // protocol magic
        conRequest.append(writeU32(0))                 // action=connect
        conRequest.append(writeU32(txn1))
        try await sendUDP(conn, conRequest)

        let conResp = try await recvUDP(conn, timeout: 5)
        guard conResp.count >= 16 else { throw UDPError.badResponse("connect response too short") }
        let respAction = readU32(conResp, 0)
        let respTxn = readU32(conResp, 4)
        guard respAction == 0, respTxn == txn1 else {
            throw UDPError.badResponse("connect mismatch action=\(respAction) txn=\(respTxn)")
        }
        let connectionID = conResp.subdata(in: 8..<16)

        // Announce
        let txn2 = UInt32.random(in: 0..<UInt32.max)
        var ann = Data()
        ann.append(connectionID)
        ann.append(writeU32(1))                        // action=announce
        ann.append(writeU32(txn2))
        ann.append(p.infoHash)
        ann.append(p.peerID)
        ann.append(writeU64Signed(p.downloaded))
        ann.append(writeU64Signed(p.left))
        ann.append(writeU64Signed(p.uploaded))
        ann.append(writeU32Signed(p.event.rawValue))
        ann.append(writeU32(0))                        // ip (let tracker infer)
        ann.append(writeU32(UInt32.random(in: 0..<UInt32.max))) // key
        ann.append(writeU32Signed(-1))                 // num_want default
        ann.append(writeU16(p.port))
        try await sendUDP(conn, ann)

        let annResp = try await recvUDP(conn, timeout: 5)
        guard annResp.count >= 20 else { throw UDPError.badResponse("announce response too short") }
        let a2 = readU32(annResp, 0)
        let t2 = readU32(annResp, 4)
        if a2 == 3 {
            let msg = String(data: annResp.subdata(in: 8..<annResp.count), encoding: .utf8) ?? ""
            throw UDPError.trackerError(msg)
        }
        guard a2 == 1, t2 == txn2 else {
            throw UDPError.badResponse("announce mismatch action=\(a2) txn=\(t2)")
        }
        let interval = Int(readU32(annResp, 8))
        let leechers = Int(readU32(annResp, 12))
        let seeders = Int(readU32(annResp, 16))

        var peers: [TorrentPeer] = []
        var i = 20
        while i + 6 <= annResp.count {
            let ip = "\(annResp[i]).\(annResp[i + 1]).\(annResp[i + 2]).\(annResp[i + 3])"
            let pport = (UInt16(annResp[i + 4]) << 8) | UInt16(annResp[i + 5])
            if pport > 0 { peers.append(TorrentPeer(ip: ip, port: pport)) }
            i += 6
        }
        return AnnounceResponse(interval: interval, peers: peers,
                                complete: seeders, incomplete: leechers)
    }

    // MARK: NWConnection helpers

    private static func startConn(_ conn: NWConnection, on queue: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:   if gate.fire() { cont.resume() }
                case .failed(let e):
                    if gate.fire() { cont.resume(throwing: UDPError.transport(e.localizedDescription)) }
                case .cancelled:
                    if gate.fire() { cont.resume(throwing: UDPError.transport("cancelled")) }
                default: break
                }
            }
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 5) {
                if gate.fire() {
                    conn.cancel(); cont.resume(throwing: UDPError.timeout)
                }
            }
        }
    }

    private static func sendUDP(_ c: NWConnection, _ d: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: d, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: UDPError.transport(e.localizedDescription)) }
                else { cont.resume() }
            })
        }
    }

    private static func recvUDP(_ c: NWConnection, timeout: Double) async throws -> Data {
        try await withThrowingTaskGroup(of: Data.self) { group in
            group.addTask {
                try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
                    c.receiveMessage { data, _, _, error in
                        if let e = error { cont.resume(throwing: UDPError.transport(e.localizedDescription)); return }
                        cont.resume(returning: data ?? Data())
                    }
                }
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw UDPError.timeout
            }
            defer { group.cancelAll() }
            return try await group.next() ?? Data()
        }
    }

    // MARK: Binary helpers

    private static func writeU16(_ v: UInt16) -> Data {
        Data([UInt8((v >> 8) & 0xff), UInt8(v & 0xff)])
    }
    private static func writeU32(_ v: UInt32) -> Data {
        Data([UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff),
              UInt8((v >> 8) & 0xff), UInt8(v & 0xff)])
    }
    private static func writeU32Signed(_ v: Int32) -> Data { writeU32(UInt32(bitPattern: v)) }
    private static func writeU64(_ v: UInt64) -> Data {
        var out = Data(count: 8)
        for i in 0..<8 { out[i] = UInt8((v >> (56 - i * 8)) & 0xff) }
        return out
    }
    private static func writeU64Signed(_ v: Int64) -> Data { writeU64(UInt64(bitPattern: v)) }

    private static func readU32(_ d: Data, _ off: Int) -> UInt32 {
        let b = d.startIndex + off
        return (UInt32(d[b]) << 24) | (UInt32(d[b + 1]) << 16) |
               (UInt32(d[b + 2]) << 8) |  UInt32(d[b + 3])
    }
}
