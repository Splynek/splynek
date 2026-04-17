import Foundation
import CryptoKit
@testable import SplynekCore

/// Load-bearing claim: BEP 52 piece verification. Wrong math here
/// means v0.19's pure-v2 downloads silently accept corrupted bytes.
/// These tests build a real Merkle subtree from known data and
/// verify against the computed root — plus the failure path.
enum TorrentV2VerifyTests {

    /// Fixed 16 KiB block. BEP 52 locks the leaf boundary.
    static let blockSize: Int = 16 * 1024

    /// Compute a piece subtree root ourselves (outside the code under
    /// test) so we can cross-check TorrentV2Verify's arithmetic.
    /// Pads with the zero-leaf hash (SHA-256 of 16 KiB of zeroes) up
    /// to `leavesPerPiece`, then pair-hashes up the tree.
    static func referenceSubtreeRoot(
        _ piece: Data, pieceLength: Int64
    ) -> Data {
        var leaves: [Data] = []
        var off = 0
        while off < piece.count {
            let end = min(off + blockSize, piece.count)
            leaves.append(Data(SHA256.hash(data: piece.subdata(in: off..<end))))
            off = end
        }
        let leavesPerPiece = Int(pieceLength / Int64(blockSize))
        let zeroLeaf = Data(SHA256.hash(data: Data(count: blockSize)))
        while leaves.count < leavesPerPiece {
            leaves.append(zeroLeaf)
        }
        var level = leaves
        while level.count > 1 {
            var next: [Data] = []
            var i = 0
            while i < level.count {
                var h = SHA256()
                h.update(data: level[i])
                h.update(data: level[i + 1])
                next.append(Data(h.finalize()))
                i += 2
            }
            level = next
        }
        return level[0]
    }

    static func run() {
        TestHarness.suite("BEP 52 verification") {

            TestHarness.test("Full-sized piece (4 blocks) matches reference root") {
                // pieceLength = 64 KiB → 4 leaves, always power of two.
                let pieceLen: Int64 = 64 * 1024
                let piece = Data((0..<Int(pieceLen)).map { UInt8($0 & 0xFF) })
                let expected = referenceSubtreeRoot(piece, pieceLength: pieceLen)
                let computed = TorrentV2Verify.computePieceSubtreeRoot(
                    pieceData: piece, pieceLength: pieceLen
                )
                try expectEqual(computed, expected)
            }

            TestHarness.test("Short final piece pads with zero-leaves") {
                // pieceLen = 64 KiB (4 leaves) but data is 1.5 blocks.
                let pieceLen: Int64 = 64 * 1024
                let short = Data(repeating: 0xAB, count: Int(blockSize) + blockSize / 2)
                let expected = referenceSubtreeRoot(short, pieceLength: pieceLen)
                let computed = TorrentV2Verify.computePieceSubtreeRoot(
                    pieceData: short, pieceLength: pieceLen
                )
                try expectEqual(computed, expected)
            }

            TestHarness.test("verifyPiece accepts correct bytes against layer") {
                // One-piece layer: the layer IS the subtree root, so build
                // the root, use it as layer[0..32], verify against it.
                let pieceLen: Int64 = 32 * 1024   // 2 blocks
                let piece = Data((0..<Int(pieceLen)).map { UInt8(($0 * 7) & 0xFF) })
                let layer = TorrentV2Verify.computePieceSubtreeRoot(
                    pieceData: piece, pieceLength: pieceLen
                )
                try expect(layer.count == 32)
                try expect(TorrentV2Verify.verifyPiece(
                    pieceData: piece, pieceIndex: 0,
                    pieceLength: pieceLen, layer: layer
                ))
            }

            TestHarness.test("verifyPiece rejects corrupted bytes") {
                let pieceLen: Int64 = 32 * 1024
                var piece = Data((0..<Int(pieceLen)).map { UInt8($0 & 0xFF) })
                let layer = TorrentV2Verify.computePieceSubtreeRoot(
                    pieceData: piece, pieceLength: pieceLen
                )
                piece[100] ^= 0xFF    // flip one byte
                try expect(!TorrentV2Verify.verifyPiece(
                    pieceData: piece, pieceIndex: 0,
                    pieceLength: pieceLen, layer: layer
                ))
            }

            TestHarness.test("verifyPiece handles multi-piece layer by index") {
                // Build a two-piece layer manually: piece 0 root ‖ piece 1 root.
                let pieceLen: Int64 = 32 * 1024
                let p0 = Data(repeating: 0x11, count: Int(pieceLen))
                let p1 = Data(repeating: 0x22, count: Int(pieceLen))
                var layer = Data()
                layer.append(TorrentV2Verify.computePieceSubtreeRoot(
                    pieceData: p0, pieceLength: pieceLen
                ))
                layer.append(TorrentV2Verify.computePieceSubtreeRoot(
                    pieceData: p1, pieceLength: pieceLen
                ))
                try expect(TorrentV2Verify.verifyPiece(
                    pieceData: p1, pieceIndex: 1,
                    pieceLength: pieceLen, layer: layer
                ))
                // Cross-check: piece 0 bytes MUST NOT verify at index 1.
                try expect(!TorrentV2Verify.verifyPiece(
                    pieceData: p0, pieceIndex: 1,
                    pieceLength: pieceLen, layer: layer
                ))
            }
        }
    }
}
