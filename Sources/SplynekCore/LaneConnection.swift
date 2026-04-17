import Foundation
import Network

enum RangeError: Error, LocalizedError {
    case invalidURL
    case connectionFailed(String)
    case badStatus(Int, String)
    case prematureEOF
    /// 416 Range Not Satisfiable. The server is healthy but doesn't have
    /// the requested bytes (classic case: a fleet peer that hasn't yet
    /// downloaded this chunk). The engine treats this as a per-mirror
    /// failure — requeue the chunk, keep the lane alive, try a different
    /// URL — rather than a lane-health hit.
    case rangeNotAvailable

    var errorDescription: String? {
        switch self {
        case .invalidURL:                return "Invalid URL."
        case .connectionFailed(let s):   return "Connection failed: \(s)"
        case .badStatus(let s, let r):   return "HTTP \(s) \(r)"
        case .prematureEOF:              return "Server closed connection before body finished."
        case .rangeNotAvailable:         return "Range not available from this mirror."
        }
    }
}

/// Persistent HTTP/1.1 connection pinned to a single NWInterface.
///
/// `NWParameters.requiredInterface` is Apple's public wrapper around
/// `IP_BOUND_IF` / `IPV6_BOUND_IF`, so the kernel enforces egress on the
/// chosen interface regardless of routing-table state.
///
/// This class reuses the TCP+TLS session across multiple Range requests.
/// The fetch loop sends keep-alive requests and auto-reopens the connection
/// if the server hangs up. That saves a TLS handshake per chunk after the
/// first — on chunk-heavy workloads this is a real throughput win.
final class LaneConnection {

    let url: URL
    let interface: NWInterface
    let bandwidth: TokenBucket
    let useDoH: Bool
    /// Extra request headers applied to every GET (e.g. Authorization,
    /// Referer, API tokens).
    let extraHeaders: [String: String]
    private let dispatchQueue: DispatchQueue
    private var conn: NWConnection?
    private let cancelFlag: CancelFlag
    /// Cached DoH lookup result for this lane's hostname.
    private var resolvedIP: String?
    /// Callback fired once per successful connect with the peer IP we
    /// actually landed on. Used by DownloadEngine to populate
    /// `LaneStats.connectedTo`, which the UI shows as a "Peer" column —
    /// our connection-path-transparency signal.
    var onConnected: ((String) -> Void)?

    init(url: URL, interface: NWInterface, bandwidth: TokenBucket,
         cancelFlag: CancelFlag, useDoH: Bool = false,
         extraHeaders: [String: String] = [:]) {
        self.url = url
        self.interface = interface
        self.bandwidth = bandwidth
        self.cancelFlag = cancelFlag
        self.useDoH = useDoH
        self.extraHeaders = extraHeaders
        self.dispatchQueue = DispatchQueue(label: "splynek.lane.\(interface.name)")
    }

    /// Merge URL-userinfo (https://user:pass@host/...) + explicit headers +
    /// defaults into a final `Name: Value` header block. The auth header
    /// supplied via `extraHeaders` wins over the URL's inline credentials,
    /// so a caller can override explicitly.
    private func effectiveHeaders(hostHeader: String, range: String) -> [(String, String)] {
        var out: [(String, String)] = [
            ("Host", hostHeader),
            ("User-Agent", "Splynek/0.1 (macOS)"),
            ("Accept", "*/*"),
            ("Accept-Encoding", "identity"),
            ("Range", range),
            ("Connection", "keep-alive")
        ]
        if let user = url.user, let pass = url.password {
            let token = "\(user):\(pass)".data(using: .utf8)?.base64EncodedString() ?? ""
            out.append(("Authorization", "Basic \(token)"))
        }
        for (k, v) in extraHeaders {
            // Drop any duplicate (case-insensitive) to let extraHeaders win.
            out.removeAll { $0.0.lowercased() == k.lowercased() }
            out.append((k, v))
        }
        return out
    }

    /// Fetch `[start, end]` inclusive. `onBytes` is called per received piece.
    /// `onRTT`, if set, is invoked once per request with the measured time
    /// from send(request) to first body byte — our best approximation of
    /// round-trip latency (plus server first-byte processing time).
    /// Returns total body bytes streamed. On transport failures we try one
    /// reconnect before giving up.
    func fetch(
        start: Int64,
        end: Int64,
        onBytes: @escaping (Data) -> Void,
        onRTT: ((TimeInterval) -> Void)? = nil
    ) async throws -> Int64 {
        var lastError: Error?
        for attempt in 0..<2 {
            do {
                if conn == nil { try await openConnection() }
                return try await executeRequest(
                    start: start, end: end,
                    onBytes: onBytes, onRTT: onRTT
                )
            } catch RangeError.rangeNotAvailable {
                // 416 is a semantic "this mirror can't serve THIS chunk"
                // signal, not a transport failure. Leave the keep-alive
                // connection intact so the next chunk request can reuse
                // it, and bubble up for the engine's per-mirror rotation.
                throw RangeError.rangeNotAvailable
            } catch RangeError.prematureEOF where attempt == 0 {
                closeConnection()
                lastError = RangeError.prematureEOF
                continue
            } catch RangeError.connectionFailed where attempt == 0 {
                closeConnection()
                lastError = RangeError.connectionFailed("reconnect")
                continue
            } catch {
                closeConnection()
                throw error
            }
        }
        throw lastError ?? RangeError.prematureEOF
    }

    func close() { closeConnection() }

    // MARK: Connection lifecycle

    private func openConnection() async throws {
        guard let host = url.host, !host.isEmpty else { throw RangeError.invalidURL }
        let scheme = url.scheme ?? "http"
        let port = UInt16(url.port ?? (scheme == "https" ? 443 : 80))

        // Optionally resolve via DoH, pinned to this lane's interface, so the
        // DNS query egresses the same NIC as the data. Cached for subsequent
        // reconnects within this lane.
        var endpointHost: String = host
        if useDoH {
            if resolvedIP == nil {
                if let result = try? await DoHResolver.resolve(host: host, interface: interface),
                   let ip = result.first {
                    resolvedIP = ip
                }
            }
            if let ip = resolvedIP { endpointHost = ip }
        }

        let params: NWParameters = (scheme == "https") ? .tls : .tcp
        params.requiredInterface = interface
        params.prohibitedInterfaceTypes = []

        // If we resolved to a literal IP but still need TLS SNI / cert
        // hostname verification to target the original host, override SNI.
        if scheme == "https", endpointHost != host {
            if let tlsOpts = (params.defaultProtocolStack.applicationProtocols
                .compactMap { $0 as? NWProtocolTLS.Options }).first {
                sec_protocol_options_set_tls_server_name(
                    tlsOpts.securityProtocolOptions, host
                )
            }
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(endpointHost),
            port: NWEndpoint.Port(integerLiteral: port)
        )
        let c = NWConnection(to: endpoint, using: params)
        conn = c
        cancelFlag.onCancel { [weak c] in c?.cancel() }

        try await withTimeout(seconds: 15) {
            try await self.waitForReady(c)
        } onTimeout: {
            c.cancel()
        }
        // Transparency: report the actual peer we landed on. DoH + Happy
        // Eyeballs can route us to different IPs than the OS would have
        // chosen, and this closure surfaces that to the UI per lane.
        if let onConnected {
            let peer = Self.remoteIP(of: c) ?? endpointHost
            onConnected(peer)
        }
    }

    private static func remoteIP(of conn: NWConnection) -> String? {
        if case let .hostPort(host, _) = conn.currentPath?.remoteEndpoint ?? conn.endpoint {
            switch host {
            case .ipv4(let a): return "\(a)"
            case .ipv6(let a): return "\(a)"
            default:           return nil
            }
        }
        return nil
    }

    private func closeConnection() {
        conn?.cancel()
        conn = nil
    }

    private func waitForReady(_ c: NWConnection) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            let gate = ResumeGate()
            c.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    if gate.fire() { cont.resume() }
                case .failed(let err):
                    if gate.fire() {
                        cont.resume(throwing: RangeError.connectionFailed(err.localizedDescription))
                    }
                case .cancelled:
                    if gate.fire() {
                        cont.resume(throwing: RangeError.connectionFailed("cancelled"))
                    }
                default: break
                }
            }
            c.start(queue: dispatchQueue)
        }
    }

    // MARK: Per-request

    private func executeRequest(
        start: Int64,
        end: Int64,
        onBytes: @escaping (Data) -> Void,
        onRTT: ((TimeInterval) -> Void)? = nil
    ) async throws -> Int64 {
        guard let c = conn else { throw RangeError.connectionFailed("no connection") }
        guard let host = url.host else { throw RangeError.invalidURL }

        let scheme = url.scheme ?? "http"
        let port = UInt16(url.port ?? (scheme == "https" ? 443 : 80))
        let defaultPort = (scheme == "https") ? UInt16(443) : UInt16(80)
        let hostHeader = (port == defaultPort) ? host : "\(host):\(port)"

        var path = url.path.isEmpty ? "/" : url.path
        if let q = url.query, !q.isEmpty { path += "?" + q }

        let requestHeaders = effectiveHeaders(
            hostHeader: hostHeader, range: "bytes=\(start)-\(end)"
        )
        var req = "GET \(path) HTTP/1.1\r\n"
        for (k, v) in requestHeaders { req += "\(k): \(v)\r\n" }
        req += "\r\n"
        try await send(c, data: Data(req.utf8))
        let sentAt = Date()
        var firstByteReported = false

        // Read headers
        var buffer = Data()
        var headerEnd: Int? = nil
        let sentinel = Data("\r\n\r\n".utf8)
        while headerEnd == nil {
            if cancelFlag.isCancelled { return 0 }
            let piece = try await receive(c, max: 16 * 1024)
            if piece.isEmpty { throw RangeError.prematureEOF }
            buffer.append(piece)
            if let r = buffer.range(of: sentinel) { headerEnd = r.upperBound }
            if buffer.count > 64 * 1024 && headerEnd == nil {
                throw RangeError.badStatus(0, "headers exceed 64 KiB")
            }
        }
        let headerData = buffer.prefix(headerEnd!)
        let bodyPrefix = buffer.suffix(from: headerEnd!)
        guard let headerText = String(data: headerData, encoding: .isoLatin1) else {
            throw RangeError.badStatus(0, "headers not latin1-decodable")
        }
        let (status, reason, headers) = parseHeaders(headerText)
        if status == 416 {
            // Drain the body (usually empty, but servers can send a
            // short explanation) so we can reuse the keep-alive conn.
            let bodyLen = Int64(headers["content-length"].flatMap(Int64.init) ?? 0)
            var drained: Int64 = 0
            if !bodyPrefix.isEmpty {
                drained = min(Int64(bodyPrefix.count), bodyLen)
            }
            while drained < bodyLen {
                let piece = try await receive(c, max: Int(bodyLen - drained))
                if piece.isEmpty { break }
                drained += Int64(piece.count)
            }
            throw RangeError.rangeNotAvailable
        }
        guard status == 200 || status == 206 else {
            throw RangeError.badStatus(status, reason)
        }
        let contentLength: Int64? = headers["content-length"].flatMap { Int64($0) }
        let expected = end - start + 1
        var remaining = contentLength ?? expected
        var streamed: Int64 = 0

        if !bodyPrefix.isEmpty {
            let take = min(Int64(bodyPrefix.count), remaining)
            let slice = bodyPrefix.prefix(Int(take))
            if !firstByteReported {
                onRTT?(Date().timeIntervalSince(sentAt))
                firstByteReported = true
            }
            onBytes(Data(slice))
            streamed += Int64(slice.count)
            remaining -= Int64(slice.count)
        }

        let isCellular = (interface.type == .cellular)
        let usageHost = url.host
        while remaining > 0 {
            if cancelFlag.isCancelled { break }
            let cap = min(Int(remaining), 64 * 1024)
            await bandwidth.take(Int64(cap))
            let piece = try await receive(c, max: cap)
            if piece.isEmpty { break }
            if !firstByteReported {
                onRTT?(Date().timeIntervalSince(sentAt))
                firstByteReported = true
            }
            onBytes(piece)
            streamed += Int64(piece.count)
            remaining -= Int64(piece.count)
            let n = Int64(piece.count)
            if isCellular { CellularBudget.add(n) }
            HostUsage.credit(host: usageHost, bytes: n)
        }

        if streamed < expected && !cancelFlag.isCancelled {
            throw RangeError.prematureEOF
        }
        return streamed
    }

    // MARK: Low-level send / receive

    private func send(_ c: NWConnection, data: Data) async throws {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            c.send(content: data, completion: .contentProcessed { error in
                if let e = error { cont.resume(throwing: e) } else { cont.resume() }
            })
        }
    }

    private func receive(_ c: NWConnection, max: Int) async throws -> Data {
        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data, Error>) in
            c.receive(minimumIncompleteLength: 1, maximumLength: max) { data, _, _, error in
                if let e = error { cont.resume(throwing: e); return }
                cont.resume(returning: data ?? Data())
            }
        }
    }

    private func parseHeaders(_ text: String) -> (Int, String, [String: String]) {
        var lines = text.split(separator: "\r\n", omittingEmptySubsequences: false).map(String.init)
        guard let statusLine = lines.first else { return (0, "", [:]) }
        lines.removeFirst()
        let parts = statusLine.split(separator: " ", maxSplits: 2).map(String.init)
        let status = parts.count > 1 ? Int(parts[1]) ?? 0 : 0
        let reason = parts.count > 2 ? parts[2] : ""
        var headers: [String: String] = [:]
        for line in lines where !line.isEmpty {
            if let colon = line.firstIndex(of: ":") {
                let name = line[..<colon].trimmingCharacters(in: .whitespaces).lowercased()
                let value = line[line.index(after: colon)...].trimmingCharacters(in: .whitespaces)
                headers[name] = value
            }
        }
        return (status, reason, headers)
    }

    // MARK: Timeout utility

    private func withTimeout(
        seconds: Double,
        body: @escaping @Sendable () async throws -> Void,
        onTimeout: @escaping @Sendable () -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            group.addTask { try await body() }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                onTimeout()
                throw RangeError.connectionFailed("connect timeout after \(Int(seconds))s")
            }
            defer { group.cancelAll() }
            try await group.next()
        }
    }
}
