import Foundation
import Network

/// DNS-over-HTTPS resolver that performs the query *through a specific
/// interface*. Closes the leak where `NWConnection` uses the system resolver
/// (possibly egressing a different interface) even though the data-plane
/// socket is pinned via `requiredInterface`.
///
/// Uses the Cloudflare JSON-DoH endpoint (`https://1.1.1.1/dns-query`) with
/// `Accept: application/dns-json`. The 1.1.1.1 target is a literal IP so no
/// bootstrap DNS is needed.
///
/// Strictly best-effort: a caller should fall back to the system resolver
/// if this throws.
enum DoHResolver {

    struct Result {
        let ipv4: [String]
        let ipv6: [String]
        var first: String? { ipv4.first ?? ipv6.first }
    }

    enum DoHError: Error, LocalizedError {
        case transport(String)
        case badResponse
        case noAnswer

        var errorDescription: String? {
            switch self {
            case .transport(let s): return "DoH transport: \(s)"
            case .badResponse:      return "DoH: bad JSON response"
            case .noAnswer:         return "DoH: no answers"
            }
        }
    }

    /// Resolve `host` via Cloudflare 1.1.1.1 over a TCP+TLS connection pinned
    /// to `interface`. Prefer a single call per lane and cache the result for
    /// the lifetime of that lane.
    static func resolve(host: String, interface: NWInterface) async throws -> Result {
        async let a4: [String] = query(host: host, type: "A", interface: interface)
        async let a6: [String] = (try? await query(host: host, type: "AAAA", interface: interface)) ?? []
        let (v4, v6) = try await (a4, a6)
        if v4.isEmpty && v6.isEmpty { throw DoHError.noAnswer }
        return Result(ipv4: v4, ipv6: v6)
    }

    // MARK: Per-type query

    private static func query(host: String, type: String, interface: NWInterface) async throws -> [String] {
        let conn = try await open(interface: interface)
        defer { conn.cancel() }

        let path = "/dns-query?name=\(percent(host))&type=\(type)"
        let req =
            "GET \(path) HTTP/1.1\r\n" +
            "Host: 1.1.1.1\r\n" +
            "User-Agent: Splynek/0.1 (macOS)\r\n" +
            "Accept: application/dns-json\r\n" +
            "Connection: close\r\n" +
            "\r\n"
        try await send(conn, Data(req.utf8))
        let (status, body) = try await readResponse(conn)
        guard status == 200 else { throw DoHError.transport("HTTP \(status)") }
        guard let json = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let answers = json["Answer"] as? [[String: Any]] else {
            throw DoHError.badResponse
        }
        let wantedType = (type == "A") ? 1 : 28  // DNS RR types
        return answers.compactMap { rec in
            guard let t = rec["type"] as? Int, t == wantedType,
                  let data = rec["data"] as? String else { return nil }
            return data
        }
    }

    // MARK: Connection

    private static func open(interface: NWInterface) async throws -> NWConnection {
        let params: NWParameters = .tls
        params.requiredInterface = interface
        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host("1.1.1.1"),
            port: NWEndpoint.Port(integerLiteral: 443)
        )
        let conn = NWConnection(to: endpoint, using: params)

        return try await withCheckedThrowingContinuation {
            (cont: CheckedContinuation<NWConnection, Error>) in
            let gate = ResumeGate()
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready:     if gate.fire() { cont.resume(returning: conn) }
                case .failed(let e):
                    if gate.fire() { cont.resume(throwing: DoHError.transport(e.localizedDescription)) }
                case .cancelled:
                    if gate.fire() { cont.resume(throwing: DoHError.transport("cancelled")) }
                default: break
                }
            }
            let queue = DispatchQueue(label: "splynek.doh.\(interface.name)")
            conn.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 8) {
                if gate.fire() {
                    conn.cancel()
                    cont.resume(throwing: DoHError.transport("connect timeout"))
                }
            }
        }
    }

    private static func send(_ c: NWConnection, _ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: data, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: DoHError.transport(e.localizedDescription)) }
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
            if piece.isEmpty { throw DoHError.transport("early EOF in headers") }
            buffer.append(piece)
            if let r = buffer.range(of: sentinel) { headerEnd = r.upperBound }
            if buffer.count > 64 * 1024 && headerEnd == nil { throw DoHError.badResponse }
        }
        let headerText = String(data: buffer.prefix(headerEnd!), encoding: .isoLatin1) ?? ""
        let statusLine = headerText.split(separator: "\r\n").first.map(String.init) ?? ""
        let parts = statusLine.split(separator: " ", maxSplits: 2).map(String.init)
        let status = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        var bodyLen: Int64 = Int64.max
        for line in headerText.split(separator: "\r\n").dropFirst() {
            let segs = line.split(separator: ":", maxSplits: 1).map(String.init)
            if segs.count == 2, segs[0].trimmingCharacters(in: .whitespaces).lowercased() == "content-length",
               let n = Int64(segs[1].trimmingCharacters(in: .whitespaces)) {
                bodyLen = n
            }
        }
        var body = Data(buffer.suffix(from: headerEnd!))
        while Int64(body.count) < bodyLen {
            let piece = try await recv(c, max: 32 * 1024)
            if piece.isEmpty { break }
            body.append(piece)
        }
        return (status, body)
    }

    private static func recv(_ c: NWConnection, max: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            c.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, error in
                if let e = error { cont.resume(throwing: DoHError.transport(e.localizedDescription)); return }
                cont.resume(returning: data ?? Data())
            }
        }
    }

    private static func percent(_ s: String) -> String {
        s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
    }
}
