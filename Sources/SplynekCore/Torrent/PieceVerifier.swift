import Foundation
import CryptoKit

/// Per-piece verification, shared between the live swarm (`PeerCoordinator
/// .acceptPiece`) and the session-restore scanner (`TorrentResume`).
/// v0.40 lifted the logic out of the coordinator so both call sites
/// route through a single well-tested function — previously the scan-on-
/// resume path didn't exist, so the logic lived inline.
enum PieceVerifier {

    /// Verify `data` against the piece hashes declared by `info`.
    /// Returns true iff the bytes match the torrent's per-piece
    /// commitments. Behaviour:
    ///   - v1 / hybrid: compare SHA-1 against `info.pieceHashes[index]`.
    ///   - v2: rebuild the per-piece Merkle subtree and compare to
    ///     `info.pieceLayers` entry.
    ///   - hybrid (both present): require both to pass.
    ///   - v2-only magnet (no piece layers fetched yet): pessimistic
    ///     `false` during resume — we can't prove the bytes are valid,
    ///     so the engine will re-download them once the layers
    ///     arrive. (The live-swarm `acceptPiece` is more lenient
    ///     because it's fed newly-arrived bytes, not disk data.)
    static func verify(data: Data, index: Int, info: TorrentInfo) -> Bool {
        verify(data: data, index: index, info: info, resumeMode: false)
    }

    /// Same as `verify(...)` but with a flag controlling the
    /// v2-magnet-without-layers behaviour. Exposed to let the
    /// engine's `acceptPiece` keep its "accept on faith" semantics
    /// for newly-arrived bytes while resume is strict.
    static func verify(
        data: Data, index: Int, info: TorrentInfo, resumeMode: Bool
    ) -> Bool {
        let v1Ok: Bool?
        if !info.pieceHashes.isEmpty, index < info.pieceHashes.count {
            let digest = Data(Insecure.SHA1.hash(data: data))
            v1Ok = (digest == info.pieceHashes[index])
        } else {
            v1Ok = nil
        }
        let v2Ok: Bool?
        if info.metaVersion != .v1,
           let located = TorrentV2Verify.locatePiece(info: info, globalIdx: index) {
            v2Ok = TorrentV2Verify.verifyPiece(
                pieceData: data, pieceIndex: located.localIndex,
                pieceLength: info.pieceLength, layer: located.layer
            )
        } else {
            v2Ok = nil
        }
        switch (v1Ok, v2Ok) {
        case (.some(true), .some(true)): return true
        case (.some(true), nil):         return true
        case (nil, .some(true)):         return true
        case (.some(false), _):          return false
        case (_, .some(false)):          return false
        case (nil, nil):
            // No verification data available. Resume mode refuses to
            // pretend — the piece will be re-fetched. Live-swarm mode
            // accepts for v2 magnets that haven't yet received their
            // layers (PeerCoordinator.acceptPiece preserves that.)
            return resumeMode ? false : (info.metaVersion == .v2)
        }
    }
}
