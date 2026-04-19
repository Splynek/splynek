import Foundation
import Network

/// A discovered interface we can egress through. May have IPv4, IPv6, or both.
struct DiscoveredInterface: Identifiable, Hashable, Sendable {
    /// Classification of the physical link. Drives the sidebar icon
    /// and the "expensive" flag (for cellular budgeting).
    ///
    /// v0.46: added `.iPhoneUSB` so the interface row labels an
    /// iPhone USB tether correctly. macOS reports it via
    /// `NWInterface.InterfaceType.wiredEthernet` (it IS
    /// Ethernet-over-USB), so without a specific check it used to
    /// show up as "ETH" — confusing when users are on Wi-Fi only
    /// and suddenly see a second "ETH" row.
    enum Kind: String, Sendable { case wifi, ethernet, cellular, iPhoneUSB, other }

    let name: String
    let ipv4: String?
    let ipv6: String?
    let ifindex: UInt32
    let kind: Kind
    let nwInterface: NWInterface?

    var id: String { name }

    var primaryIP: String { ipv4 ?? ipv6 ?? "?" }

    var label: String {
        switch kind {
        case .wifi:       return "WIFI"
        case .ethernet:   return "ETH"
        case .cellular:   return "CELL"
        case .iPhoneUSB:  return "iPhone"
        case .other:      return "OTHER"
        }
    }

    /// Heuristic: cellular links (and iPhone USB tether, which is
    /// ultimately cellular bandwidth) are treated as metered. Drives
    /// default selection and the "metered-safe" confirmation flow.
    var isExpensive: Bool { kind == .cellular || kind == .iPhoneUSB }

    static func == (lhs: DiscoveredInterface, rhs: DiscoveredInterface) -> Bool {
        lhs.name == rhs.name && lhs.ipv4 == rhs.ipv4 && lhs.ipv6 == rhs.ipv6
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(name); hasher.combine(ipv4); hasher.combine(ipv6)
    }
}

/// One chunk of the target file.
struct Chunk: Identifiable, Equatable, Sendable {
    let id: Int
    let start: Int64   // inclusive
    let end: Int64     // inclusive
    var downloaded: Int64 = 0
    var done: Bool = false

    var length: Int64 { end - start + 1 }
}

struct ProbeResult: Sendable {
    let totalBytes: Int64
    let supportsRange: Bool
    let suggestedFilename: String
    let finalURL: URL
    let etag: String?
    let lastModified: String?
}

/// "Fire once" latch used to guard single-shot continuations against state
/// callbacks that can fire multiple times.
final class ResumeGate: @unchecked Sendable {
    private let lock = NSLock()
    private var fired = false
    func fire() -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard !fired else { return false }
        fired = true
        return true
    }
}

/// Thread-safe Int64 accumulator used to bridge background byte counts into
/// other isolation domains without captured-var data races.
final class AtomicCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var n: Int64 = 0
    func add(_ m: Int64) { lock.lock(); n += m; lock.unlock() }
    var value: Int64 { lock.lock(); defer { lock.unlock() }; return n }
    func reset() { lock.lock(); n = 0; lock.unlock() }
}

/// Cancel flag + onCancel handler registry. Lane code registers handlers so
/// in-flight NWConnections get torn down promptly when the user hits Cancel.
final class CancelFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var flag = false
    private var handlers: [() -> Void] = []

    var isCancelled: Bool { lock.lock(); defer { lock.unlock() }; return flag }

    func onCancel(_ handler: @escaping @Sendable () -> Void) {
        lock.lock()
        if flag { lock.unlock(); handler(); return }
        handlers.append(handler)
        lock.unlock()
    }

    func cancel() {
        lock.lock()
        guard !flag else { lock.unlock(); return }
        flag = true
        let snapshot = handlers; handlers = []
        lock.unlock()
        for h in snapshot { h() }
    }
}

/// Simple token-bucket rate limiter. Used for per-lane bandwidth caps.
/// `ratePerSec == 0` disables the cap.
actor TokenBucket {
    private(set) var ratePerSec: Int64
    private var tokens: Double
    private var lastRefill: Date

    init(ratePerSec: Int64) {
        self.ratePerSec = ratePerSec
        self.tokens = Double(ratePerSec)
        self.lastRefill = Date()
    }

    func setRate(_ rate: Int64) {
        ratePerSec = rate
        tokens = Double(rate)
        lastRefill = Date()
    }

    func take(_ n: Int64) async {
        guard ratePerSec > 0 else { return }
        while true {
            refill()
            if tokens >= Double(n) { tokens -= Double(n); return }
            let needed = Double(n) - tokens
            let waitSec = max(0.01, needed / Double(ratePerSec))
            try? await Task.sleep(nanoseconds: UInt64(waitSec * 1_000_000_000))
        }
    }

    private func refill() {
        let now = Date()
        let elapsed = now.timeIntervalSince(lastRefill)
        if elapsed <= 0 { return }
        let add = Double(ratePerSec) * elapsed
        // Cap at 1 second of burst to avoid huge bursts after long idle.
        tokens = min(tokens + add, Double(ratePerSec))
        lastRefill = now
    }
}

/// Minimal record saved to Application Support after each completed download.
struct HistoryEntry: Codable, Identifiable, Hashable {
    var id: UUID
    var url: String
    var filename: String
    var outputPath: String
    var totalBytes: Int64
    var bytesPerInterface: [String: Int64]
    var startedAt: Date
    var finishedAt: Date
    var sha256: String?
    /// Estimated seconds saved vs a single-interface baseline, derived
    /// from the DownloadReport at completion. Optional so legacy v0.15
    /// history files load cleanly.
    var secondsSaved: Double?

    var durationSeconds: Double { finishedAt.timeIntervalSince(startedAt) }
    var avgThroughputBps: Double {
        let d = durationSeconds
        return d > 0 ? Double(totalBytes) / d : 0
    }
}

/// Sidecar file written next to the in-progress output. Used to resume
/// a download after an app crash / reboot / intentional pause.
struct SidecarState: Codable {
    var url: String            // final URL we were fetching
    var total: Int64           // expected total size
    var etag: String?          // if server sent one
    var lastModified: String?  // if server sent one
    var chunkSize: Int64       // chunking granularity used
    var completed: [Int]       // indices of chunks already finished
    var version: Int = 1
}

/// Gatekeeper's verdict on a completed download, surfaced to the UI so the
/// user can see it before double-clicking.
enum GatekeeperVerdict: Equatable {
    case notApplicable           // file type we don't evaluate
    case pending                 // not yet checked
    case accepted(String)        // spctl output line
    case rejected(String)
    case unavailable(String)     // spctl missing or errored
}
