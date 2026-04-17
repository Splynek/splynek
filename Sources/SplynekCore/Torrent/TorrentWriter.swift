import Foundation

/// Splice piece bytes into the right files of a torrent.
///
/// For a single-file torrent this is trivially one FileHandle. For multi-file
/// torrents, pieces can straddle file boundaries, so each `writePiece` call
/// dispatches to every file the piece overlaps.
final class TorrentWriter {

    let info: TorrentInfo
    let rootDirectory: URL
    /// For single-file torrents, this is the file itself; for multi-file, it's the
    /// enclosing directory that holds `info.name/<paths>`.
    private var handles: [String: FileHandle] = [:]

    init(info: TorrentInfo, rootDirectory: URL) {
        self.info = info
        self.rootDirectory = rootDirectory
    }

    /// Create all files pre-allocated to their correct size. Necessary so
    /// seeks into not-yet-written regions succeed.
    func preallocate() throws {
        let fm = FileManager.default
        for f in info.files {
            let rel = info.relativePath(for: f)
            let url = rootDirectory.appendingPathComponent(rel)
            try fm.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try? fm.removeItem(at: url)
            fm.createFile(atPath: url.path, contents: nil)
            let h = try FileHandle(forWritingTo: url)
            try h.truncate(atOffset: UInt64(f.length))
            try h.close()
        }
    }

    /// Write `data` at the given virtual-file byte offset, splitting across
    /// multiple files if needed. Piece SHA-1 should be verified before this
    /// is called.
    func writeAt(virtualOffset: Int64, data: Data) throws {
        var remaining = data
        var cursor = virtualOffset
        for f in info.files where !remaining.isEmpty {
            let fileStart = f.offset
            let fileEnd = f.offset + f.length
            if cursor >= fileEnd { continue }
            if cursor + Int64(remaining.count) <= fileStart { continue }
            let writeFrom = max(cursor, fileStart)
            let writeTo = min(cursor + Int64(remaining.count), fileEnd)
            if writeFrom >= writeTo { continue }
            let spanLen = Int(writeTo - writeFrom)
            let dataFrom = Int(writeFrom - cursor)
            let slice = remaining.subdata(in: dataFrom..<(dataFrom + spanLen))
            let rel = info.relativePath(for: f)
            let handle = try handle(for: rel, at: rootDirectory.appendingPathComponent(rel))
            try handle.seek(toOffset: UInt64(writeFrom - fileStart))
            try handle.write(contentsOf: slice)
            // Drop the portion we just wrote from `remaining`.
            let consumed = Int(writeTo - cursor)
            remaining = remaining.subdata(in: consumed..<remaining.count)
            cursor = writeTo
        }
    }

    /// Read `length` bytes starting at `virtualOffset` in the contiguous
    /// "virtual file" view. Splits the read across underlying files for
    /// multi-file torrents.
    func readAt(virtualOffset: Int64, length: Int64) throws -> Data {
        var out = Data()
        var cursor = virtualOffset
        var remaining = length
        for f in info.files where remaining > 0 {
            let fileStart = f.offset
            let fileEnd = f.offset + f.length
            if cursor >= fileEnd { continue }
            if cursor + remaining <= fileStart { continue }
            let readFrom = max(cursor, fileStart)
            let readTo = min(cursor + remaining, fileEnd)
            if readFrom >= readTo { continue }
            let want = Int(readTo - readFrom)
            let rel = info.relativePath(for: f)
            let url = rootDirectory.appendingPathComponent(rel)
            let h = try FileHandle(forReadingFrom: url)
            defer { try? h.close() }
            try h.seek(toOffset: UInt64(readFrom - fileStart))
            let chunk = try h.read(upToCount: want) ?? Data()
            out.append(chunk)
            let took = Int64(chunk.count)
            remaining -= took
            cursor += took
            if took == 0 { break }  // unexpected short read
        }
        return out
    }

    func close() {
        for (_, h) in handles { try? h.close() }
        handles.removeAll()
    }

    private func handle(for key: String, at url: URL) throws -> FileHandle {
        if let h = handles[key] { return h }
        let h = try FileHandle(forWritingTo: url)
        handles[key] = h
        return h
    }
}
