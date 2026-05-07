import Foundation

/// Run a URL through each interface individually, then through all of
/// them aggregated. Reports the throughput side-by-side so the
/// multi-interface win is observable, not just claimed.
///
/// Each probe spawns a real DownloadEngine against a temp file, which
/// means the benchmark exercises the full stack — keep-alive, DoH
/// (if enabled), per-chunk work-stealing, the shared TokenBucket, the
/// lot. Temp files are deleted after each probe.
@MainActor
final class BenchmarkRunner: ObservableObject {

    struct Probe: Identifiable, Hashable {
        let id: UUID = UUID()
        var label: String
        var kindIcon: String
        var throughputBps: Double
        var bytes: Int64
        var durationSeconds: Double
        var error: String?
    }

    @Published var results: [Probe] = []
    @Published var isRunning: Bool = false
    @Published var phase: String = ""

    /// Live progress for the in-flight probe.  2026-05-06 fix: the
    /// previous UI showed only `phase + spinner` while a probe ran,
    /// which made multi-second downloads feel like nothing was
    /// happening.  These three properties are polled by the run
    /// loop every 250 ms and surface throughput / bytes / expected
    /// in the source-card row so the user sees live activity.
    @Published var liveBytes: Int64 = 0
    @Published var liveExpectedBytes: Int64 = 0
    @Published var liveThroughputBps: Double = 0

    /// Default target — Hetzner's 100 MB file is a conventional benchmark
    /// target that's CDN-backed, range-capable, and free.
    static let defaultURLString = "https://ash-speed.hetzner.com/100MB.bin"

    /// Run a benchmark pass: every interface in `interfaces` individually,
    /// then the aggregate (only if there are 2+ interfaces). Sequential
    /// so the single-path numbers aren't contaminated by the others
    /// running at the same time.
    func run(url: URL, interfaces: [DiscoveredInterface]) async {
        isRunning = true
        results = []
        defer { isRunning = false }

        let pickable = interfaces.filter { $0.nwInterface != nil }
        guard !pickable.isEmpty else {
            phase = "No interfaces available."
            return
        }

        for iface in pickable {
            phase = "Single-path through \(iface.name)…"
            let r = await probe(
                url: url,
                interfaces: [iface],
                label: iface.name,
                icon: icon(for: iface.kind)
            )
            results.append(r)
        }

        if pickable.count >= 2 {
            phase = "Aggregate through \(pickable.count) interfaces…"
            let r = await probe(
                url: url,
                interfaces: pickable,
                label: "Multi-path (\(pickable.count))",
                icon: "bolt.fill"
            )
            results.append(r)
        }

        phase = "Done."
    }

    // MARK: Probe

    private func probe(
        url: URL,
        interfaces: [DiscoveredInterface],
        label: String,
        icon: String
    ) async -> Probe {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-bench-\(UUID().uuidString).bin")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let progress = DownloadProgress()
        progress.lanes = interfaces.map { LaneStats(interface: $0) }
        let engine = DownloadEngine(
            urls: [url],
            outputURL: tmp,
            interfaces: interfaces,
            sha256Expected: nil,
            connectionsPerInterface: 1,
            useDoH: false,
            progress: progress
        )
        let started = Date()

        // 2026-05-06 fix: poll the progress object every 250 ms during
        // the probe and surface bytes / throughput / expected on the
        // runner's @Published properties so the UI shows live activity.
        // Earlier UX: just a spinner + phase text — users couldn't tell
        // anything was happening.  The poll task cancels itself when
        // the engine.run() completes (we cancel + await it explicitly).
        liveBytes = 0
        liveExpectedBytes = 0
        liveThroughputBps = 0
        let pollTask = Task { [weak self] in
            while !Task.isCancelled {
                let now = Date()
                let elapsed = max(0.001, now.timeIntervalSince(started))
                let bytes = progress.downloaded
                let total = progress.totalBytes
                await MainActor.run {
                    self?.liveBytes = bytes
                    self?.liveExpectedBytes = total
                    self?.liveThroughputBps = Double(bytes) / elapsed
                }
                try? await Task.sleep(nanoseconds: 250_000_000)
            }
        }

        await engine.run()
        pollTask.cancel()

        let duration = max(0.001, Date().timeIntervalSince(started))
        let bytes = progress.downloaded
        let bps = Double(bytes) / duration

        // Drop the live state — the next probe's first poll will
        // reset it; clearing here makes the inter-probe transition
        // visually clean (the live row goes blank for a frame
        // rather than showing stale numbers from the prior probe).
        liveBytes = 0
        liveExpectedBytes = 0
        liveThroughputBps = 0

        return Probe(
            label: label,
            kindIcon: icon,
            throughputBps: bps,
            bytes: bytes,
            durationSeconds: duration,
            error: progress.errorMessage
        )
    }

    private func icon(for kind: DiscoveredInterface.Kind) -> String {
        switch kind {
        case .wifi:      return "wifi"
        case .ethernet:  return "cable.connector"
        case .cellular:  return "antenna.radiowaves.left.and.right"
        case .iPhoneUSB: return "iphone"
        case .other:     return "network"
        }
    }

    // MARK: Export

    /// Plain-text summary for the "Copy results" button. Renders as a
    /// fixed-width column layout so it pastes cleanly anywhere.
    func plainTextSummary(url: URL) -> String {
        guard !results.isEmpty else { return "" }
        var lines: [String] = [
            "Splynek benchmark — \(url.absoluteString)",
            String(repeating: "-", count: 48)
        ]
        for r in results {
            lines.append(String(format: "%-20s  %10s   %.2fs",
                                (r.label as NSString).utf8String!,
                                formatRate(r.throughputBps),
                                r.durationSeconds))
        }
        if let best = results.map(\.throughputBps).max(),
           let worst = results.map(\.throughputBps).min(),
           worst > 0 {
            lines.append(String(repeating: "-", count: 48))
            lines.append(String(format: "Best / worst: %.2f×", best / worst))
        }
        return lines.joined(separator: "\n")
    }
}
