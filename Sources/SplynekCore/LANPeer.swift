import Foundation
import Network

/// Bonjour-advertised LAN peering: once a Splynek user has downloaded a file,
/// they can opt to serve its byte ranges to other Splyneks on the same
/// network.
///
/// Service type: `_splynek._tcp`
/// TXT records:   content-hash = <sha256 hex of the file>,
///                filename      = <sanitised>,
///                size          = <bytes>
///
/// Discovery side (`LANPeerBrowser`) returns any peer that advertises the
/// hash we're looking for. Client code then fetches range-GETs from that
/// peer as another URL in the mirror list.
///
/// Intentional simplifications:
///   - HTTP/1.1 only between Splyneks (same engine, no new wire format)
///   - No authentication; peers are identified only by content hash
///   - No LAN-only enforcement beyond Bonjour scoping
///
/// Authentication is a real future concern — a LAN eavesdropper could
/// poison hashes they don't control. Mitigating options documented in
/// README (signed manifests, IPFS CID-based lookups).

/// TXT keys
enum LANPeerTXT {
    static let contentHash = "hash"
    static let filename    = "name"
    static let size        = "size"
}

/// Advertise a file we have on this host as available for LAN peers.
final class LANPeerAdvertiser {
    let listener: NWListener
    let port: UInt16
    let hash: String
    let filename: String
    let size: Int64
    let filePath: URL

    init(hash: String, filename: String, size: Int64, filePath: URL) throws {
        self.hash = hash
        self.filename = filename
        self.size = size
        self.filePath = filePath

        // Bind to any available port; we'll publish it via Bonjour.
        let listener = try NWListener(using: .tcp)
        self.listener = listener

        let txt: [String: String] = [
            LANPeerTXT.contentHash: hash,
            LANPeerTXT.filename:    filename,
            LANPeerTXT.size:        String(size)
        ]
        let record = NWTXTRecord(txt)
        listener.service = NWListener.Service(
            name: "Splynek-\(hash.prefix(8))",
            type: "_splynek._tcp",
            domain: nil,
            txtRecord: record.data
        )
        self.port = UInt16(truncatingIfNeeded: listener.port?.rawValue ?? 0)

        listener.newConnectionHandler = { [weak self] conn in
            self?.accept(conn)
        }
    }

    func start() {
        listener.start(queue: DispatchQueue(label: "splynek.lan.advertiser"))
    }

    func stop() {
        listener.cancel()
    }

    // MARK: Serving

    private func accept(_ conn: NWConnection) {
        let q = DispatchQueue(label: "splynek.lan.serve.\(UUID().uuidString.prefix(8))")
        conn.stateUpdateHandler = { state in
            if case .ready = state {
                Task { await self.serveHTTP(conn) }
            } else if case .failed = state {
                conn.cancel()
            }
        }
        conn.start(queue: q)
    }

    private func serveHTTP(_ conn: NWConnection) async {
        // Read a Range GET, respond with a 206 partial content.
        var buffer = Data()
        let sentinel = Data("\r\n\r\n".utf8)
        while buffer.range(of: sentinel) == nil, buffer.count < 8 * 1024 {
            guard let piece = try? await recv(conn, max: 4096), !piece.isEmpty else {
                conn.cancel(); return
            }
            buffer.append(piece)
        }
        guard let headerEnd = buffer.range(of: sentinel)?.upperBound,
              let headerText = String(data: buffer.prefix(headerEnd), encoding: .isoLatin1) else {
            conn.cancel(); return
        }
        var start: Int64 = 0
        var end: Int64 = size - 1
        for line in headerText.split(separator: "\r\n") {
            let lower = line.lowercased()
            if lower.hasPrefix("range:") {
                let value = line.dropFirst(6).trimmingCharacters(in: .whitespaces)
                if value.hasPrefix("bytes=") {
                    let spec = value.dropFirst(6)
                    let parts = spec.split(separator: "-", maxSplits: 1).map(String.init)
                    if parts.count >= 1, let s = Int64(parts[0]) { start = s }
                    if parts.count >= 2, let e = Int64(parts[1]) { end = e }
                }
            }
        }
        guard start >= 0, end < size, start <= end else {
            try? await send(conn, Data("HTTP/1.1 416 Range Not Satisfiable\r\nContent-Length: 0\r\nConnection: close\r\n\r\n".utf8))
            conn.cancel(); return
        }
        let length = end - start + 1
        let status = "HTTP/1.1 206 Partial Content\r\n"
        let headers =
            "Content-Type: application/octet-stream\r\n" +
            "Content-Length: \(length)\r\n" +
            "Content-Range: bytes \(start)-\(end)/\(size)\r\n" +
            "Connection: close\r\n\r\n"
        try? await send(conn, Data((status + headers).utf8))

        do {
            let handle = try FileHandle(forReadingFrom: filePath)
            defer { try? handle.close() }
            try handle.seek(toOffset: UInt64(start))
            var remaining = length
            while remaining > 0 {
                let take = Int(min(remaining, 64 * 1024))
                let chunk = try handle.read(upToCount: take) ?? Data()
                if chunk.isEmpty { break }
                try? await send(conn, chunk)
                remaining -= Int64(chunk.count)
            }
        } catch {
            // best effort
        }
        conn.cancel()
    }

    private func send(_ c: NWConnection, _ data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: data, completion: .contentProcessed { err in
                if let e = err { cont.resume(throwing: e) } else { cont.resume() }
            })
        }
    }

    private func recv(_ c: NWConnection, max: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            c.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, err in
                if let e = err { cont.resume(throwing: e); return }
                cont.resume(returning: data ?? Data())
            }
        }
    }
}

/// Browse LAN for Splynek advertisements and return URLs that serve the
/// requested content hash.
actor LANPeerBrowser {

    private var browser: NWBrowser?
    private var found: [URL] = []
    private var targetHash: String = ""

    func findPeers(for contentHash: String, timeout: TimeInterval) async -> [URL] {
        targetHash = contentHash.lowercased()
        found = []
        let params = NWParameters()
        params.includePeerToPeer = true
        let descriptor = NWBrowser.Descriptor.bonjourWithTXTRecord(
            type: "_splynek._tcp", domain: nil
        )
        let browser = NWBrowser(for: descriptor, using: params)
        self.browser = browser

        let gate = ResumeGate()
        return await withCheckedContinuation { (cont: CheckedContinuation<[URL], Never>) in
            browser.browseResultsChangedHandler = { results, _ in
                Task { [weak self] in
                    guard let self else { return }
                    let wanted = await self.getTargetHash()
                    for r in results {
                        if case let .service(name, _, _, _) = r.endpoint {
                            _ = name
                            if case .bonjour(let txt) = r.metadata,
                               let hash = txt[LANPeerTXT.contentHash],
                               hash.lowercased() == wanted {
                                if let url = await self.endpointToURL(r.endpoint) {
                                    await self.addURL(url)
                                }
                            }
                        }
                    }
                }
            }
            browser.start(queue: DispatchQueue(label: "splynek.lan.browser"))
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                Task { [weak self] in
                    guard let self else { cont.resume(returning: []); return }
                    let urls = await self.stop()
                    if gate.fire() { cont.resume(returning: urls) }
                }
            }
        }
    }

    private func addURL(_ url: URL) {
        if !found.contains(url) { found.append(url) }
    }

    private func getTargetHash() -> String { targetHash }

    private func endpointToURL(_ endpoint: NWEndpoint) async -> URL? {
        // Resolve the service endpoint by briefly opening an NWConnection
        // and reading the resolved host/port from currentPath.
        let conn = NWConnection(to: endpoint, using: .tcp)
        let gate = ResumeGate()
        return await withCheckedContinuation { (cont: CheckedContinuation<URL?, Never>) in
            conn.stateUpdateHandler = { state in
                switch state {
                case .ready, .waiting, .failed, .cancelled:
                    guard gate.fire() else { return }
                    let resolved: URL?
                    if case let .hostPort(host, port) = conn.currentPath?.remoteEndpoint ?? endpoint {
                        switch host {
                        case .ipv4(let a):
                            resolved = URL(string: "http://\(a):\(port.rawValue)/")
                        case .ipv6(let a):
                            resolved = URL(string: "http://[\(a)]:\(port.rawValue)/")
                        case .name(let n, _):
                            resolved = URL(string: "http://\(n):\(port.rawValue)/")
                        @unknown default:
                            resolved = nil
                        }
                    } else {
                        resolved = nil
                    }
                    conn.cancel()
                    cont.resume(returning: resolved)
                default: break
                }
            }
            conn.start(queue: DispatchQueue(label: "splynek.lan.resolve"))
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                if gate.fire() { conn.cancel(); cont.resume(returning: nil) }
            }
        }
    }

    private func stop() async -> [URL] {
        browser?.cancel()
        browser = nil
        return found
    }
}
