import Foundation
import Network
import CryptoKit

/// A tiny, read-mostly DHT server. Responds to the four query types other
/// nodes might send us:
///
///   - `ping`           → {id}
///   - `find_node`      → {id, nodes}
///   - `get_peers`      → {id, token, values | nodes}
///   - `announce_peer`  → (token-validate, cache peer) {id}
///
/// Not implemented:
///   - Real Kademlia routing buckets — our `knownNodes` is a flat bag.
///   - Token rotation secret refresh on a timer (we use a per-process secret).
///
/// Purpose: make Splynek a well-behaved DHT citizen rather than a pure
/// leech. The bag of known nodes also doubles as an additional bootstrap
/// source for the `DHT` client.
final class DHTServer {

    let ourNodeID: Data
    let interface: NWInterface
    /// Announce_peer cache, keyed by info hash → observed peers (ip, port, ts).
    private var announced: [Data: [(String, UInt16, Date)]] = [:]
    /// Simple bag of nodes we've seen, trimmed to recent-most 512.
    private var knownNodes: [(id: Data, ip: String, port: UInt16)] = []
    /// Per-process token secret; used to HMAC client ip→token so we can
    /// validate announce_peer without storing per-client state.
    private let tokenSecret: Data
    private var listener: NWListener?
    private var running = false
    private let lock = NSLock()

    init(ourNodeID: Data, interface: NWInterface) {
        self.ourNodeID = ourNodeID
        self.interface = interface
        var seed = Data(count: 16)
        for i in 0..<16 { seed[i] = UInt8.random(in: 0...255) }
        self.tokenSecret = seed
    }

    var boundPort: UInt16 { UInt16(truncatingIfNeeded: listener?.port?.rawValue ?? 0) }

    func start() throws {
        guard !running else { return }
        let params = NWParameters.udp
        params.requiredInterface = interface
        let l = try NWListener(using: params)
        l.newConnectionHandler = { [weak self] conn in
            conn.start(queue: DispatchQueue(label: "splynek.dht.server.conn"))
            self?.receive(on: conn)
        }
        l.start(queue: DispatchQueue(label: "splynek.dht.server"))
        self.listener = l
        self.running = true
    }

    func stop() {
        listener?.cancel()
        listener = nil
        running = false
    }

    // MARK: Per-datagram

    private func receive(on conn: NWConnection) {
        conn.receiveMessage { [weak self, weak conn] data, _, _, _ in
            guard let self, let conn, let data, !data.isEmpty else {
                conn?.cancel(); return
            }
            let reply = self.process(datagram: data, from: conn)
            if let reply {
                conn.send(content: reply, completion: .contentProcessed { _ in
                    conn.cancel()
                })
            } else {
                conn.cancel()
            }
        }
    }

    private func process(datagram: Data, from conn: NWConnection) -> Data? {
        guard let v = try? Bencode.decode(datagram), case .dict(let d) = v,
              case .bytes(let y)? = Bencode.lookup(d, "y") else { return nil }
        guard let txn = Bencode.asBytes(Bencode.lookup(d, "t")) else { return nil }

        if y == Data("q".utf8) {
            // It's a query
            guard case .bytes(let q)? = Bencode.lookup(d, "q"),
                  let qName = String(data: q, encoding: .utf8),
                  case .dict(let args)? = Bencode.lookup(d, "a") else {
                return errorReply(txn: txn, code: 203, message: "bad query")
            }
            // Learn the sender if they included an id.
            if case .bytes(let sid)? = Bencode.lookup(args, "id"), sid.count == 20 {
                recordNode(id: sid, conn: conn)
            }
            switch qName {
            case "ping":
                return okReply(txn: txn, r: [
                    Data("id".utf8): .bytes(ourNodeID)
                ])
            case "find_node":
                guard case .bytes(let target)? = Bencode.lookup(args, "target"),
                      target.count == 20 else {
                    return errorReply(txn: txn, code: 203, message: "need target")
                }
                return okReply(txn: txn, r: [
                    Data("id".utf8):    .bytes(ourNodeID),
                    Data("nodes".utf8): .bytes(compactNodes(closestTo: target, limit: 8))
                ])
            case "get_peers":
                guard case .bytes(let ih)? = Bencode.lookup(args, "info_hash"),
                      ih.count == 20 else {
                    return errorReply(txn: txn, code: 203, message: "need info_hash")
                }
                let token = generateToken(for: conn)
                var r: [Data: Bencode.Value] = [
                    Data("id".utf8):    .bytes(ourNodeID),
                    Data("token".utf8): .bytes(token)
                ]
                let peers = lookupAnnouncedPeers(for: ih)
                if !peers.isEmpty {
                    r[Data("values".utf8)] = .list(peers.map { peer -> Bencode.Value in
                        var b = Data()
                        for part in peer.0.split(separator: ".") {
                            b.append(UInt8(part) ?? 0)
                        }
                        b.append(UInt8((peer.1 >> 8) & 0xff))
                        b.append(UInt8(peer.1 & 0xff))
                        return .bytes(b)
                    })
                } else {
                    r[Data("nodes".utf8)] = .bytes(compactNodes(closestTo: ih, limit: 8))
                }
                return okReply(txn: txn, r: r)
            case "announce_peer":
                guard case .bytes(let ih)? = Bencode.lookup(args, "info_hash"),
                      ih.count == 20,
                      case .bytes(let token)? = Bencode.lookup(args, "token"),
                      validateToken(token, for: conn) else {
                    return errorReply(txn: txn, code: 203, message: "bad token")
                }
                let port = UInt16(Bencode.asInt(Bencode.lookup(args, "port")) ?? 0)
                if let ip = remoteIP(of: conn), port > 0 {
                    recordAnnounce(ih: ih, ip: ip, port: port)
                }
                return okReply(txn: txn, r: [Data("id".utf8): .bytes(ourNodeID)])
            default:
                return errorReply(txn: txn, code: 204, message: "method unknown")
            }
        }
        // Ignore responses / errors from others.
        return nil
    }

    // MARK: State

    private func recordNode(id: Data, conn: NWConnection) {
        guard let (ip, port) = remoteHostPort(of: conn), port > 0 else { return }
        lock.lock()
        knownNodes.append((id, ip, port))
        if knownNodes.count > 512 { knownNodes.removeFirst(knownNodes.count - 512) }
        lock.unlock()
    }

    private func recordAnnounce(ih: Data, ip: String, port: UInt16) {
        lock.lock()
        var list = announced[ih] ?? []
        // Drop stale entries (>30 min) and dedupe.
        let cutoff = Date().addingTimeInterval(-1800)
        list = list.filter { $0.2 >= cutoff && !($0.0 == ip && $0.1 == port) }
        list.append((ip, port, Date()))
        announced[ih] = list
        lock.unlock()
    }

    private func lookupAnnouncedPeers(for ih: Data) -> [(String, UInt16)] {
        lock.lock(); defer { lock.unlock() }
        let cutoff = Date().addingTimeInterval(-1800)
        return (announced[ih] ?? []).filter { $0.2 >= cutoff }.map { ($0.0, $0.1) }
    }

    private func compactNodes(closestTo target: Data, limit: Int) -> Data {
        lock.lock()
        let snap = knownNodes
        lock.unlock()
        let sorted = snap.sorted { DHT.xorLess($0.id, $1.id, target: target) }
        var out = Data()
        for n in sorted.prefix(limit) {
            out.append(n.id)
            for part in n.ip.split(separator: ".") {
                out.append(UInt8(part) ?? 0)
            }
            out.append(UInt8((n.port >> 8) & 0xff))
            out.append(UInt8(n.port & 0xff))
        }
        return out
    }

    // MARK: Tokens (stateless: HMAC over ip + secret, truncated)

    private func generateToken(for conn: NWConnection) -> Data {
        let ip = remoteIP(of: conn) ?? ""
        var hasher = SHA256()
        hasher.update(data: tokenSecret)
        hasher.update(data: Data(ip.utf8))
        return Data(hasher.finalize()).prefix(8)
    }

    private func validateToken(_ token: Data, for conn: NWConnection) -> Bool {
        generateToken(for: conn) == token
    }

    // MARK: Bencoded replies

    private func okReply(txn: Data, r: [Data: Bencode.Value]) -> Data {
        Bencode.encode(.dict([
            Data("t".utf8): .bytes(txn),
            Data("y".utf8): .bytes(Data("r".utf8)),
            Data("r".utf8): .dict(r)
        ]))
    }

    private func errorReply(txn: Data, code: Int, message: String) -> Data {
        Bencode.encode(.dict([
            Data("t".utf8): .bytes(txn),
            Data("y".utf8): .bytes(Data("e".utf8)),
            Data("e".utf8): .list([.integer(Int64(code)), .bytes(Data(message.utf8))])
        ]))
    }

    // MARK: Utility

    private func remoteIP(of conn: NWConnection) -> String? {
        remoteHostPort(of: conn)?.0
    }

    private func remoteHostPort(of conn: NWConnection) -> (String, UInt16)? {
        if case let .hostPort(host, port) = conn.endpoint {
            switch host {
            case .ipv4(let a): return ("\(a)", port.rawValue)
            case .ipv6(let a): return ("\(a)", port.rawValue)
            default: return nil
            }
        }
        return nil
    }
}
