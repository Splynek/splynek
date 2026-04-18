import SwiftUI

/// Live dashboard for active downloads. Deliberately loud — big
/// headline throughput, per-interface cards, full-width progress, and
/// a phase strip that makes the engine's pipeline legible instead of
/// hiding it.
///
/// Renders one section per running job. When nothing is running,
/// falls back to a calm empty state pointing the user back to
/// Downloads.
struct LiveView: View {
    @ObservedObject var vm: SplynekViewModel

    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                PageHeader(
                    systemImage: "waveform.circle.fill",
                    title: "Live",
                    subtitle: "What the engine is doing right now. One section per running download — throughput, interface breakdown, pipeline stage."
                )

                let running = vm.activeJobs.filter {
                    $0.lifecycle == .running || $0.lifecycle == .paused
                }
                let showTorrent = vm.isTorrenting
                if running.isEmpty && !showTorrent {
                    emptyState
                } else {
                    if showTorrent {
                        TorrentLiveCard(vm: vm, progress: vm.torrentProgress)
                    }
                    ForEach(running) { job in
                        jobCard(job)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: 900)
        }
        .frame(maxWidth: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Live")
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "antenna.radiowaves.left.and.right.slash")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)
            Text("No active downloads")
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text("Start one from the Downloads tab or the Assistant, and it'll show up here in real time.")
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .padding(.vertical, 80)
        .frame(maxWidth: .infinity)
    }

    // MARK: Per-job card

    @ViewBuilder
    private func jobCard(_ job: DownloadJob) -> some View {
        LiveJobCard(job: job, vm: vm)
    }
}

/// Self-contained live card for one download. Separated so each card
/// has its own `@ObservedObject` binding on the job's progress —
/// parent-level ObservedObject would still work but this makes
/// rendering boundaries cleaner.
struct LiveJobCard: View {
    @ObservedObject var job: DownloadJob
    let vm: SplynekViewModel
    @ObservedObject var progress: DownloadProgress

    init(job: DownloadJob, vm: SplynekViewModel) {
        self.job = job
        self.vm = vm
        _progress = ObservedObject(wrappedValue: job.progress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            filenameRow

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                bigRate
                Spacer()
                controls
            }

            GradientProgressBar(fraction: progress.fraction, height: 10)

            HStack(spacing: 24) {
                MetricView(value: progress.phase.rawValue,
                           caption: "Phase", tint: phaseTint)
                MetricView(
                    value: percentString,
                    caption: "Complete", tint: .green
                )
                MetricView(
                    value: "\(formatBytes(progress.downloaded)) / \(formatBytes(progress.totalBytes))",
                    caption: "Bytes", monospaced: true
                )
                MetricView(
                    value: etaText,
                    caption: "ETA"
                )
                Spacer()
            }

            phaseStrip

            if !progress.lanes.isEmpty {
                laneGrid
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
    }

    // MARK: Filename row

    private var filenameRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down.circle.fill")
                .foregroundStyle(.tint)
            Text(job.outputURL.lastPathComponent)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(1).truncationMode(.middle)
            Text("·").foregroundStyle(.secondary)
            Text(job.url.host ?? job.url.absoluteString)
                .font(.caption).foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            if job.lifecycle == .paused {
                StatusPill(text: "PAUSED", style: .warning)
            } else {
                StatusPill(text: "LIVE", style: .success)
            }
        }
    }

    // MARK: Big rate

    private var bigRate: some View {
        let (value, unit) = rateParts(progress.throughputBps)
        return HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    /// Split a bytes-per-second number into headline + unit so the
    /// two can be typographically distinct (big + small).
    private func rateParts(_ bps: Double) -> (String, String) {
        let units: [(Double, String)] = [
            (1_000_000_000, "GB/s"),
            (1_000_000,     "MB/s"),
            (1_000,         "KB/s")
        ]
        for (threshold, unit) in units where bps >= threshold {
            return (String(format: "%.1f", bps / threshold), unit)
        }
        return (String(format: "%.0f", bps), "B/s")
    }

    // MARK: Transport controls

    private var controls: some View {
        HStack(spacing: 8) {
            if job.lifecycle == .running {
                Button {
                    vm.pauseJob(job)
                } label: {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.orange)
                }
                .buttonStyle(.plain)
                .help("Pause")
            } else if job.lifecycle == .paused {
                Button {
                    vm.resumeJob(job)
                } label: {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.green)
                }
                .buttonStyle(.plain)
                .help("Resume")
            }
            Button(role: .destructive) {
                job.cancel()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help("Cancel")
        }
    }

    // MARK: Phase strip

    /// Pills for every pipeline phase, with the current one highlighted
    /// and upstream phases marked complete.
    private var phaseStrip: some View {
        let ordered = DownloadProgress.Phase.allCases
        let currentIndex = ordered.firstIndex(of: progress.phase) ?? 0
        return HStack(spacing: 6) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { idx, phase in
                phasePill(phase, idx: idx, currentIndex: currentIndex)
                if idx < ordered.count - 1 {
                    Rectangle()
                        .fill(idx < currentIndex
                              ? Color.accentColor.opacity(0.4)
                              : Color.primary.opacity(0.12))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func phasePill(_ phase: DownloadProgress.Phase,
                           idx: Int, currentIndex: Int) -> some View {
        let isCurrent = idx == currentIndex
        let isPast    = idx < currentIndex
        let tint: Color = isCurrent ? .accentColor : (isPast ? .green : .secondary)
        let bg: Color   = isCurrent ? Color.accentColor.opacity(0.18)
                        : (isPast ? Color.green.opacity(0.14)
                                  : Color.primary.opacity(0.05))
        HStack(spacing: 4) {
            Image(systemName: phase.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(phase.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(bg))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(isCurrent ? 0.6 : 0.0), lineWidth: 1)
        )
    }

    private var phaseTint: Color {
        switch progress.phase {
        case .pending, .probing, .planning: return .secondary
        case .connecting, .downloading:     return .accentColor
        case .verifying, .gatekeeper:       return .orange
        case .done:                         return .green
        }
    }

    // MARK: Lane grid

    private var laneGrid: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Interfaces")
                .font(.caption).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.6)
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 200), spacing: 12)
            ], spacing: 12) {
                ForEach(progress.lanes) { lane in
                    laneCard(lane)
                }
            }
        }
    }

    private func laneCard(_ lane: LaneStats) -> some View {
        let totalDone = progress.lanes.reduce(Int64(0)) { $0 + $1.bytesTotal }
        let share = totalDone > 0 ? Double(lane.bytesTotal) / Double(totalDone) : 0
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: lane.interface.kind == .wifi ? "wifi"
                      : lane.interface.kind == .ethernet ? "cable.connector"
                      : "antenna.radiowaves.left.and.right")
                    .foregroundStyle(.tint)
                Text(lane.interface.name)
                    .font(.system(.callout, design: .monospaced, weight: .semibold))
                Spacer()
                if lane.failedOver {
                    StatusPill(text: "FAILOVER", style: .warning)
                }
            }
            HStack(alignment: .lastTextBaseline, spacing: 4) {
                Text(formatRate(lane.throughputBps))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .monospacedDigit()
                    .contentTransition(.numericText())
            }
            HStack(spacing: 10) {
                Label("\(lane.chunksDone) chunks",
                      systemImage: "square.stack.3d.up.fill")
                    .font(.caption).foregroundStyle(.secondary)
                Label(String(format: "%.0f%% share", share * 100),
                      systemImage: "chart.pie.fill")
                    .font(.caption).foregroundStyle(.secondary)
            }
            if lane.medianRTT > 0 {
                Label(String(format: "RTT %.0fms", lane.medianRTT * 1000),
                      systemImage: "clock")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.1), lineWidth: 0.5)
        )
    }

    // MARK: Derived strings

    private var percentString: String {
        String(format: "%.1f%%", progress.fraction * 100)
    }

    private var etaText: String {
        guard progress.totalBytes > 0,
              progress.throughputBps > 0,
              !progress.finished else { return "—" }
        return formatDuration(
            Double(progress.totalBytes - progress.downloaded) / progress.throughputBps
        )
    }
}

// MARK: - Torrent

/// Canonical pipeline vocabulary shared with the HTTP phase strip so the
/// Live dashboard reads the same story regardless of transport. The engine
/// emits freeform `progress.phase` strings; `infer(...)` collapses them
/// (plus piece/finished/seeding state) down to one of these six pills.
enum TorrentLivePhase: String, CaseIterable {
    case announcing       = "Announcing"
    case fetchingMetadata = "Fetching metadata"
    case connecting       = "Connecting to peers"
    case downloading      = "Downloading"
    case seeding          = "Seeding"
    case done             = "Done"

    var systemImage: String {
        switch self {
        case .announcing:       return "megaphone.fill"
        case .fetchingMetadata: return "doc.text.magnifyingglass"
        case .connecting:       return "link"
        case .downloading:      return "arrow.down.circle.fill"
        case .seeding:          return "antenna.radiowaves.left.and.right"
        case .done:             return "checkmark.circle.fill"
        }
    }

    /// Pure mapper from engine-emitted state to a pipeline pill. Kept as
    /// primitives (not TorrentProgress) so the test harness can pin every
    /// transition without standing up a MainActor.
    static func infer(
        phase: String,
        piecesDone: Int,
        finished: Bool,
        seedingListening: Bool
    ) -> TorrentLivePhase {
        if finished {
            return seedingListening ? .seeding : .done
        }
        let lower = phase.lowercased()
        // Partial-seed-while-leech: the engine is both seeding and still
        // fetching pieces. The downloading state is more informative for
        // the user than the seeding badge here; show seeding only when
        // it's the dominant activity (post-completion) which the branch
        // above already covers.
        if piecesDone > 0 { return .downloading }
        if lower.contains("metadata")          { return .fetchingMetadata }
        if lower.contains("connecting")        { return .connecting }
        if lower.contains("seeding stopped")   { return .done }
        if lower.contains("seeding")           { return .seeding }
        return .announcing
    }
}

/// Lightweight 1-Hz throughput sampler for a TorrentProgress. `TorrentEngine`
/// doesn't publish a rate directly (pieces arrive in bursts and the UI
/// wants a smoothed number), so we derive one from `downloaded` deltas
/// over a short rolling window.
@MainActor
final class TorrentRateSampler: ObservableObject {
    @Published var throughputBps: Double = 0
    private var samples: [(time: TimeInterval, bytes: Int64)] = []
    private var timer: Timer?

    func start(tracking progress: TorrentProgress) {
        stop()
        let t = Timer(timeInterval: 1.0, repeats: true) { [weak self, weak progress] _ in
            Task { @MainActor in
                guard let self, let progress else { return }
                self.sample(progress.downloaded)
            }
        }
        RunLoop.main.add(t, forMode: .common)
        self.timer = t
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        samples.removeAll()
        throughputBps = 0
    }

    private func sample(_ downloaded: Int64) {
        let now = Date().timeIntervalSinceReferenceDate
        samples.append((now, downloaded))
        // ~8-second rolling window — long enough to smooth piece bursts,
        // short enough that the number still reacts to slowdowns.
        while let first = samples.first, now - first.time > 8 {
            samples.removeFirst()
        }
        guard let first = samples.first, let last = samples.last,
              samples.count >= 2 else {
            throughputBps = 0
            return
        }
        let span = last.time - first.time
        guard span > 0 else { return }
        let delta = last.bytes - first.bytes
        throughputBps = delta > 0 ? Double(delta) / span : 0
    }
}

/// Torrent-flavoured sibling to `LiveJobCard`. Shares the visual grammar
/// (72-pt headline, phase strip, big metrics) but swaps lane stats for the
/// torrent-native signals: peers, pieces, endgame, seeding uptime.
struct TorrentLiveCard: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var progress: TorrentProgress
    @StateObject private var rate = TorrentRateSampler()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            titleRow

            HStack(alignment: .lastTextBaseline, spacing: 10) {
                bigRate
                Spacer()
                controls
            }

            GradientProgressBar(fraction: progress.fraction, height: 10)

            HStack(spacing: 24) {
                MetricView(value: currentPhase.rawValue,
                           caption: "Phase", tint: phaseTint)
                MetricView(
                    value: String(format: "%.1f%%", progress.fraction * 100),
                    caption: "Complete", tint: .green
                )
                MetricView(
                    value: "\(progress.piecesDone)/\(progress.pieces)",
                    caption: "Pieces", monospaced: true
                )
                MetricView(
                    value: "\(progress.activePeers)/\(progress.peers)",
                    caption: "Peers (active / known)"
                )
                Spacer()
            }

            phaseStrip

            if let seed = progress.seeding, seed.listening {
                seedingStrip(seed)
            }

            if let err = progress.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(err).font(.callout)
                }
            }
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 4, x: 0, y: 1)
        .onAppear { rate.start(tracking: progress) }
        .onDisappear { rate.stop() }
    }

    // MARK: Rows

    private var titleRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .foregroundStyle(.tint)
            Text(progress.name.isEmpty ? "Torrent" : progress.name)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            if progress.endgame {
                StatusPill(text: "ENDGAME", style: .warning)
            }
            if currentPhase == .seeding {
                StatusPill(text: "SEEDING", style: .info)
            } else if progress.finished {
                StatusPill(text: "COMPLETE", style: .success)
            } else {
                StatusPill(text: "LIVE", style: .success)
            }
        }
    }

    private var bigRate: some View {
        let (value, unit) = rateParts(rate.throughputBps)
        return HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(value)
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(unit)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)
        }
    }

    private func rateParts(_ bps: Double) -> (String, String) {
        let units: [(Double, String)] = [
            (1_000_000_000, "GB/s"),
            (1_000_000,     "MB/s"),
            (1_000,         "KB/s")
        ]
        for (threshold, unit) in units where bps >= threshold {
            return (String(format: "%.1f", bps / threshold), unit)
        }
        return (String(format: "%.0f", bps), "B/s")
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button(role: .destructive) {
                vm.cancelTorrent()
            } label: {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(.red)
            }
            .buttonStyle(.plain)
            .help(currentPhase == .seeding ? "Stop seeding" : "Cancel")
        }
    }

    // MARK: Phase strip

    private var currentPhase: TorrentLivePhase {
        TorrentLivePhase.infer(
            phase: progress.phase,
            piecesDone: progress.piecesDone,
            finished: progress.finished,
            seedingListening: progress.seeding?.listening ?? false
        )
    }

    private var phaseStrip: some View {
        let ordered = TorrentLivePhase.allCases
        let currentIndex = ordered.firstIndex(of: currentPhase) ?? 0
        return HStack(spacing: 6) {
            ForEach(Array(ordered.enumerated()), id: \.offset) { idx, phase in
                phasePill(phase, idx: idx, currentIndex: currentIndex)
                if idx < ordered.count - 1 {
                    Rectangle()
                        .fill(idx < currentIndex
                              ? Color.accentColor.opacity(0.4)
                              : Color.primary.opacity(0.12))
                        .frame(height: 1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }

    @ViewBuilder
    private func phasePill(_ phase: TorrentLivePhase,
                           idx: Int, currentIndex: Int) -> some View {
        let isCurrent = idx == currentIndex
        let isPast    = idx < currentIndex
        let tint: Color = isCurrent ? .accentColor : (isPast ? .green : .secondary)
        let bg: Color   = isCurrent ? Color.accentColor.opacity(0.18)
                        : (isPast ? Color.green.opacity(0.14)
                                  : Color.primary.opacity(0.05))
        HStack(spacing: 4) {
            Image(systemName: phase.systemImage)
                .font(.system(size: 10, weight: .semibold))
            Text(phase.rawValue)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(Capsule(style: .continuous).fill(bg))
        .overlay(
            Capsule(style: .continuous)
                .strokeBorder(tint.opacity(isCurrent ? 0.6 : 0.0), lineWidth: 1)
        )
    }

    private var phaseTint: Color {
        switch currentPhase {
        case .announcing, .fetchingMetadata: return .secondary
        case .connecting, .downloading:      return .accentColor
        case .seeding:                       return .orange
        case .done:                          return .green
        }
    }

    // MARK: Seeding strip

    private func seedingStrip(_ seed: SeedingProgress) -> some View {
        HStack(spacing: 16) {
            Label("Port \(seed.port)", systemImage: "number")
                .font(.caption).foregroundStyle(.secondary)
            Label("\(seed.connectedPeers) leechers",
                  systemImage: "person.2.fill")
                .font(.caption).foregroundStyle(.secondary)
            Label("Uploaded \(formatBytes(seed.bytesServed))",
                  systemImage: "arrow.up.circle")
                .font(.caption).foregroundStyle(.secondary)
            Label("Up \(formatDuration(seed.uptime))",
                  systemImage: "clock")
                .font(.caption).foregroundStyle(.secondary)
            Spacer()
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }
}
