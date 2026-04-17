import Foundation
import CryptoKit
@testable import SplynekCore

/// Load-bearing claim: per-chunk Merkle integrity. Wrong Merkle math
/// would silently accept corrupted chunks. Pins the hash formats and
/// inclusion-proof algebra against known vectors + a real round-trip
/// through MerklePublisher.
enum MerkleTreeTests {

    static func run() {
        TestHarness.suite("Merkle tree") {

            TestHarness.test("Leaf hash is domain-separated with 0x00 prefix") {
                let data = Data("hello".utf8)
                let leaf = MerkleTree.leafHash(data)
                var h = SHA256()
                h.update(data: Data([0x00]))
                h.update(data: data)
                try expectEqual(leaf, Data(h.finalize()))
            }

            TestHarness.test("Pair hash is domain-separated with 0x01 prefix") {
                let a = Data(repeating: 0xAA, count: 32)
                let b = Data(repeating: 0xBB, count: 32)
                let pair = MerkleTree.pairHash(a, b)
                var h = SHA256()
                h.update(data: Data([0x01]))
                h.update(data: a)
                h.update(data: b)
                try expectEqual(pair, Data(h.finalize()))
            }

            TestHarness.test("Single-leaf root equals the leaf") {
                let leaves = [MerkleTree.leafHash(Data("x".utf8))]
                try expectEqual(MerkleTree.root(leaves: leaves), leaves[0])
            }

            TestHarness.test("Two-leaf root is pair of leaves") {
                let l0 = MerkleTree.leafHash(Data("alpha".utf8))
                let l1 = MerkleTree.leafHash(Data("beta".utf8))
                try expectEqual(
                    MerkleTree.root(leaves: [l0, l1]),
                    MerkleTree.pairHash(l0, l1)
                )
            }

            TestHarness.test("Odd-count tree duplicates the last leaf at each level") {
                let l0 = MerkleTree.leafHash(Data("a".utf8))
                let l1 = MerkleTree.leafHash(Data("b".utf8))
                let l2 = MerkleTree.leafHash(Data("c".utf8))
                let p01 = MerkleTree.pairHash(l0, l1)
                let p22 = MerkleTree.pairHash(l2, l2)
                let expected = MerkleTree.pairHash(p01, p22)
                try expectEqual(MerkleTree.root(leaves: [l0, l1, l2]), expected)
            }

            TestHarness.test("Proofs verify for every index, 5-leaf tree") {
                let leaves = (0..<5).map {
                    MerkleTree.leafHash(Data("leaf\($0)".utf8))
                }
                let root = MerkleTree.root(leaves: leaves)
                for i in 0..<leaves.count {
                    let proof = MerkleTree.proof(forIndex: i, leaves: leaves)
                    try expect(
                        MerkleTree.verify(leaf: leaves[i], proof: proof, expectedRoot: root),
                        "proof for index \(i) did not verify"
                    )
                    var bad = leaves[i]
                    bad[0] ^= 0xFF
                    try expect(
                        !MerkleTree.verify(leaf: bad, proof: proof, expectedRoot: root),
                        "proof accepted a corrupted leaf at index \(i)"
                    )
                }
            }

            TestHarness.test("Proofs verify for sampled indices, 100-leaf tree") {
                let leaves = (0..<100).map {
                    MerkleTree.leafHash(Data("chunk-\($0)".utf8))
                }
                let root = MerkleTree.root(leaves: leaves)
                for i in [0, 1, 49, 50, 99] {
                    let proof = MerkleTree.proof(forIndex: i, leaves: leaves)
                    try expect(
                        MerkleTree.verify(leaf: leaves[i], proof: proof, expectedRoot: root),
                        "proof for index \(i) of 100 did not verify"
                    )
                }
            }

            TestHarness.test("MerklePublisher rebuilds the expected root end-to-end") {
                let tmp = FileManager.default.temporaryDirectory
                    .appendingPathComponent("splynek-merkle-\(UUID().uuidString).bin")
                defer { try? FileManager.default.removeItem(at: tmp) }
                // 9 MiB — multiple chunks + a short final chunk.
                let payload = Data((0..<(9 * 1024 * 1024)).map { UInt8($0 & 0xFF) })
                try payload.write(to: tmp)
                let manifest = try MerklePublisher.manifest(for: tmp)
                try expectEqual(manifest.totalBytes, Int64(payload.count))
                try expectEqual(manifest.chunkSize, MerklePublisher.chunkSize)
                try expect(manifest.leafHexes.count > 1)
                let root = MerkleTree.root(leaves: manifest.leafHashes)
                try expectEqual(root.hexEncodedString, manifest.rootHex)
            }
        }
    }
}
