import Foundation

/// Strategy Bet S6 — File Witness.
///
/// On-disk persistence for `DownloadReceipt`s.  Each completed
/// download mints one receipt, stored at:
///
/// ```
/// ~/Library/Application Support/Splynek/receipts/<sha256>.json
/// ```
///
/// Keyed by content SHA-256 because:
/// - It's the unique-per-bytes identifier that ties directly to
///   the receipt's signed payload
/// - If the same content is downloaded twice from different URLs,
///   the latest receipt wins (idempotent overwrite)
/// - Lookup from HistoryDetailSheet is a simple `read(forSha256:)`
///   without needing UUID / job-ID joins
///
/// Failures are intentionally silent: the engine's success path
/// shouldn't fail because the user's disk is full or
/// `~/Library/Application Support` is read-only (rare but possible).
/// Receipts are an additive feature; if they can't write, the
/// download still succeeds.
public enum ReceiptStore {

    /// `~/Library/Application Support/Splynek/receipts/`
    /// (per-user, sandbox-container-aware via `urls(for:)`).
    static func directoryURL() -> URL? {
        guard let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return appSupport
            .appendingPathComponent("Splynek", isDirectory: true)
            .appendingPathComponent("receipts", isDirectory: true)
    }

    /// Mint + write a receipt for a freshly-completed download.  No-op
    /// if SHA-256 is missing/invalid.  Caller must be on the main
    /// actor (DeviceKeyManager is @MainActor-isolated).
    @MainActor
    public static func mintAndStore(
        url: URL,
        sha256: String?,
        sizeBytes: Int64,
        finishedAt: Date = Date()
    ) {
        guard let sha = sha256?.lowercased(), isHex64(sha) else { return }
        guard let dir = directoryURL() else { return }
        do {
            try FileManager.default.createDirectory(
                at: dir, withIntermediateDirectories: true
            )
        } catch {
            return
        }
        guard let receipt = try? DownloadReceipt.mint(
            url: url,
            sha256: sha,
            sizeBytes: sizeBytes,
            finishedAt: finishedAt
        ) else { return }
        guard let body = try? receipt.prettyJSON() else { return }
        let target = dir.appendingPathComponent("\(sha).json")
        // Atomic write: temp then rename, so a crash mid-write doesn't
        // leave a half-baked receipt at the canonical location.
        try? body.write(to: target, options: [.atomic])
    }

    /// Read the receipt for a content hash, if present.  Used by
    /// HistoryDetailSheet's "Export receipt" action.
    public static func read(forSha256 sha: String) -> DownloadReceipt? {
        guard let dir = directoryURL() else { return nil }
        let path = dir.appendingPathComponent("\(sha.lowercased()).json")
        guard let data = try? Data(contentsOf: path) else { return nil }
        return try? JSONDecoder().decode(DownloadReceipt.self, from: data)
    }

    /// True if a receipt exists for this hash.  Cheap check —
    /// doesn't decode.  Used to gate the UI's "Export receipt"
    /// button visibility.
    public static func exists(forSha256 sha: String) -> Bool {
        guard let dir = directoryURL() else { return false }
        let path = dir.appendingPathComponent("\(sha.lowercased()).json")
        return FileManager.default.fileExists(atPath: path.path)
    }

    private static func isHex64(_ s: String) -> Bool {
        guard s.count == 64 else { return false }
        return s.allSatisfy { $0.isHexDigit }
    }
}
