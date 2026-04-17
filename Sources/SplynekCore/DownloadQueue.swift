import Foundation

/// One entry in the persistent download queue.
struct QueueEntry: Codable, Identifiable, Hashable {
    enum Status: String, Codable, Hashable {
        case pending     // waiting its turn
        case running     // currently fetching
        case completed   // done
        case failed      // terminal error
        case cancelled   // user asked to stop
    }

    var id: UUID
    var url: String
    var sha256: String?
    var addedAt: Date
    var status: Status
    var finishedAt: Date?
    var errorMessage: String?
}

/// Codable disk shape.
private struct QueueSnapshot: Codable {
    var version: Int = 1
    var entries: [QueueEntry]
}

/// Persistent FIFO queue of URLs to download.
///
/// We keep it simple: an ordered list stored as JSON under Application
/// Support, loaded at launch and rewritten on every mutation. Status fields
/// let the UI render "pending / running / done / failed" badges without a
/// separate state store.
final class DownloadQueue {

    static var storeURL: URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("queue.json")
    }

    static func load() -> [QueueEntry] {
        guard let data = try? Data(contentsOf: storeURL),
              let snap = try? JSONDecoder.iso8601.decode(QueueSnapshot.self, from: data)
        else { return [] }
        return snap.entries
    }

    static func save(_ entries: [QueueEntry]) {
        let snap = QueueSnapshot(entries: entries)
        guard let data = try? JSONEncoder.iso8601.encode(snap) else { return }
        try? data.write(to: storeURL, options: .atomic)
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
