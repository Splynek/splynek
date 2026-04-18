import Foundation
import CryptoKit
@testable import SplynekCore

/// v0.40 added session restore for torrents: on startup the engine
/// scans each piece's bytes off disk and marks verified ones as
/// done so the swarm doesn't re-fetch them.
///
/// These tests build a minimal multi-file v1 torrent, materialise
/// its bytes in a temp directory through `TorrentWriter`, run
/// `TorrentResume.scan`, and assert:
///   - every piece gets verified when the bytes are correct;
///   - a single-byte corruption drops exactly that piece;
///   - a short final piece is handled (BEP 3 edge case);
///   - the `PieceVerifier.verify(resumeMode:)` flag correctly
///     refuses v2-magnets-without-layers (tests the engine's
///     "don't pretend we verified it" guarantee).
enum TorrentResumeTests {

    // MARK: Fixture builders

    /// Create a v1 single-root-folder TorrentInfo with one data file
    /// of the given byte pattern, chunked into `pieceLength`-byte
    /// pieces. Returns the info + the payload used to generate it.
    private static func buildV1Fixture(
        pieceLength: Int64, totalLength: Int64, rootName: String, fileName: String
    ) -> (info: TorrentInfo, payload: Data) {
        var payload = Data(count: Int(totalLength))
        // Deterministic pseudo-random bytes so SHA-1 stays stable
        // across runs and is unlikely to collide with any other
        // canned fixture in the repo.
        for i in 0..<Int(totalLength) {
            payload[i] = UInt8(truncatingIfNeeded: (i * 2654435761) >> 16)
        }

        // Piece hashes.
        var pieceHashes: [Data] = []
        var offset = 0
        while offset < payload.count {
            let end = min(offset + Int(pieceLength), payload.count)
            let slice = payload.subdata(in: offset..<end)
            pieceHashes.append(Data(Insecure.SHA1.hash(data: slice)))
            offset = end
        }

        let fileEntry = TorrentFileEntry(
            pathComponents: [fileName],
            length: totalLength,
            offset: 0,
            piecesRoot: nil
        )
        let info = TorrentInfo(
            name: rootName,
            totalLength: totalLength,
            pieceLength: pieceLength,
            pieceHashes: pieceHashes,
            infoHash: Data(count: 20),
            infoHashV2: nil,
            infoHashV2Short: nil,
            announceURLs: [],
            files: [fileEntry],
            isMultiFile: false,
            comment: nil,
            createdBy: nil,
            metaVersion: .v1,
            pieceLayers: [:]
        )
        return (info, payload)
    }

    /// Write `payload` to the virtual-file layout TorrentWriter
    /// expects, using the writer itself (so we exercise the same
    /// code path the live engine does).
    private static func materialise(
        info: TorrentInfo, payload: Data, root: URL
    ) throws -> TorrentWriter {
        let writer = TorrentWriter(info: info, rootDirectory: root)
        try writer.preallocate()
        try writer.writeAt(virtualOffset: 0, data: payload)
        return writer
    }

    private static func withTempRoot<T>(_ body: (URL) throws -> T) throws -> T {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-resume-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        return try body(root)
    }

    // MARK: Tests

    static func run() {
        TestHarness.suite("Torrent session restore") {

            TestHarness.test("Full valid payload → every piece verified") {
                try withTempRoot { root in
                    let fx = buildV1Fixture(
                        pieceLength: 256, totalLength: 1024,
                        rootName: "pkg", fileName: "data.bin"
                    )
                    let writer = try materialise(info: fx.info, payload: fx.payload, root: root)
                    defer { writer.close() }
                    let result = TorrentResume.scan(info: fx.info, rootDirectory: root)
                    try expectEqual(result.verifiedPieces.count, fx.info.numPieces)
                    try expectEqual(result.bytesRecovered, fx.info.totalLength)
                }
            }

            TestHarness.test("Single-byte corruption rejects exactly one piece") {
                try withTempRoot { root in
                    let fx = buildV1Fixture(
                        pieceLength: 256, totalLength: 1024,
                        rootName: "pkg", fileName: "data.bin"
                    )
                    let writer = try materialise(info: fx.info, payload: fx.payload, root: root)
                    defer { writer.close() }

                    // Flip a byte inside piece index 2 (bytes 512..768).
                    let corruptionOffset: Int64 = 600
                    try writer.writeAt(
                        virtualOffset: corruptionOffset,
                        data: Data([fx.payload[Int(corruptionOffset)] ^ 0xFF])
                    )

                    let result = TorrentResume.scan(info: fx.info, rootDirectory: root)
                    try expectEqual(result.verifiedPieces.count, fx.info.numPieces - 1)
                    try expect(!result.verifiedPieces.contains(2),
                               "piece 2 contained the corrupted byte, should NOT be verified")
                    try expectEqual(result.bytesRecovered,
                                    fx.info.totalLength - fx.info.pieceLength)
                }
            }

            TestHarness.test("Short final piece is handled") {
                try withTempRoot { root in
                    // 1000 bytes, piece length 256 → pieces 0..3 are 256 bytes,
                    // piece 3 is 232 bytes. BEP 3 allows the final piece to be short.
                    let fx = buildV1Fixture(
                        pieceLength: 256, totalLength: 1000,
                        rootName: "pkg", fileName: "data.bin"
                    )
                    try expectEqual(fx.info.numPieces, 4)
                    let writer = try materialise(info: fx.info, payload: fx.payload, root: root)
                    defer { writer.close() }
                    let result = TorrentResume.scan(info: fx.info, rootDirectory: root)
                    try expectEqual(result.verifiedPieces.count, 4)
                }
            }

            TestHarness.test("Fully restored torrent reports bytesRecovered == totalLength") {
                try withTempRoot { root in
                    let fx = buildV1Fixture(
                        pieceLength: 128, totalLength: 512,
                        rootName: "pkg", fileName: "x.bin"
                    )
                    let writer = try materialise(info: fx.info, payload: fx.payload, root: root)
                    defer { writer.close() }
                    let result = TorrentResume.scan(info: fx.info, rootDirectory: root)
                    try expectEqual(result.bytesRecovered, 512)
                }
            }

            TestHarness.test("Empty torrent info produces empty result") {
                let emptyFile = TorrentFileEntry(
                    pathComponents: ["empty.bin"], length: 0, offset: 0, piecesRoot: nil
                )
                let empty = TorrentInfo(
                    name: "empty", totalLength: 0, pieceLength: 0,
                    pieceHashes: [], infoHash: Data(count: 20),
                    infoHashV2: nil, infoHashV2Short: nil,
                    announceURLs: [], files: [emptyFile],
                    isMultiFile: false, comment: nil, createdBy: nil,
                    metaVersion: .v1, pieceLayers: [:]
                )
                // We can't build a writer without creating dirs; just
                // use the fact that scan bails on numPieces == 0.
                let fm = FileManager.default
                let root = fm.temporaryDirectory
                    .appendingPathComponent("splynek-empty-\(UUID().uuidString)")
                try fm.createDirectory(at: root, withIntermediateDirectories: true)
                defer { try? fm.removeItem(at: root) }
                let result = TorrentResume.scan(info: empty, rootDirectory: root)
                try expectEqual(result, .empty)
            }
        }

        TestHarness.suite("PieceVerifier resume-mode semantics") {

            TestHarness.test("v1 correct bytes → verified") {
                let fx = buildV1Fixture(
                    pieceLength: 256, totalLength: 1024,
                    rootName: "x", fileName: "d.bin"
                )
                let piece0 = fx.payload.subdata(in: 0..<256)
                try expect(PieceVerifier.verify(
                    data: piece0, index: 0, info: fx.info, resumeMode: true
                ))
            }

            TestHarness.test("v1 corrupt bytes → not verified") {
                let fx = buildV1Fixture(
                    pieceLength: 256, totalLength: 1024,
                    rootName: "x", fileName: "d.bin"
                )
                var corrupt = fx.payload.subdata(in: 0..<256)
                corrupt[0] ^= 0xFF
                try expect(!PieceVerifier.verify(
                    data: corrupt, index: 0, info: fx.info, resumeMode: true
                ))
            }

            TestHarness.test("v2 magnet without layers + resume mode → NOT verified") {
                // Build a bare v2 TorrentInfo with no piece layers
                // (the magnet-before-metadata state). Resume mode
                // should refuse to accept anything rather than
                // silently pretending the bytes are valid.
                let fileEntry = TorrentFileEntry(
                    pathComponents: ["d.bin"], length: 1024,
                    offset: 0, piecesRoot: Data(count: 32)
                )
                let v2NoLayers = TorrentInfo(
                    name: "x", totalLength: 1024, pieceLength: 256,
                    pieceHashes: [], infoHash: Data(count: 20),
                    infoHashV2: Data(count: 32),
                    infoHashV2Short: Data(count: 20),
                    announceURLs: [], files: [fileEntry],
                    isMultiFile: false, comment: nil, createdBy: nil,
                    metaVersion: .v2, pieceLayers: [:]
                )
                try expect(!PieceVerifier.verify(
                    data: Data(count: 256), index: 0, info: v2NoLayers,
                    resumeMode: true
                ))
            }

            TestHarness.test("v2 magnet without layers + live-swarm mode → accepted") {
                // Regression guard for the engine's live-swarm path:
                // PeerCoordinator.acceptPiece must keep accepting
                // bytes tentatively when the swarm hasn't delivered
                // piece layers yet.
                let fileEntry = TorrentFileEntry(
                    pathComponents: ["d.bin"], length: 1024,
                    offset: 0, piecesRoot: Data(count: 32)
                )
                let v2NoLayers = TorrentInfo(
                    name: "x", totalLength: 1024, pieceLength: 256,
                    pieceHashes: [], infoHash: Data(count: 20),
                    infoHashV2: Data(count: 32),
                    infoHashV2Short: Data(count: 20),
                    announceURLs: [], files: [fileEntry],
                    isMultiFile: false, comment: nil, createdBy: nil,
                    metaVersion: .v2, pieceLayers: [:]
                )
                try expect(PieceVerifier.verify(
                    data: Data(count: 256), index: 0, info: v2NoLayers,
                    resumeMode: false
                ))
            }
        }
    }
}
