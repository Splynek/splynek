import Foundation

/// Serialised form of one in-flight DownloadJob, small enough to survive a
/// relaunch. Everything needed to reconstruct a `DownloadJob` in `.paused`
/// state is captured here (the per-chunk sidecar on disk carries the
/// actual progress — this file is just the job's configuration).
struct DownloadJobSnapshot: Codable {
    var url: String
    var outputPath: String
    var sha256: String?
    var connectionsPerInterface: Int
    var useDoH: Bool
    var extraHeaders: [String: String]
    var merkleManifest: MerkleManifest?
    /// BSD names of the interfaces the job was using. On restore we look
    /// these up against the current interface list; missing ones fall off.
    var interfaceNames: [String]
}

/// Minimal torrent-side snapshot: remember what the user had loaded so
/// relaunch can re-populate the form. Byte-level progress for torrent
/// pieces lives on disk in the output files themselves, so there's no
/// sidecar equivalent — we just make the next `Start` click convenient.
struct TorrentSnapshot: Codable {
    var magnetText: String?
    var torrentFilePath: String?
}

private struct SessionSnapshot: Codable {
    var version: Int = 2
    var savedAt: Date
    var jobs: [DownloadJobSnapshot]
    var torrent: TorrentSnapshot?
}

enum SessionStore {
    static var storeURL: URL {
        let fm = FileManager.default
        let base = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = base.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("session.json")
    }

    static func load() -> (jobs: [DownloadJobSnapshot], torrent: TorrentSnapshot?) {
        guard let data = try? Data(contentsOf: storeURL),
              let snap = try? JSONDecoder.iso8601.decode(SessionSnapshot.self, from: data)
        else { return ([], nil) }
        return (snap.jobs, snap.torrent)
    }

    static func save(jobs: [DownloadJobSnapshot], torrent: TorrentSnapshot? = nil) {
        let snap = SessionSnapshot(savedAt: Date(), jobs: jobs, torrent: torrent)
        if let data = try? JSONEncoder.iso8601.encode(snap) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    static func clear() {
        try? FileManager.default.removeItem(at: storeURL)
    }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
        return e
    }
}
private extension JSONDecoder {
    static var iso8601: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
