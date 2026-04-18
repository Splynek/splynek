import Foundation
import Network
import CryptoKit

// MARK: - Published lane stats

/// Per-interface aggregate stats. If multiple sub-workers are running on the
/// same interface (intra-lane parallelism), they share one LaneStats.
@MainActor
final class LaneStats: ObservableObject, Identifiable {
    let interface: DiscoveredInterface
    nonisolated var id: String { interface.id }

    @Published var bytesTotal: Int64 = 0
    @Published var chunksDone: Int = 0
    @Published var errors: Int = 0
    /// Chunks requeued because this lane's mirror returned 416. Counted
    /// separately from `errors` so fleet-peer cooperation doesn't look
    /// like network flakiness in the health score.
    @Published var chunksSkipped: Int = 0
    @Published var activeChunks: Int = 0
    @Published private(set) var throughputBps: Double = 0
    /// Rolling history of throughput samples (sampled at 1 Hz, newest last).
    @Published private(set) var history: [Double] = []
    /// Median of the last `rttCapacity` time-to-first-byte samples (seconds).
    @Published private(set) var medianRTT: TimeInterval = 0
    /// 0–100 composite health score. Drops when errors spike or RTT
    /// variance relative to the median rises. The engine stops dispatching
    /// to a lane that stays below `unhealthyThreshold` for long.
    @Published private(set) var healthScore: Double = 100
    /// Remote IP we connected to (post-DoH / resolution). Surfaced as
    /// "connection-path transparency" in the lane card.
    @Published var connectedTo: String = ""
    /// True once the engine has decided to stop dispatching to this lane.
    @Published var failedOver: Bool = false

    nonisolated static let unhealthyThreshold: Double = 25

    private var window: [(Date, Int64)] = []
    private var recentRTTs: [TimeInterval] = []
    private static let rttCapacity = 20
    private static let historyCapacity = 120  // 2 minutes at 1 Hz

    init(interface: DiscoveredInterface) { self.interface = interface }

    func record(_ n: Int) {
        bytesTotal += Int64(n)
        let now = Date()
        window.append((now, Int64(n)))
        let cutoff = now.addingTimeInterval(-1.0)
        while let first = window.first, first.0 < cutoff { window.removeFirst() }
        let span = max(now.timeIntervalSince(window.first?.0 ?? now), 0.001)
        throughputBps = Double(window.reduce(0) { $0 + $1.1 }) / span
    }

    func sampleHistory() {
        history.append(throughputBps)
        if history.count > Self.historyCapacity { history.removeFirst(history.count - Self.historyCapacity) }
    }

    func recordRTT(_ rtt: TimeInterval) {
        recentRTTs.append(rtt)
        if recentRTTs.count > Self.rttCapacity {
            recentRTTs.removeFirst(recentRTTs.count - Self.rttCapacity)
        }
        let sorted = recentRTTs.sorted()
        medianRTT = sorted[sorted.count / 2]
        recomputeHealth()
    }

    /// Recompute the 0–100 health score from observed signal:
    ///   - errors in the last ~window degrade it fast
    ///   - RTT variance > 3× median degrades it moderately
    /// Stays at 100 when everything's quiet.
    func recomputeHealth() {
        var score: Double = 100
        // Errors: each error deducts 15, up to 75.
        score -= min(Double(errors) * 15, 75)
        // RTT spike: current last > 3× median.
        if recentRTTs.count >= 3, medianRTT > 0,
           let latest = recentRTTs.last, latest > medianRTT * 3 {
            score -= 20
        }
        // Empty activity with errors: penalise harder.
        if chunksDone == 0, errors > 0 { score -= 10 }
        healthScore = max(0, min(100, score))
    }

    func reset() {
        bytesTotal = 0; chunksDone = 0; errors = 0; activeChunks = 0
        throughputBps = 0; history = []
        window.removeAll()
    }
}

/// Post-mortem summary shown when a download completes. The
/// "screenshot moment" that makes Splynek's value concrete.
struct DownloadReport: Codable, Hashable {
    var totalBytes: Int64
    var durationSeconds: Double
    /// Bytes attributed to each interface (by BSD name).
    var bytesPerInterface: [String: Int64]
    /// Average-throughput estimate if only the single best lane had been
    /// used, derived from that lane's per-chunk rate during the actual run.
    var singleLaneEstimateBps: Double
    var aggregateBps: Double

    /// Savings as a multiplier: 2.5 ⇒ "2.5× faster."
    var speedupFactor: Double {
        guard singleLaneEstimateBps > 0 else { return 1 }
        return aggregateBps / singleLaneEstimateBps
    }

    /// Estimated time saved vs. single-lane hypothesis.
    var secondsSaved: Double {
        guard singleLaneEstimateBps > 0 else { return 0 }
        let singleLaneDuration = Double(totalBytes) / singleLaneEstimateBps
        return max(0, singleLaneDuration - durationSeconds)
    }
}

@MainActor
final class DownloadProgress: ObservableObject {
    @Published var totalBytes: Int64 = 0
    @Published var downloaded: Int64 = 0
    @Published var lanes: [LaneStats] = []
    @Published var started: Date = .distantPast
    @Published var finished: Bool = false
    @Published var errorMessage: String? = nil
    @Published var gatekeeper: GatekeeperVerdict = .pending
    @Published var resumed: Bool = false  // true if we picked up from a sidecar
    @Published var report: DownloadReport?
    /// Which logical stage of the pipeline is running right now.
    /// Drives the Phase strip in the Live view.
    @Published var phase: Phase = .pending

    enum Phase: String, CaseIterable, Sendable {
        case pending     = "Queued"
        case probing     = "Probing"
        case planning    = "Planning"
        case connecting  = "Connecting"
        case downloading = "Downloading"
        case verifying   = "Verifying"
        case gatekeeper  = "Gatekeeper"
        case done        = "Done"

        var systemImage: String {
            switch self {
            case .pending:     return "hourglass"
            case .probing:     return "questionmark.circle"
            case .planning:    return "list.number"
            case .connecting:  return "link"
            case .downloading: return "arrow.down.circle"
            case .verifying:   return "checkmark.seal"
            case .gatekeeper:  return "lock.shield"
            case .done:        return "checkmark.circle.fill"
            }
        }
    }

    var fraction: Double { totalBytes > 0 ? Double(downloaded) / Double(totalBytes) : 0 }
    var throughputBps: Double { lanes.reduce(0) { $0 + $1.throughputBps } }

    func tickHistory() { for l in lanes { l.sampleHistory() } }
}

// MARK: - Chunk queue

actor ChunkQueue {
    private var chunks: [Chunk]
    init(_ chunks: [Chunk]) { self.chunks = chunks }

    func takeNext() -> Chunk? {
        guard let idx = chunks.firstIndex(where: { !$0.done && $0.downloaded == 0 }) else {
            return nil
        }
        var c = chunks[idx]
        c.downloaded = -1  // sentinel: in-flight
        chunks[idx] = c
        return c
    }

    func markDone(_ id: Int) -> [Int] {
        if let i = chunks.firstIndex(where: { $0.id == id }) {
            chunks[i].done = true
        }
        return chunks.filter(\.done).map(\.id)
    }

    func requeue(_ id: Int) {
        if let i = chunks.firstIndex(where: { $0.id == id }) {
            chunks[i].downloaded = 0
        }
    }

    func allDone() -> Bool { chunks.allSatisfy { $0.done } }
    func snapshot() -> [Chunk] { chunks }
    func prefillDone(_ ids: Set<Int>) {
        for i in 0..<chunks.count where ids.contains(chunks[i].id) {
            chunks[i].done = true
        }
    }
}

// MARK: - Engine

/// Orchestrates discovery, chunk planning, lane workers (with intra-lane
/// parallelism), resume via sidecar, history persistence, and post-download
/// Gatekeeper evaluation.
final class DownloadEngine {

    static let chunkBytes: Int64 = 4 * 1024 * 1024

    let urls: [URL]
    let outputURL: URL
    let interfaces: [DiscoveredInterface]
    let sha256Expected: String?
    let connectionsPerInterface: Int
    let useDoH: Bool
    let merkleManifest: MerkleManifest?
    let extraHeaders: [String: String]
    /// Per-interface `TokenBucket`s, keyed by BSD name, injected by the
    /// ViewModel so caps are enforced globally across concurrent jobs.
    /// Missing entries fall back to an unlimited per-engine bucket.
    let sharedBuckets: [String: TokenBucket]
    let progress: DownloadProgress

    private let cancelFlag = CancelFlag()
    private var historyTimerTask: Task<Void, Never>?
    private var sidecarURL: URL { outputURL.appendingPathExtension("splynek") }

    init(
        urls: [URL],
        outputURL: URL,
        interfaces: [DiscoveredInterface],
        sha256Expected: String?,
        connectionsPerInterface: Int,
        useDoH: Bool,
        merkleManifest: MerkleManifest? = nil,
        extraHeaders: [String: String] = [:],
        sharedBuckets: [String: TokenBucket] = [:],
        progress: DownloadProgress
    ) {
        precondition(!urls.isEmpty, "DownloadEngine needs at least one URL")
        self.urls = urls
        self.outputURL = outputURL
        self.interfaces = interfaces
        self.sha256Expected = sha256Expected
        self.connectionsPerInterface = max(1, connectionsPerInterface)
        self.useDoH = useDoH
        self.merkleManifest = merkleManifest
        self.extraHeaders = extraHeaders
        self.sharedBuckets = sharedBuckets
        self.progress = progress
    }

    /// Primary URL, used for probing and filename derivation.
    var url: URL { urls[0] }

    func cancel() { cancelFlag.cancel(); historyTimerTask?.cancel() }

    // MARK: Main run loop

    func run() async {
        let startTime = Date()
        do {
            await MainActor.run { progress.phase = .probing }
            let probed = try await Probe.run(url, extraHeaders: extraHeaders)
            guard probed.supportsRange else {
                await report("Server doesn't advertise Range support; aggregation impossible.")
                return
            }

            // Prepare output file (resume-aware).
            await MainActor.run { progress.phase = .planning }
            let resumeInfo = loadSidecar(for: probed)
            await MainActor.run {
                progress.totalBytes = probed.totalBytes
                progress.started = startTime
                progress.lanes = interfaces.map { LaneStats(interface: $0) }
                progress.resumed = resumeInfo != nil
            }
            if resumeInfo == nil {
                try preallocate(path: outputURL, size: probed.totalBytes)
            }

            let chunks = planChunks(total: probed.totalBytes)
            let queue = ChunkQueue(chunks)
            if let ri = resumeInfo {
                await queue.prefillDone(Set(ri.completed))
                let already = chunks.filter { ri.completed.contains($0.id) }.reduce(0) { $0 + $1.length }
                await MainActor.run { progress.downloaded = already }
            }

            let laneStats = await MainActor.run { progress.lanes }
            startHistorySampler()
            await MainActor.run { progress.phase = .connecting }

            // If the caller passed multiple mirror URLs, each is a valid fetch
            // source; the probed finalURL becomes one of many.
            let laneURLs: [URL] = urls.count == 1 ? [probed.finalURL] : urls
            await MainActor.run { progress.phase = .downloading }
            try await runWorkers(
                laneURLs: laneURLs,
                queue: queue,
                laneStats: laneStats,
                totalChunks: chunks.count,
                probe: probed
            )

            historyTimerTask?.cancel()

            if cancelFlag.isCancelled {
                // Leave the sidecar in place so the next run can resume.
                await report("Cancelled.")
                return
            }

            try? FileManager.default.removeItem(at: sidecarURL)
            await MainActor.run { progress.phase = .verifying }

            // Always compute the file's SHA-256 on completion. Two reasons:
            //   1. If the user supplied an expected hash we compare.
            //   2. Either way, the digest feeds the fleet's content-
            //      addressed index — downstream Splyneks on the LAN can
            //      fetch *this* file by content hash without re-downloading
            //      from the origin.
            let contentHash: String = (try? sha256(of: outputURL)) ?? ""
            if let want = sha256Expected, !contentHash.isEmpty,
               contentHash.lowercased() != want.lowercased() {
                await report("SHA-256 mismatch: expected \(want), got \(contentHash)")
                return
            }
            if let manifest = merkleManifest,
               let expectedRoot = Data(hexEncoded: manifest.rootHex) {
                let computedRoot = MerkleTree.root(leaves: manifest.leafHashes)
                guard computedRoot == expectedRoot else {
                    await report("Merkle root mismatch against manifest.")
                    return
                }
            }

            await MainActor.run { progress.phase = .gatekeeper }
            Quarantine.mark(outputURL)
            let verdict = await GatekeeperVerify.evaluate(outputURL)

            // Build the download report before flipping `finished`.
            let report = await MainActor.run { () -> DownloadReport in
                let dur = max(0.001, Date().timeIntervalSince(progress.started))
                let bytesPerIface = Dictionary(
                    uniqueKeysWithValues: progress.lanes.map {
                        ($0.interface.name, $0.bytesTotal)
                    }
                )
                let bestLaneBps = progress.lanes
                    .map { Double($0.bytesTotal) / dur }
                    .max() ?? 0
                let aggregate = Double(progress.totalBytes) / dur
                return DownloadReport(
                    totalBytes: progress.totalBytes,
                    durationSeconds: dur,
                    bytesPerInterface: bytesPerIface,
                    singleLaneEstimateBps: bestLaneBps,
                    aggregateBps: aggregate
                )
            }
            await MainActor.run {
                progress.gatekeeper = verdict
                progress.report = report
                progress.finished = true
                progress.phase = .done
            }
            Notifier.post(
                title: "Download complete",
                body: outputURL.lastPathComponent,
                subtitle: ByteCountFormatter.string(fromByteCount: probed.totalBytes,
                                                    countStyle: .binary)
            )

            let totalBytes = probed.totalBytes
            let laneBytes = await MainActor.run {
                Dictionary(uniqueKeysWithValues: progress.lanes.map { ($0.interface.name, $0.bytesTotal) })
            }
            DownloadHistory.record(
                HistoryEntry(
                    id: UUID(),
                    url: url.absoluteString,
                    filename: outputURL.lastPathComponent,
                    outputPath: outputURL.path,
                    totalBytes: totalBytes,
                    bytesPerInterface: laneBytes,
                    startedAt: startTime,
                    finishedAt: Date(),
                    sha256: contentHash.isEmpty
                        ? sha256Expected
                        : contentHash.lowercased(),
                    secondsSaved: report.secondsSaved
                )
            )
            // QA P2 #10 (v0.43): the lane-level HostUsage.credit
            // call lives inside LaneConnection.streamRange. Tiny
            // files and single-shot paths occasionally skip that
            // code (e.g., the whole payload arrives in the first
            // probe read), leaving the host row blank. Reconcile
            // on completion — if the per-host tally is less than
            // what the download actually pulled, top up the
            // difference so "Today by host" never silently
            // undercounts a real completion.
            if let host = url.host, !host.isEmpty, totalBytes > 0 {
                let alreadyCredited = HostUsage.entry(for: host)?.bytesToday ?? 0
                // Heuristic: credit the shortfall. This can over-
                // count by a little if the user downloads the same
                // host's files in rapid succession between the
                // credit and this reconciliation, but never by a
                // whole download — and under-counting is the
                // bigger UX wart.
                let shortfall = totalBytes - alreadyCredited
                if shortfall > 0 && alreadyCredited < totalBytes / 2 {
                    HostUsage.credit(host: host, bytes: shortfall)
                }
            }
        } catch {
            historyTimerTask?.cancel()
            await report(error.localizedDescription)
        }
    }

    // MARK: Worker spawn

    private func runWorkers(
        laneURLs: [URL],
        queue: ChunkQueue,
        laneStats: [LaneStats],
        totalChunks: Int,
        probe: ProbeResult
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for (idx, iface) in interfaces.enumerated() {
                guard let nw = iface.nwInterface else { continue }
                // Caller (the VM) must inject a shared bucket per interface
                // so caps apply globally across concurrent jobs. If it
                // didn't, create an uncapped bucket — matches the old
                // per-engine behaviour for ad-hoc callers.
                let bucket = sharedBuckets[iface.name]
                    ?? TokenBucket(ratePerSec: 0)
                for subIdx in 0..<connectionsPerInterface {
                    // Distribute mirrors across sub-workers round-robin by
                    // (interface, subIndex). Keep-alive stays intact because
                    // each sub-worker locks to one URL for its lifetime.
                    let assigned = laneURLs[(idx * connectionsPerInterface + subIdx) % laneURLs.count]
                    group.addTask { [self] in
                        try await runSubLane(
                            interfaceNW: nw,
                            interfaceIndex: idx,
                            subIndex: subIdx,
                            stats: laneStats[idx],
                            queue: queue,
                            finalURL: assigned,
                            bucket: bucket,
                            probe: probe
                        )
                    }
                }
            }
            try await group.waitForAll()
        }
    }

    // MARK: Sub-lane worker

    private func runSubLane(
        interfaceNW: NWInterface,
        interfaceIndex: Int,
        subIndex: Int,
        stats: LaneStats,
        queue: ChunkQueue,
        finalURL: URL,
        bucket: TokenBucket,
        probe: ProbeResult
    ) async throws {
        let lane = LaneConnection(
            url: finalURL, interface: interfaceNW,
            bandwidth: bucket, cancelFlag: cancelFlag,
            useDoH: useDoH,
            extraHeaders: extraHeaders
        )
        lane.onConnected = { ip in
            Task { @MainActor in stats.connectedTo = ip }
        }
        defer { lane.close() }

        var errorStreak = 0
        while !cancelFlag.isCancelled {
            if await queue.allDone() { return }
            // Auto-failover: stop dispatching if this lane has decayed
            // past the unhealthy threshold AND has sustained errors.
            let snap = await MainActor.run {
                (stats.healthScore, stats.errors, stats.chunksDone)
            }
            if snap.0 < LaneStats.unhealthyThreshold,
               snap.1 >= 3, snap.2 == 0 {
                await MainActor.run { stats.failedOver = true }
                return
            }
            guard let chunk = await queue.takeNext() else {
                try? await Task.sleep(nanoseconds: 100_000_000)
                continue
            }
            await MainActor.run { stats.activeChunks += 1 }

            do {
                let handle = try FileHandle(forWritingTo: outputURL)
                defer { try? handle.close() }
                try handle.seek(toOffset: UInt64(chunk.start))

                let counter = AtomicCounter()
                let streamed = try await lane.fetch(
                    start: chunk.start, end: chunk.end,
                    onBytes: { piece in
                        try? handle.write(contentsOf: piece)
                        counter.add(Int64(piece.count))
                    },
                    onRTT: { rtt in
                        Task { @MainActor in stats.recordRTT(rtt) }
                    }
                )
                if streamed != chunk.length, !cancelFlag.isCancelled {
                    throw RangeError.prematureEOF
                }

                // Per-chunk Merkle integrity check. If the manifest's chunk
                // layout matches ours, verify leaf-then-proof. Mismatch ⇒
                // treat the chunk as failed so it'll be re-fetched.
                if let manifest = merkleManifest,
                   manifest.chunkSize == Self.chunkBytes,
                   chunk.id < manifest.leafHashes.count {
                    let expectedLeaf = manifest.leafHashes[chunk.id]
                    let leafOnDisk = try readAndHashChunk(chunk)
                    if leafOnDisk != expectedLeaf {
                        throw RangeError.prematureEOF   // recycled through requeue path
                    }
                }

                let bytesDone = counter.value
                let completedIds = await queue.markDone(chunk.id)
                await MainActor.run {
                    stats.record(Int(bytesDone))
                    stats.chunksDone += 1
                    stats.activeChunks = max(0, stats.activeChunks - 1)
                    progress.downloaded += bytesDone
                }
                // Persist resume state after each finished chunk.
                saveSidecar(
                    url: finalURL,
                    total: probe.totalBytes,
                    etag: probe.etag,
                    lastModified: probe.lastModified,
                    completed: completedIds
                )
                errorStreak = 0
            } catch RangeError.rangeNotAvailable {
                // This mirror (typically a fleet peer with a partial
                // download) doesn't have this chunk yet. Requeue the
                // chunk for any other lane to pick up. Don't count this
                // as a lane error — the lane is healthy and may succeed
                // on the next chunk the peer does have. Record a hop
                // via `chunksSkipped` so the UI can surface cooperative
                // fleet activity.
                await queue.requeue(chunk.id)
                await MainActor.run {
                    stats.chunksSkipped += 1
                    stats.activeChunks = max(0, stats.activeChunks - 1)
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                await queue.requeue(chunk.id)
                await MainActor.run {
                    stats.errors += 1
                    stats.activeChunks = max(0, stats.activeChunks - 1)
                }
                errorStreak = min(errorStreak + 1, 6)
                let delay = 0.25 * pow(2.0, Double(errorStreak - 1))
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }
    }

    // MARK: History sampler (1 Hz)

    private func startHistorySampler() {
        historyTimerTask?.cancel()
        historyTimerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                if Task.isCancelled { break }
                await MainActor.run { [weak self] in self?.progress.tickHistory() }
            }
        }
    }

    // MARK: Sidecar load/save

    private func loadSidecar(for probe: ProbeResult) -> SidecarState? {
        guard let data = try? Data(contentsOf: sidecarURL),
              let state = try? JSONDecoder().decode(SidecarState.self, from: data),
              state.url == probe.finalURL.absoluteString,
              state.total == probe.totalBytes,
              state.chunkSize == Self.chunkBytes,
              FileManager.default.fileExists(atPath: outputURL.path)
        else { return nil }
        // ETag / Last-Modified must match if both sides have one.
        if let saved = state.etag, let got = probe.etag, saved != got { return nil }
        if state.etag == nil,
           let savedLM = state.lastModified,
           let gotLM = probe.lastModified,
           savedLM != gotLM { return nil }
        return state
    }

    private func saveSidecar(
        url: URL, total: Int64, etag: String?, lastModified: String?, completed: [Int]
    ) {
        let state = SidecarState(
            url: url.absoluteString,
            total: total,
            etag: etag,
            lastModified: lastModified,
            chunkSize: Self.chunkBytes,
            completed: completed
        )
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: sidecarURL, options: .atomic)
        }
    }

    // MARK: Helpers

    private func planChunks(total: Int64) -> [Chunk] {
        var chunks: [Chunk] = []
        var pos: Int64 = 0
        var id = 0
        while pos < total {
            let end = min(pos + Self.chunkBytes - 1, total - 1)
            chunks.append(Chunk(id: id, start: pos, end: end))
            pos = end + 1
            id += 1
        }
        return chunks
    }

    private func preallocate(path: URL, size: Int64) throws {
        let fm = FileManager.default
        try? fm.removeItem(at: path)
        fm.createFile(atPath: path.path, contents: nil)
        let handle = try FileHandle(forWritingTo: path)
        try handle.truncate(atOffset: UInt64(size))
        try handle.close()
    }

    /// Read a specific chunk back from the file and compute its Merkle leaf
    /// hash. Used only when a manifest is supplied.
    private func readAndHashChunk(_ chunk: Chunk) throws -> Data {
        let h = try FileHandle(forReadingFrom: outputURL)
        defer { try? h.close() }
        try h.seek(toOffset: UInt64(chunk.start))
        let data = try h.read(upToCount: Int(chunk.length)) ?? Data()
        return MerkleTree.leafHash(data)
    }

    private func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while true {
            let data = try handle.read(upToCount: 1 << 20) ?? Data()
            if data.isEmpty { break }
            hasher.update(data: data)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private func report(_ message: String) async {
        await MainActor.run { progress.errorMessage = message }
    }
}

