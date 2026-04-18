import Foundation

/// BEP 9 + BEP 52 magnet link parser. We pull out:
///   - `xt=urn:btih:…`  — classic v1 info hash (SHA-1, 20 bytes)
///   - `xt=urn:btmh:1220<64-hex>` — BEP 52 v2 info hash (SHA-256, 32 bytes).
///      The `1220` prefix is the multihash tag 0x12 = SHA-256, 0x20 = 32 bytes.
///   - `dn=…` display name, `tr=…` trackers, `ws=…` web seeds.
///
/// A magnet may carry both `xt` kinds (hybrid torrent) — we surface both
/// hashes so the engine can pick whichever swarm yields peers.
struct MagnetLink {
    /// Primary info hash used by v1 peer handshakes. For pure-v2 magnets this
    /// is the first 20 bytes of the SHA-256 info hash (the handshake field is
    /// 20 bytes wide; BEP 52 truncates).
    let infoHash: Data              // 20 bytes
    /// Full 32-byte SHA-256 v2 info hash, if the magnet advertises one.
    let infoHashV2: Data?
    let displayName: String?
    let trackers: [URL]
    let webSeeds: [URL]

    /// True iff the magnet carried a `urn:btmh:` field (implying v2 swarm).
    var isV2: Bool { infoHashV2 != nil }
}

enum MagnetError: Error, LocalizedError {
    case notMagnet
    case missingInfoHash
    case unsupportedHash(String)

    var errorDescription: String? {
        switch self {
        case .notMagnet:                return "Not a magnet: URI."
        case .missingInfoHash:          return "Magnet: missing xt=urn:btih:… info hash."
        case .unsupportedHash(let s):   return "Magnet: hash format not supported (\(s))."
        }
    }
}

enum Magnet {
    static func parse(_ uri: String) throws -> MagnetLink {
        guard uri.hasPrefix("magnet:?") else { throw MagnetError.notMagnet }
        let query = String(uri.dropFirst("magnet:?".count))
        var parts: [(String, String)] = []
        for pair in query.split(separator: "&") {
            let kv = pair.split(separator: "=", maxSplits: 1).map(String.init)
            if kv.count == 2 {
                // QA P2 #9 (v0.43): `application/x-www-form-urlencoded`
                // uses `+` for space. `removingPercentEncoding` only
                // handles `%20`, leaving magnet display names like
                // `Ubuntu+Test` with a literal `+`. Decode `+` → space
                // BEFORE percent-decoding so real `%2B` (an actual `+`
                // in the value) still round-trips correctly.
                let plusDecoded = kv[1].replacingOccurrences(of: "+", with: " ")
                parts.append((kv[0], plusDecoded.removingPercentEncoding ?? plusDecoded))
            }
        }

        var v1InfoHash: Data?
        var v2InfoHash: Data?
        var displayName: String?
        var trackers: [URL] = []
        var webSeeds: [URL] = []

        for (k, v) in parts {
            switch k {
            case "xt":
                if v.hasPrefix("urn:btih:") {
                    let suffix = String(v.dropFirst("urn:btih:".count))
                    if suffix.count == 40, let h = hexToData(suffix) {
                        v1InfoHash = h
                    } else if suffix.count == 32 {
                        // base32-encoded SHA-1 (less common)
                        if let h = base32ToData(suffix.uppercased()), h.count == 20 {
                            v1InfoHash = h
                        } else {
                            throw MagnetError.unsupportedHash("base32 decode failed")
                        }
                    } else {
                        throw MagnetError.unsupportedHash(suffix)
                    }
                } else if v.hasPrefix("urn:btmh:") {
                    // BEP 52 v2 multihash. We only accept the SHA-256 variant
                    // (`1220` prefix = 0x12 + 0x20 byte).
                    let rest = String(v.dropFirst("urn:btmh:".count))
                    guard rest.count == 4 + 64,
                          rest.hasPrefix("1220"),
                          let h = hexToData(String(rest.dropFirst(4))),
                          h.count == 32 else {
                        throw MagnetError.unsupportedHash("btmh: \(rest)")
                    }
                    v2InfoHash = h
                }
            case "dn":
                displayName = v
            case "tr":
                if let u = URL(string: v) { trackers.append(u) }
            case "ws":
                if let u = URL(string: v) { webSeeds.append(u) }
            default: break
            }
        }
        // Pick a primary 20-byte info hash for peer handshakes. v1 wins if
        // both present (hybrid swarm — v1 peers are still the majority in
        // 2026). Pure v2 magnets use the first 20 bytes of the SHA-256.
        let primary: Data?
        if let v1 = v1InfoHash {
            primary = v1
        } else if let v2 = v2InfoHash {
            primary = v2.prefix(20)
        } else {
            primary = nil
        }
        guard let ih = primary else { throw MagnetError.missingInfoHash }
        return MagnetLink(
            infoHash: ih,
            infoHashV2: v2InfoHash,
            displayName: displayName.map(Sanitize.filename),
            trackers: trackers,
            webSeeds: webSeeds
        )
    }

    private static func hexToData(_ hex: String) -> Data? {
        let cleaned = hex.replacingOccurrences(of: " ", with: "")
        guard cleaned.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(cleaned.count / 2)
        var idx = cleaned.startIndex
        while idx < cleaned.endIndex {
            let next = cleaned.index(idx, offsetBy: 2)
            guard let b = UInt8(cleaned[idx..<next], radix: 16) else { return nil }
            bytes.append(b)
            idx = next
        }
        return Data(bytes)
    }

    private static func base32ToData(_ s: String) -> Data? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        let map: [Character: UInt8] = Dictionary(uniqueKeysWithValues: alphabet.enumerated().map { ($1, UInt8($0)) })
        var bits: UInt64 = 0
        var bitCount = 0
        var out: [UInt8] = []
        for ch in s where ch != "=" {
            guard let v = map[ch] else { return nil }
            bits = (bits << 5) | UInt64(v)
            bitCount += 5
            if bitCount >= 8 {
                bitCount -= 8
                out.append(UInt8((bits >> bitCount) & 0xff))
            }
        }
        return Data(out)
    }
}
