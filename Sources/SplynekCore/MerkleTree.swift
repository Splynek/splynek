import Foundation
import CryptoKit

/// Per-chunk SHA-256 Merkle tree used for incremental integrity verification
/// of HTTP downloads.
///
/// Why: today we compute SHA-256 at the end of the download. If the hash
/// doesn't match, the whole file must be re-downloaded. A Merkle tree over
/// chunks lets us verify each chunk as it lands and re-fetch just the bad
/// one.
///
/// Hash layout (RFC 6962-style, binary tree, duplicate-last-leaf for odd
/// counts):
///   leaf_i   = SHA256(0x00 || chunk_i)
///   inner_ab = SHA256(0x01 || left || right)
///   root     = the apex
///
/// The consumer ships two things: a sidecar manifest (per-chunk leaf hashes,
/// published with the file) and the expected root. Splynek verifies leaves
/// inline and then proves them against the root.
enum MerkleTree {

    static func leafHash(_ data: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: Data([0x00]))
        hasher.update(data: data)
        return Data(hasher.finalize())
    }

    static func pairHash(_ a: Data, _ b: Data) -> Data {
        var hasher = SHA256()
        hasher.update(data: Data([0x01]))
        hasher.update(data: a)
        hasher.update(data: b)
        return Data(hasher.finalize())
    }

    /// Compute the Merkle root of an array of leaf hashes (not raw data).
    static func root(leaves: [Data]) -> Data {
        guard !leaves.isEmpty else { return Data(count: 32) }
        var level = leaves
        while level.count > 1 {
            var next: [Data] = []
            next.reserveCapacity((level.count + 1) / 2)
            var i = 0
            while i < level.count {
                let l = level[i]
                let r = (i + 1 < level.count) ? level[i + 1] : l
                next.append(pairHash(l, r))
                i += 2
            }
            level = next
        }
        return level[0]
    }

    /// Produce a Merkle proof for index `i` against `leaves`.
    /// The proof is a sequence of (siblingHash, isSiblingOnRight) pairs.
    static func proof(forIndex i: Int, leaves: [Data]) -> [(sibling: Data, siblingRight: Bool)] {
        var out: [(Data, Bool)] = []
        var level = leaves
        var idx = i
        while level.count > 1 {
            let partnerIdx = (idx % 2 == 0) ? idx + 1 : idx - 1
            let siblingIdx = min(partnerIdx, level.count - 1)
            let siblingRight = partnerIdx > idx
            out.append((level[siblingIdx], siblingRight))
            var next: [Data] = []
            var j = 0
            while j < level.count {
                let l = level[j]
                let r = (j + 1 < level.count) ? level[j + 1] : l
                next.append(pairHash(l, r))
                j += 2
            }
            level = next
            idx /= 2
        }
        return out
    }

    /// Verify a single leaf hash against a root given its proof.
    static func verify(leaf: Data, proof: [(sibling: Data, siblingRight: Bool)],
                       expectedRoot: Data) -> Bool {
        var cur = leaf
        for step in proof {
            cur = step.siblingRight
                ? pairHash(cur, step.sibling)
                : pairHash(step.sibling, cur)
        }
        return cur == expectedRoot
    }
}

/// Sidecar format written alongside a download when Merkle integrity is used.
/// Also accepted as input (if the user has a .splynekmerkle next to the URL).
struct MerkleManifest: Codable {
    var version: Int = 1
    var chunkSize: Int64
    var totalBytes: Int64
    /// Hex-encoded leaf hashes, one per chunk, in order.
    var leafHexes: [String]
    /// Hex-encoded root hash.
    var rootHex: String

    var leafHashes: [Data] {
        leafHexes.compactMap { Data(hexEncoded: $0) }
    }
}

// MARK: Publisher

/// Build a `MerkleManifest` describing a file on disk. Used by the
/// "Publish Splynek manifest" tool: chunks the file at the same
/// 4 MiB boundary the engine uses, SHA-256-leaves each chunk, computes
/// the root. The resulting JSON can be served next to the file and
/// consumed by another Splynek install for inline per-chunk verification.
enum MerklePublisher {
    static let chunkSize: Int64 = 4 * 1024 * 1024

    enum PublishError: Error, LocalizedError {
        case cantOpen(String)

        var errorDescription: String? {
            switch self {
            case .cantOpen(let s): return "Can't read file: \(s)"
            }
        }
    }

    static func manifest(for fileURL: URL) throws -> MerkleManifest {
        let handle: FileHandle
        do { handle = try FileHandle(forReadingFrom: fileURL) }
        catch { throw PublishError.cantOpen(error.localizedDescription) }
        defer { try? handle.close() }

        var leafHexes: [String] = []
        var total: Int64 = 0
        while true {
            let chunk = (try? handle.read(upToCount: Int(chunkSize))) ?? Data()
            if chunk.isEmpty { break }
            leafHexes.append(MerkleTree.leafHash(chunk).hexEncodedString)
            total += Int64(chunk.count)
            if Int64(chunk.count) < chunkSize { break }
        }
        let leaves = leafHexes.compactMap { Data(hexEncoded: $0) }
        let rootHex = MerkleTree.root(leaves: leaves).hexEncodedString
        return MerkleManifest(
            chunkSize: chunkSize,
            totalBytes: total,
            leafHexes: leafHexes,
            rootHex: rootHex
        )
    }
}

extension Data {
    init?(hexEncoded hex: String) {
        let s = hex.filter { !$0.isWhitespace }
        guard s.count % 2 == 0 else { return nil }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(s.count / 2)
        var idx = s.startIndex
        while idx < s.endIndex {
            let next = s.index(idx, offsetBy: 2)
            guard let b = UInt8(s[idx..<next], radix: 16) else { return nil }
            bytes.append(b)
            idx = next
        }
        self.init(bytes)
    }

    var hexEncodedString: String {
        map { String(format: "%02x", $0) }.joined()
    }
}
