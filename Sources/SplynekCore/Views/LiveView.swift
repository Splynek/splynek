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
                if running.isEmpty {
                    emptyState
                } else {
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
