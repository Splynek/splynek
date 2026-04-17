import Foundation
import CryptoKit

/// A file within a multi-file torrent. For BEP 52 (v2) torrents, each file
/// additionally carries its own `piecesRoot` — the SHA-256 Merkle root of
/// its 16 KiB-block leaves. The root bubbles up through the per-file tree
/// and is compared against the layer hashes shipped in `piece layers`.
struct TorrentFileEntry {
    let pathComponents: [String]   // sanitised relative path pieces
    let length: Int64
    let offset: Int64              // byte offset inside the contiguous "virtual file"
    /// v2 only: 32-byte SHA-256 root over the file's padded 16 KiB leaf blocks.
    /// Nil for v1-only torrents.
    let piecesRoot: Data?
}

/// Which BEP 3 / BEP 52 formats this torrent supports.
///   - `.v1`: classic SHA-1 + flat `pieces`.
///   - `.v2`: BEP 52 only, SHA-256 file tree, no `pieces`.
///   - `.hybrid`: both — v1 peers and v2 peers can verify the same data.
enum TorrentMetaVersion: Int, Sendable {
    case v1 = 1
    case v2 = 2
    case hybrid = 3

    var displayLabel: String {
        switch self {
        case .v1:     return "BT v1"
        case .v2:     return "BT v2"
        case .hybrid: return "Hybrid v1+v2"
        }
    }
}

struct TorrentInfo {
    let name: String               // root directory for multi-file, or filename for single
    let totalLength: Int64
    let pieceLength: Int64
    /// v1 SHA-1 piece hashes. Empty for pure-v2 torrents.
    let pieceHashes: [Data]        // 20 bytes each
    /// v1 SHA-1 info hash. Always present (v2-only torrents still synthesize
    /// one as `Data(count: 20)` placeholder — callers check `metaVersion`).
    let infoHash: Data             // 20 bytes for v1 / hybrid; zero-bytes for pure v2
    /// v2 full SHA-256 info hash (32 bytes). Nil for pure-v1.
    let infoHashV2: Data?
    /// v2 truncated info hash (first 20 bytes of `infoHashV2`) for use in the
    /// 20-byte peer-wire handshake field. Nil for pure-v1.
    let infoHashV2Short: Data?
    let announceURLs: [URL]
    let files: [TorrentFileEntry]  // always non-empty (single-file torrents produce one entry)
    let isMultiFile: Bool
    let comment: String?
    let createdBy: String?
    let metaVersion: TorrentMetaVersion
    /// v2 per-file "piece layer" hashes. Keys are each file's `piecesRoot`
    /// (32 bytes); values are the concatenated SHA-256 hashes at the
    /// `log2(pieceLength/16384)` layer of that file's Merkle tree. Empty
    /// for pure-v1 torrents or when not shipped in the root dict.
    let pieceLayers: [Data: Data]

    var numPieces: Int {
        if metaVersion == .v2 {
            // For pure v2, count pieces as ceil(totalLength / pieceLength).
            return pieceLength > 0
                ? Int((totalLength + pieceLength - 1) / pieceLength)
                : 0
        }
        return pieceHashes.count
    }

    /// Relative path on disk for a file entry.
    func relativePath(for entry: TorrentFileEntry) -> String {
        let cleaned = entry.pathComponents.map { Sanitize.filename($0) }
        return ([name] + cleaned).joined(separator: "/")
    }
}

enum TorrentParseError: Error, LocalizedError {
    case invalidBencode(String)
    case missingField(String)
    case badPieceHashes
    case badV2Tree(String)

    var errorDescription: String? {
        switch self {
        case .invalidBencode(let s):    return "torrent: \(s)"
        case .missingField(let f):      return "torrent: missing field '\(f)'"
        case .badPieceHashes:           return "torrent: pieces field length is not a multiple of 20"
        case .badV2Tree(let s):         return "torrent (v2): \(s)"
        }
    }
}

enum TorrentFile {

    static func parse(_ data: Data) throws -> TorrentInfo {
        let (root, infoRange): (Bencode.Value, Range<Int>?)
        do {
            (root, infoRange) = try Bencode.decodeWithInfoRange(data)
        } catch {
            throw TorrentParseError.invalidBencode(error.localizedDescription)
        }
        let rawInfoBytes: Data
        if let r = infoRange {
            rawInfoBytes = data.subdata(in: r)
        } else if case .dict(let rootDict) = root,
                  let infoValue = Bencode.lookup(rootDict, "info") {
            rawInfoBytes = Bencode.encode(infoValue)
        } else {
            rawInfoBytes = Data()
        }
        return try buildInfo(root: root, rawInfoBytes: rawInfoBytes)
    }

    static func parse(contentsOf url: URL) throws -> TorrentInfo {
        try parse(try Data(contentsOf: url))
    }

    /// Build a TorrentInfo given just the bencoded info-dict bytes — used
    /// when the dict was fetched via BEP 9 metadata exchange and we don't
    /// have an outer .torrent file. Piece layers are unavailable in that
    /// case; v2 verification therefore needs live `hash_request` peer
    /// messages (not yet implemented — engine falls back to v1 verify).
    static func fromInfoDict(_ infoBytes: Data, trackers: [URL]) throws -> TorrentInfo {
        let infoValue: Bencode.Value
        do { infoValue = try Bencode.decode(infoBytes) }
        catch { throw TorrentParseError.invalidBencode(error.localizedDescription) }
        let fakeRoot: Bencode.Value = .dict([
            Data("info".utf8): infoValue,
            Data("announce-list".utf8): .list(trackers.map { .list([.bytes(Data($0.absoluteString.utf8))]) })
        ])
        return try buildInfo(root: fakeRoot, rawInfoBytes: infoBytes)
    }

    // MARK: Core builder

    private static func buildInfo(root: Bencode.Value, rawInfoBytes: Data) throws -> TorrentInfo {
        guard case .dict(let rootDict) = root else {
            throw TorrentParseError.invalidBencode("root is not a dict")
        }
        guard let infoValue = Bencode.lookup(rootDict, "info"),
              case .dict(let info) = infoValue else {
            throw TorrentParseError.missingField("info")
        }
        guard let name = Bencode.asString(Bencode.lookup(info, "name")) else {
            throw TorrentParseError.missingField("info.name")
        }
        guard let pieceLength = Bencode.asInt(Bencode.lookup(info, "piece length")) else {
            throw TorrentParseError.missingField("info.piece length")
        }

        // Detect BEP 52 v2 presence.
        let metaVersionField = Bencode.asInt(Bencode.lookup(info, "meta version")) ?? 0
        let hasV1Pieces = Bencode.asBytes(Bencode.lookup(info, "pieces")) != nil
        let hasV2Tree = Bencode.asDict(Bencode.lookup(info, "file tree")) != nil
        let metaVersion: TorrentMetaVersion
        switch (hasV1Pieces, hasV2Tree, metaVersionField) {
        case (true, true, _):    metaVersion = .hybrid
        case (false, true, 2):   metaVersion = .v2
        case (true, false, _):   metaVersion = .v1
        default:
            // Missing both layouts is unrecoverable; missing layout + meta
            // version==2 (v2-only with no tree) same story.
            throw TorrentParseError.missingField("info.pieces or info.file tree")
        }

        // v1 SHA-1 piece hashes
        var hashes: [Data] = []
        if hasV1Pieces, let pieces = Bencode.asBytes(Bencode.lookup(info, "pieces")) {
            guard pieces.count % 20 == 0 else { throw TorrentParseError.badPieceHashes }
            hashes.reserveCapacity(pieces.count / 20)
            var i = pieces.startIndex
            while i < pieces.endIndex {
                let next = pieces.index(i, offsetBy: 20)
                hashes.append(Data(pieces[i..<next]))
                i = next
            }
        }

        // v1 info hash (SHA-1 over raw info bytes).
        let v1InfoHash: Data = metaVersion == .v2
            ? Data(count: 20)                                       // placeholder
            : Data(Insecure.SHA1.hash(data: rawInfoBytes))

        // v2 info hash (SHA-256 over raw info bytes).
        let v2InfoHash: Data?
        let v2InfoHashShort: Data?
        if metaVersion != .v1 {
            let h = Data(SHA256.hash(data: rawInfoBytes))
            v2InfoHash = h
            v2InfoHashShort = h.prefix(20)
        } else {
            v2InfoHash = nil
            v2InfoHashShort = nil
        }

        // Files. Prefer v1 layout for hybrid (so the writer uses identical
        // byte layout as v1 peers would); fall back to v2 tree otherwise.
        var files: [TorrentFileEntry] = []
        var total: Int64 = 0
        let isMulti: Bool
        if metaVersion == .v2 {
            guard let tree = Bencode.asDict(Bencode.lookup(info, "file tree")) else {
                throw TorrentParseError.badV2Tree("missing file tree")
            }
            (files, total, isMulti) = try flattenV2Tree(tree, rootName: name)
        } else if let list = Bencode.asList(Bencode.lookup(info, "files")) {
            isMulti = true
            var offset: Int64 = 0
            for v in list {
                guard case .dict(let fd) = v,
                      let length = Bencode.asInt(Bencode.lookup(fd, "length")),
                      let pathList = Bencode.asList(Bencode.lookup(fd, "path")) else {
                    continue
                }
                let parts = pathList.compactMap { Bencode.asString($0) }
                files.append(TorrentFileEntry(
                    pathComponents: parts, length: length, offset: offset,
                    piecesRoot: nil
                ))
                offset += length
            }
            total = offset
            // For hybrid torrents, stitch piecesRoot from the v2 tree onto
            // each file we just built. Skip files that aren't found in the
            // tree (malformed hybrid — caller can still fall back to v1).
            if metaVersion == .hybrid,
               let tree = Bencode.asDict(Bencode.lookup(info, "file tree")) {
                files = attachPiecesRoots(files, tree: tree)
            }
        } else if let length = Bencode.asInt(Bencode.lookup(info, "length")) {
            isMulti = false
            // Pure-v1 single-file. Hybrid single-file would also land here.
            var piecesRoot: Data? = nil
            if metaVersion == .hybrid,
               let tree = Bencode.asDict(Bencode.lookup(info, "file tree")) {
                // Tree for single-file torrents: { <name>: { "": { length, pieces root } } }
                piecesRoot = lookupSinglePiecesRoot(tree: tree)
            }
            files.append(TorrentFileEntry(
                pathComponents: [name], length: length, offset: 0,
                piecesRoot: piecesRoot
            ))
            total = length
        } else {
            throw TorrentParseError.missingField("info.length or info.files or file tree")
        }

        // Piece layers (v2 / hybrid, lives on the *root* dict, not info).
        var pieceLayers: [Data: Data] = [:]
        if metaVersion != .v1,
           let layersDict = Bencode.asDict(Bencode.lookup(rootDict, "piece layers")) {
            for (k, v) in layersDict {
                if case .bytes(let data) = v { pieceLayers[k] = data }
            }
        }

        // Trackers
        var announce: [URL] = []
        if let s = Bencode.asString(Bencode.lookup(rootDict, "announce")),
           let u = URL(string: s) { announce.append(u) }
        if let list = Bencode.asList(Bencode.lookup(rootDict, "announce-list")) {
            for tier in list {
                if let urls = Bencode.asList(tier) {
                    for v in urls {
                        if let s = Bencode.asString(v), let u = URL(string: s) {
                            announce.append(u)
                        }
                    }
                }
            }
        }
        var seen: Set<String> = []
        announce = announce.filter { seen.insert($0.absoluteString).inserted }

        return TorrentInfo(
            name: Sanitize.filename(name),
            totalLength: total,
            pieceLength: pieceLength,
            pieceHashes: hashes,
            infoHash: v1InfoHash,
            infoHashV2: v2InfoHash,
            infoHashV2Short: v2InfoHashShort,
            announceURLs: announce,
            files: files,
            isMultiFile: isMulti,
            comment: Bencode.asString(Bencode.lookup(rootDict, "comment")),
            createdBy: Bencode.asString(Bencode.lookup(rootDict, "created by")),
            metaVersion: metaVersion,
            pieceLayers: pieceLayers
        )
    }

    static func pieceByteRange(info: TorrentInfo, index: Int) -> Range<Int64> {
        let start = Int64(index) * info.pieceLength
        let end = min(start + info.pieceLength, info.totalLength)
        return start..<end
    }

    // MARK: v2 tree walk

    /// Flatten a BEP 52 `file tree` dict into the same `TorrentFileEntry`
    /// layout we use for v1, preserving order (Bencode keys are sorted, so
    /// this walk is deterministic). Single-file torrents have a tree of
    /// `{ <name>: { "": { length, pieces root } } }`; multi-file ones nest
    /// directory dicts.
    private static func flattenV2Tree(
        _ tree: [Data: Bencode.Value], rootName: String
    ) throws -> ([TorrentFileEntry], Int64, Bool) {
        var files: [TorrentFileEntry] = []
        var offset: Int64 = 0

        // Single-file case: tree = { "": <fileDict> } — the root `name`
        // IS the filename. But more commonly the v2 spec puts the filename
        // as the outer key. Detect by seeing if there's an empty-bytes key
        // at the top level.
        if let single = tree[Data()], case .dict(let fileDict) = single,
           let length = Bencode.asInt(Bencode.lookup(fileDict, "length")) {
            let root = Bencode.asBytes(Bencode.lookup(fileDict, "pieces root"))
            files.append(TorrentFileEntry(
                pathComponents: [rootName], length: length, offset: 0,
                piecesRoot: root
            ))
            return (files, length, false)
        }

        // Multi-file: recursive walk, collecting in bencode-sorted key order.
        func walk(_ node: [Data: Bencode.Value], path: [String]) throws {
            let sortedKeys = node.keys.sorted { $0.lexicographicallyPrecedes($1) }
            for key in sortedKeys {
                guard let name = String(data: key, encoding: .utf8),
                      let child = node[key],
                      case .dict(let childDict) = child else { continue }
                if name.isEmpty {
                    // Sentinel "" key carries the file's metadata at this path.
                    guard let length = Bencode.asInt(Bencode.lookup(childDict, "length")) else {
                        continue
                    }
                    let root = Bencode.asBytes(Bencode.lookup(childDict, "pieces root"))
                    files.append(TorrentFileEntry(
                        pathComponents: path, length: length, offset: offset,
                        piecesRoot: root
                    ))
                    offset += length
                } else {
                    try walk(childDict, path: path + [name])
                }
            }
        }

        try walk(tree, path: [])
        let isMulti = files.count > 1 || (files.first?.pathComponents.count ?? 0) > 1
        return (files, offset, isMulti)
    }

    /// For hybrid torrents: merge piecesRoot fields from a v2 tree into an
    /// existing v1-derived file list by matching pathComponents.
    private static func attachPiecesRoots(
        _ files: [TorrentFileEntry], tree: [Data: Bencode.Value]
    ) -> [TorrentFileEntry] {
        func pathToRoot(_ tree: [Data: Bencode.Value], path: ArraySlice<String>) -> Data? {
            guard let head = path.first else { return nil }
            let key = Data(head.utf8)
            guard let node = tree[key], case .dict(let childDict) = node else { return nil }
            if path.count == 1 {
                // Leaf file: must have a `""` key whose dict carries length + pieces root.
                if let leaf = childDict[Data()], case .dict(let ld) = leaf {
                    return Bencode.asBytes(Bencode.lookup(ld, "pieces root"))
                }
                return nil
            }
            return pathToRoot(childDict, path: path.dropFirst())
        }
        return files.map { f in
            let path = f.pathComponents[...]
            return TorrentFileEntry(
                pathComponents: f.pathComponents,
                length: f.length,
                offset: f.offset,
                piecesRoot: pathToRoot(tree, path: path) ?? f.piecesRoot
            )
        }
    }

    private static func lookupSinglePiecesRoot(tree: [Data: Bencode.Value]) -> Data? {
        // Look for the first dict with an "" sentinel that has pieces root.
        for (_, v) in tree {
            guard case .dict(let d) = v,
                  let leaf = d[Data()],
                  case .dict(let leafDict) = leaf else { continue }
            if let root = Bencode.asBytes(Bencode.lookup(leafDict, "pieces root")) {
                return root
            }
        }
        // Fallback: the single-file alt form where tree itself has "" key.
        if let leaf = tree[Data()], case .dict(let ld) = leaf {
            return Bencode.asBytes(Bencode.lookup(ld, "pieces root"))
        }
        return nil
    }
}
