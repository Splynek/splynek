import Foundation

/// Piece-level session-restore for torrents.
///
/// Runs once, after `TorrentWriter.preallocate()` and before the
/// swarm kicks off. For each declared piece, read the expected-length
/// range from the virtual file view and verify against the torrent's
/// piece hashes via `PieceVerifier`. Hits are handed back so the
/// engine can `picker.markDone(idx)` them — we skip re-downloading
/// anything already on disk.
///
/// Cost: O(totalBytes) disk read + SHA-1/SHA-256 hash. For a fresh
/// run where every file is all-zeros the hashes will just not match
/// and nothing is recovered. For a restart after partial progress,
/// the cost is paid once to reclaim the partial bytes — worth it
/// because the alternative is re-downloading from the swarm.
///
/// Kept free of MainActor / ObservableObject so tests can pin the
/// scanning logic against temp-dir fixtures without standing up the
/// engine or the VM.
enum TorrentResume {

    struct Result: Equatable, Sendable {
        var verifiedPieces: Set<Int>
        var bytesRecovered: Int64

        static let empty = Result(verifiedPieces: [], bytesRecovered: 0)
    }

    /// Scan every piece in `info` against the bytes on disk under
    /// `rootDirectory`. Reads go through `TorrentWriter.read(...)`
    /// which is a static, Sendable-friendly helper so the scan can
    /// be dispatched onto a background queue without capturing
    /// mutable writer state. Calls `onProgress` (off the main actor)
    /// every `progressInterval` pieces so the UI can surface a
    /// "Verifying existing pieces…" progress line. `isCancelled`
    /// lets the caller abort mid-scan (e.g., user cancels the
    /// torrent).
    static func scan(
        info: TorrentInfo,
        rootDirectory: URL,
        progressInterval: Int = 16,
        onProgress: ((Int, Int) -> Void)? = nil,
        isCancelled: () -> Bool = { false }
    ) -> Result {
        guard info.numPieces > 0, info.totalLength > 0 else {
            return .empty
        }
        var verified: Set<Int> = []
        var bytes: Int64 = 0
        for idx in 0..<info.numPieces {
            if isCancelled() { break }
            let range = TorrentFile.pieceByteRange(info: info, index: idx)
            let offset = range.lowerBound
            let length = Int64(range.count)
            guard let data = try? TorrentWriter.read(
                    info: info, rootDirectory: rootDirectory,
                    virtualOffset: offset, length: length
                  ),
                  data.count == length else {
                // Short read → the file is smaller than the piece span.
                // That's normal right after a fresh preallocate if the
                // filesystem hasn't truncated yet; we just count it as
                // a miss and the swarm will fetch.
                continue
            }
            if PieceVerifier.verify(data: data, index: idx, info: info, resumeMode: true) {
                verified.insert(idx)
                bytes += length
            }
            if let onProgress, (idx + 1) % progressInterval == 0 {
                onProgress(idx + 1, info.numPieces)
            }
        }
        onProgress?(info.numPieces, info.numPieces)
        return Result(verifiedPieces: verified, bytesRecovered: bytes)
    }
}
