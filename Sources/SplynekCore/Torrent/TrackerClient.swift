import Foundation

/// Peer from the tracker's response (BEP 3 compact or dict format).
struct TorrentPeer: Hashable {
    let ip: String      // IPv4 literal or "[ipv6]"
    let port: UInt16
}

struct AnnounceResponse {
    let interval: Int           // seconds between announces
    let peers: [TorrentPeer]
    let complete: Int?          // seeders
    let incomplete: Int?        // leechers
}

enum TrackerError: Error, LocalizedError {
    case unsupportedScheme(String)
    case transport(String)
    case badResponse(String)
    case trackerFailure(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedScheme(let s): return "Tracker: \(s) not supported (only HTTP/HTTPS)."
        case .transport(let s):         return "Tracker transport: \(s)"
        case .badResponse(let s):       return "Tracker: \(s)"
        case .trackerFailure(let s):    return "Tracker rejected announce: \(s)"
        }
    }
}

/// BitTorrent tracker-announce parameter block. The actual announcing
/// now lives in `HTTPTrackerOverNW` (per-interface via `NWConnection`)
/// and `UDPTracker`; this type's previous `announce()` method has been
/// retired as of the v0.16 audit — it duplicated the URLSession path we
/// no longer use because tracker DNS should obey `requiredInterface`.
enum TrackerClient {
    struct AnnounceParams {
        let announceURL: URL
        let infoHash: Data     // 20 bytes
        let peerID: Data       // 20 bytes
        let port: UInt16
        let uploaded: Int64
        let downloaded: Int64
        let left: Int64
        let event: String?     // "started", "completed", "stopped", or nil
    }
}
