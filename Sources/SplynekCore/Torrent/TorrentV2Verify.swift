import Foundation
import CryptoKit

/// BEP 52 piece verification.
///
/// Each v2 piece is verified by building a SHA-256 Merkle tree over the
/// piece's 16 KiB blocks and comparing the computed subtree root against
/// the corresponding 32-byte slot in the torrent's `piece layers` dict.
///
/// Block size is fixed at 16 KiB by BEP 52. Every piece length is a power
/// of two that's a multiple of 16 KiB, so each piece produces exactly
/// `pieceLength / 16384` leaves; a short final piece pads its leaves with
/// `SHA256(0x00 || zeros_16KiB)`-style balancers so the subtree shape matches
/// the layer hash (BEP 52 uses a zero-leaf pad, not duplicate-last).
///
/// For multi-file v2 torrents each file has its own pieces root and its own
/// per-file piece index space — globalPieceIndex ≠ fileLocalPieceIndex. The
/// caller maps the global piece to its (file, localIndex) before calling us.
enum TorrentV2Verify {

    /// 16 KiB. BEP 52 locks this — don't read it from the torrent.
    static let blockSize: Int64 = 16 * 1024

    /// Precomputed internal zero-subtree hashes keyed by height (0 = leaf,
    /// 1 = pair of leaves, …). Cached because padding long sparse pieces
    /// otherwise hashes 2^height zero blocks per validate.
    private static let zeroHashCache: [Data] = {
        var out: [Data] = []
        // Height 0: SHA-256 of an all-zero 16 KiB block.
        let zeroBlock = Data(count: Int(blockSize))
        out.append(Data(SHA256.hash(data: zeroBlock)))
        // Up to height 32 is *way* more than any real torrent needs (4 GiB
        // piece = 2^18 leaves). Build to 33 to be generous.
        for _ in 1...33 {
            let prev = out.last!
            var hasher = SHA256()
            hasher.update(data: prev)
            hasher.update(data: prev)
            out.append(Data(hasher.finalize()))
        }
        return out
    }()

    /// Verify `pieceData` against the v2 layer hash for `pieceIndex` in the
    /// supplied `layer` (concatenation of 32-byte hashes at a specific level
    /// of the per-file Merkle tree).
    static func verifyPiece(
        pieceData: Data,
        pieceIndex: Int,
        pieceLength: Int64,
        layer: Data
    ) -> Bool {
        let start = pieceIndex * 32
        guard start + 32 <= layer.count else { return false }
        let expected = layer.subdata(in: start..<(start + 32))
        let computed = computePieceSubtreeRoot(
            pieceData: pieceData, pieceLength: pieceLength
        )
        return computed == expected
    }

    /// Compute the subtree root a v2 layer would store for `pieceData`.
    /// Pads with zero-subtree hashes (BEP 52) if the piece is short.
    static func computePieceSubtreeRoot(pieceData: Data, pieceLength: Int64) -> Data {
        // Leaves from this piece's bytes.
        var leaves: [Data] = []
        var offset = 0
        while offset < pieceData.count {
            let end = min(offset + Int(blockSize), pieceData.count)
            leaves.append(Data(SHA256.hash(data: pieceData.subdata(in: offset..<end))))
            offset = end
        }
        // How many leaves does a full-sized piece need?
        let leavesPerPiece = Int(pieceLength / blockSize)
        // Pad up to the next power of two at this level — which for a full
        // piece is leavesPerPiece itself (always power of two in BEP 52).
        // For a short final piece, pad to leavesPerPiece with zero-leaves.
        while leaves.count < leavesPerPiece {
            leaves.append(zeroHashCache[0])
        }
        // Collapse up the tree, using zero-subtree hashes for any missing
        // sibling at odd levels (can't happen when leavesPerPiece is power
        // of two, but we keep the guard).
        var level = leaves
        var height = 0
        while level.count > 1 {
            var next: [Data] = []
            next.reserveCapacity((level.count + 1) / 2)
            var i = 0
            while i < level.count {
                let l = level[i]
                let r: Data
                if i + 1 < level.count {
                    r = level[i + 1]
                } else {
                    r = zeroHashCache[height]
                }
                var hasher = SHA256()
                hasher.update(data: l)
                hasher.update(data: r)
                next.append(Data(hasher.finalize()))
                i += 2
            }
            level = next
            height += 1
        }
        return level.first ?? Data(count: 32)
    }

    // MARK: Integration with TorrentInfo

    /// For a global piece index `globalIdx` of a v2 / hybrid torrent, return
    /// (fileEntry, localPieceIndex, layer) if the torrent ships a piece
    /// layer for the file. Returns nil for pieces that belong to a file
    /// whose layer wasn't shipped (fresh magnet, metadata-only dict) —
    /// caller then falls back to v1 SHA-1 or trust.
    static func locatePiece(
        info: TorrentInfo, globalIdx: Int
    ) -> (file: TorrentFileEntry, localIndex: Int, layer: Data)? {
        guard info.pieceLength > 0 else { return nil }
        let pieceStart = Int64(globalIdx) * info.pieceLength
        // In v2, each file is padded to a whole number of pieces. Find the
        // file this global piece lives in by walking offsets.
        var cursor: Int64 = 0
        for f in info.files {
            // A file occupies ceil(length / pieceLength) pieces in its own
            // space. In hybrid torrents the global piece space is the v1
            // contiguous layout, but v2 layer lookups use each file's own
            // local piece index. For hybrid we lean on `cursor` to keep
            // the mapping.
            let localPieces = Int((f.length + info.pieceLength - 1) / info.pieceLength)
            let fileStart = cursor
            let fileEnd = cursor + Int64(localPieces) * info.pieceLength
            if pieceStart < fileEnd && pieceStart >= fileStart,
               let root = f.piecesRoot,
               let layer = info.pieceLayers[root] {
                let localIdx = Int((pieceStart - fileStart) / info.pieceLength)
                return (f, localIdx, layer)
            }
            cursor = fileEnd
        }
        return nil
    }
}
