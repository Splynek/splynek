import Foundation
import Network

/// HTTP(S) tracker announce sent over NWConnection, optionally pinned to a
/// specific interface. Same wire format as TrackerClient, but avoids
/// URLSession so tracker DNS/egress obey `requiredInterface` too.
enum HTTPTrackerOverNW {

    static func announce(
        _ p: TrackerClient.AnnounceParams,
        interface: NWInterface?
    ) async throws -> AnnounceResponse {
        guard let scheme = p.announceURL.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            throw TrackerError.unsupportedScheme(p.announceURL.scheme ?? "?")
        }
        guard let host = p.announceURL.host else { throw TrackerError.transport("no host") }
        let port = UInt16(p.announceURL.port ?? (scheme == "https" ? 443 : 80))
        var path = p.announceURL.path.isEmpty ? "/announce" : p.announceURL.path
        let qs = buildQueryString(p)
        path += (path.contains("?") ? "&" : "?") + qs

        let params: NWParameters = (scheme == "https") ? .tls : .tcp
        if let iface = interface { params.requiredInterface = iface }
        let conn = NWConnection(
            to: .hostPort(host: .init(host), port: .init(integerLiteral: port)),
            using: params
        )
        let q = DispatchQueue(label: "splynek.httptracker.\(host)")
        try await start(conn, q)
        defer { conn.cancel() }

        let defaultPort = (scheme == "https") ? UInt16(443) : UInt16(80)
        let hostHeader = port == defaultPort ? host : "\(host):\(port)"
        let req =
            "GET \(path) HTTP/1.1\r\n" +
            "Host: \(hostHeader)\r\n" +
            "User-Agent: Splynek/0.1 (macOS)\r\n" +
            "Accept: */*\r\n" +
            "Accept-Encoding: identity\r\n" +
            "Connection: close\r\n" +
            "\r\n"
        try await send(conn, Data(req.utf8))
        let (status, body) = try await readResponse(conn)
        guard status == 200 else { throw TrackerError.transport("HTTP \(status)") }
        return try parseResponse(body)
    }

    // MARK: Query string

    private static func buildQueryString(_ p: TrackerClient.AnnounceParams) -> String {
        var parts: [String] = []
        parts.append("info_hash=" + rawEncode(p.infoHash))
        parts.append("peer_id=" + rawEncode(p.peerID))
        parts.append("port=\(p.port)")
        parts.append("uploaded=\(p.uploaded)")
        parts.append("downloaded=\(p.downloaded)")
        parts.append("left=\(p.left)")
        parts.append("compact=1")
        parts.append("numwant=50")
        if let ev = p.event { parts.append("event=\(ev)") }
        return parts.joined(separator: "&")
    }

    private static func rawEncode(_ d: Data) -> String {
        let unreserved: Set<Character> = Set(
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789.-_~"
        )
        var out = ""
        for b in d {
            let ch = Character(UnicodeScalar(b))
            if unreserved.contains(ch) { out.append(ch) }
            else { out.append(String(format: "%%%02X", b)) }
        }
        return out
    }

    // MARK: Response parsing

    private static func parseResponse(_ data: Data) throws -> AnnounceResponse {
        let v = try Bencode.decode(data)
        guard case .dict(let d) = v else { throw TrackerError.badResponse("not a dict") }
        if let msg = Bencode.asString(Bencode.lookup(d, "failure reason")) {
            throw TrackerError.trackerFailure(msg)
        }
        let interval = Int(Bencode.asInt(Bencode.lookup(d, "interval")) ?? 1800)
        var peers: [TorrentPeer] = []
        if let compact = Bencode.asBytes(Bencode.lookup(d, "peers")), compact.count % 6 == 0 {
            var i = compact.startIndex
            while i < compact.endIndex {
                let ip = "\(compact[i]).\(compact[i+1]).\(compact[i+2]).\(compact[i+3])"
                let pp = (UInt16(compact[i+4]) << 8) | UInt16(compact[i+5])
                if pp > 0 { peers.append(TorrentPeer(ip: ip, port: pp)) }
                i = compact.index(i, offsetBy: 6)
            }
        }
        return AnnounceResponse(
            interval: interval, peers: peers,
            complete: Bencode.asInt(Bencode.lookup(d, "complete")).map(Int.init),
            incomplete: Bencode.asInt(Bencode.lookup(d, "incomplete")).map(Int.init)
        )
    }

    // MARK: Connection

    private static func start(_ c: NWConnection, _ q: DispatchQueue) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            c.stateUpdateHandler = { state in
                switch state {
                case .ready:    if gate.fire() { cont.resume() }
                case .failed(let e):
                    if gate.fire() { cont.resume(throwing: TrackerError.transport(e.localizedDescription)) }
                case .cancelled:
                    if gate.fire() { cont.resume(throwing: TrackerError.transport("cancelled")) }
                default: break
                }
            }
            c.start(queue: q)
            q.asyncAfter(deadline: .now() + 10) {
                if gate.fire() { c.cancel(); cont.resume(throwing: TrackerError.transport("connect timeout")) }
            }
        }
    }

    private static func send(_ c: NWConnection, _ d: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: d, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: TrackerError.transport(e.localizedDescription)) }
                else { cont.resume() }
            })
        }
    }

    private static func readResponse(_ c: NWConnection) async throws -> (Int, Data) {
        var buffer = Data()
        var headerEnd: Int? = nil
        let sentinel = Data("\r\n\r\n".utf8)
        while headerEnd == nil {
            let piece = try await recv(c, max: 16 * 1024)
            if piece.isEmpty { throw TrackerError.transport("early EOF") }
            buffer.append(piece)
            if let r = buffer.range(of: sentinel) { headerEnd = r.upperBound }
            if buffer.count > 128 * 1024 && headerEnd == nil {
                throw TrackerError.badResponse("headers too big")
            }
        }
        let headerText = String(data: buffer.prefix(headerEnd!), encoding: .isoLatin1) ?? ""
        let statusLine = headerText.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = statusLine.split(separator: " ", maxSplits: 2).map(String.init)
        let status = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var body = Data(buffer.suffix(from: headerEnd!))

        var contentLength: Int64 = -1
        for line in headerText.split(separator: "\r\n").dropFirst() {
            let segs = line.split(separator: ":", maxSplits: 1).map(String.init)
            if segs.count == 2, segs[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length",
               let n = Int64(segs[1].trimmingCharacters(in: .whitespaces)) {
                contentLength = n
            }
        }
        // If we don't know content length, read until close.
        while contentLength < 0 || Int64(body.count) < contentLength {
            let piece = try await recv(c, max: 32 * 1024)
            if piece.isEmpty { break }
            body.append(piece)
        }
        return (status, body)
    }

    private static func recv(_ c: NWConnection, max: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            c.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, error in
                if let e = error { cont.resume(throwing: TrackerError.transport(e.localizedDescription)); return }
                cont.resume(returning: data ?? Data())
            }
        }
    }
}
