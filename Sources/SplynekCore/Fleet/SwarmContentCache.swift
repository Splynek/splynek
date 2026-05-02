import Foundation

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// SwarmContentCache is a content-addressed (SHA-256 keyed) lookup
// table from `contentDigest` → on-disk file URL.  No bytes are
// duplicated; the cache stores the URL where the original download
// already landed (via DownloadHistory + outputPath) and serves
// chunks straight from there.  Files are read-only from the cache's
// perspective; we never write or modify the user's downloads.  No
// code execution.
// =====================================================================

/// v1.9.2: keep completed downloads swarm-able after the job ends.
///
/// Without this cache, the SwarmCoordinator stops serving a job's
/// chunks the moment the job completes (the `unregister(jobID:)`
/// call removes it from the active-swarms map, and `payloadResolver`
/// can no longer find it because activeJobs no longer contains the
/// job).  That's not great — a peer that's still pulling chunks
/// loses the seeder mid-flight.
///
/// SwarmContentCache fixes this by indexing completed downloads
/// content-addressed.  The seeder side keeps serving the chunks
/// out of the on-disk file the user already has, for as long as
/// the file remains at its outputPath.
///
/// **What this is:**
///   - A `[String: URL]` mirror of `DownloadHistory.load()`, keyed
///     by `sha256` (when present in the history entry) → the
///     `outputPath` URL.
///   - Refreshed on demand (`refresh()`) and when the VM tells the
///     cache a new entry was recorded (`record(_:)`).
///
/// **What this is NOT:**
///   - A separate disk store / second copy of bytes.
///   - A redirector for missing files — when the user moves or
///     deletes the file from outputPath, lookups return nil and
///     the swarm serves 404.
///   - A network cache.  Bonjour discovery + WAN connections live
///     in FleetCoordinator.
final class SwarmContentCache: @unchecked Sendable {

    private var byDigest: [String: URL] = [:]
    private let lock = NSLock()

    init() {}

    /// Hydrate from `DownloadHistory.load()`.  Skips entries with
    /// no `sha256` field (legacy v0.15 history items) and entries
    /// whose `outputPath` no longer exists (user moved/deleted).
    func refresh(history: [HistoryEntry] = DownloadHistory.load()) {
        var fresh: [String: URL] = [:]
        let fm = FileManager.default
        for e in history {
            guard let digest = e.sha256, !digest.isEmpty else { continue }
            let url = URL(fileURLWithPath: e.outputPath)
            guard fm.fileExists(atPath: url.path) else { continue }
            fresh[digest.lowercased()] = url
        }
        lock.lock()
        byDigest = fresh
        lock.unlock()
    }

    /// Insert / update one entry.  Called from the VM's
    /// `recordHistory(...)` path so freshly-completed downloads
    /// become immediately swarm-able without waiting for the next
    /// refresh.
    func record(_ entry: HistoryEntry) {
        guard let digest = entry.sha256?.lowercased(), !digest.isEmpty else { return }
        let url = URL(fileURLWithPath: entry.outputPath)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        lock.lock()
        byDigest[digest] = url
        lock.unlock()
    }

    /// Remove a digest entry (e.g. when the user deletes a download
    /// from history).  Idempotent — no-op if not present.
    func remove(digest: String) {
        lock.lock()
        byDigest.removeValue(forKey: digest.lowercased())
        lock.unlock()
    }

    /// Lookup — returns the on-disk URL if we have a cached entry
    /// for the digest AND the file still exists.  Performs the
    /// existence check fresh on every call so a deleted file is
    /// reflected immediately in 404 responses.
    func url(forDigest digest: String) -> URL? {
        let key = digest.lowercased()
        lock.lock()
        let candidate = byDigest[key]
        lock.unlock()
        guard let candidate else { return nil }
        if FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        // Missed — clean up the stale entry while we're here.
        lock.lock()
        byDigest.removeValue(forKey: key)
        lock.unlock()
        return nil
    }

    /// Snapshot for tests + UI.  Not part of the runtime path.
    var snapshot: [String: URL] {
        lock.lock()
        defer { lock.unlock() }
        return byDigest
    }

    /// Number of digests currently cached.
    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return byDigest.count
    }
}
