import Foundation

/// Append-only JSON log of completed downloads.
/// Lives at ~/Library/Application Support/Splynek/history.json.
enum DownloadHistory {

    static var storeURL: URL {
        let fm = FileManager.default
        let appSupport = (try? fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )) ?? fm.temporaryDirectory
        let dir = appSupport.appendingPathComponent("Splynek", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [HistoryEntry] {
        guard let data = try? Data(contentsOf: storeURL),
              let list = try? JSONDecoder.iso8601.decode([HistoryEntry].self, from: data)
        else { return [] }
        return list
    }

    static func record(_ entry: HistoryEntry) {
        var list = load()
        list.append(entry)
        if list.count > 500 { list.removeFirst(list.count - 500) }
        if let data = try? JSONEncoder.iso8601.encode(list) {
            try? data.write(to: storeURL, options: .atomic)
        }
    }

    /// Aggregate a lane-performance profile for the given host, if we have
    /// prior data. Returns per-interface average throughput (bytes/sec).
    ///
    /// Used by "lane replay" — the next time the user downloads from this
    /// host, the UI can surface historical per-lane performance so they can
    /// pick the right interfaces up front.
    static func laneProfile(host: String) -> [String: Double] {
        let entries = load().filter { URL(string: $0.url)?.host == host }
        guard !entries.isEmpty else { return [:] }
        var totals: [String: (Double, Double)] = [:]  // (weighted-bytes, total-seconds)
        for e in entries {
            let secs = max(e.durationSeconds, 0.001)
            for (iface, bytes) in e.bytesPerInterface {
                let prior = totals[iface] ?? (0, 0)
                // rough estimate: per-lane bps = per-lane bytes / total duration
                totals[iface] = (prior.0 + Double(bytes), prior.1 + secs)
            }
        }
        return totals.mapValues { $0.1 > 0 ? $0.0 / $0.1 : 0 }
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
