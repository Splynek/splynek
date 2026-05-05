import Foundation

/// Strategy Bet S5 — HLS pre-buffer ring buffer.
///
/// Per-session in-memory cache of HLS segments.  Bytes-bounded
/// (default 256 MB), LRU-evicting.  Designed for one purpose:
/// serve a player's segment GETs from RAM at <1ms latency, while
/// pre-fetcher tasks fill the buffer ahead of the playhead.
///
/// Why in-memory + size-bounded:
/// - HLS segments are 2–10 MB each; a 256 MB buffer holds 25–125
///   segments = 1–4 minutes of playback.
/// - The user's playhead almost never scrubs more than that
///   backwards; forward-scrubs invalidate the buffer anyway.
/// - No reason to hit disk for this — keeps pre-buffering fast
///   and avoids wear on SSDs.
/// - On macOS with 16+ GB RAM, 256 MB is tiny; on 8 GB Macs
///   it's still <4% of RAM; the user's pain point is buffering
///   stalls, not RAM pressure.
///
/// Thread safety: this struct is NOT thread-safe by itself.
/// `HLSProxyServer` wraps each `HLSRingBuffer` in a `@MainActor`
/// owner so all reads/writes serialize through the main actor.
/// The pre-fetch tasks complete on background queues + then
/// enqueue an actor-isolated `insert` call.
public struct HLSRingBuffer: Sendable {

    /// Capacity in bytes.  Default 256 MB.  Caller can override
    /// for low-RAM Macs or larger pre-buffer windows.
    public let capacity: Int64

    public init(capacity: Int64 = 256 * 1024 * 1024) {
        self.capacity = capacity
    }

    /// Map from canonical (absolute) URL → segment bytes.  Order is
    /// LRU: insertion order, most-recently-used at the END (tail).
    /// Eviction always pops from the front (head).
    private(set) var entries: [(url: URL, data: Data)] = []

    /// Total bytes currently held.  Cheaper than recomputing on every
    /// touch; updated on insert + evict.
    private(set) var bytesHeld: Int64 = 0

    public var count: Int { entries.count }

    /// Look up bytes by URL.  Returns nil on miss.  Hits "touch" the
    /// entry so it moves to the tail — protects against eviction
    /// while the player is still requesting it.
    public mutating func get(_ url: URL) -> Data? {
        guard let idx = entries.firstIndex(where: { $0.url == url }) else { return nil }
        let entry = entries.remove(at: idx)
        entries.append(entry)
        return entry.data
    }

    /// True if the URL is in the buffer (no LRU touch — diagnostics
    /// only).  Use `get` for anything that should affect eviction.
    public func contains(_ url: URL) -> Bool {
        entries.contains(where: { $0.url == url })
    }

    /// Insert a fetched segment.  If a previous entry for the same
    /// URL exists, replaces it (and bumps to the tail).  Evicts
    /// from the head until the buffer is at-or-under capacity.
    public mutating func insert(url: URL, data: Data) {
        // Replace existing entry (e.g., re-fetch after expiry).
        if let idx = entries.firstIndex(where: { $0.url == url }) {
            bytesHeld -= Int64(entries[idx].data.count)
            entries.remove(at: idx)
        }
        entries.append((url: url, data: data))
        bytesHeld += Int64(data.count)
        evictUntilUnderCapacity()
    }

    /// Drop everything.  Used when the player switches variant
    /// (the existing buffer's segments belong to the OLD variant
    /// and won't be re-requested).
    public mutating func clear() {
        entries.removeAll()
        bytesHeld = 0
    }

    private mutating func evictUntilUnderCapacity() {
        // Stop at one entry so an oversized just-inserted segment
        // can still serve.  Players occasionally request a single
        // large segment (concatenated VOD, init segments) that
        // dwarfs a tight ring-buffer capacity; better to hold it
        // than to refuse-to-cache an in-flight playback.  When
        // the next insert lands, the oversized entry evicts as
        // it's no longer the most-recent.
        while bytesHeld > capacity, entries.count > 1 {
            let evicted = entries.removeFirst()
            bytesHeld -= Int64(evicted.data.count)
        }
    }

    // MARK: - Diagnostics

    /// Snapshot of the buffer's contents — URLs only, no bytes.  Used
    /// for the Splynek debug surface ("which 47 segments are cached
    /// for stream X right now") + tests.
    public var snapshotURLs: [URL] {
        entries.map(\.url)
    }
}
