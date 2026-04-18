import SwiftUI
import AppKit

/// Sheet presented when the user taps a History row. Preserves the
/// post-download analysis that used to vanish with the JobCard: big
/// speedup factor, per-interface contribution donut, time saved,
/// content hash + Reveal/Open buttons.
///
/// All data is reconstructed from `HistoryEntry`, which already
/// stores `bytesPerInterface`, `secondsSaved`, `totalBytes`,
/// `startedAt`, `finishedAt`, and `sha256`.
struct HistoryDetailSheet: View {
    let entry: HistoryEntry
    let onDismiss: () -> Void

    /// Lazy signature evaluation. Populated on appear (only for
    /// evaluable file types) so opening the sheet is instant; the
    /// card shows a spinner while the three tools run.
    @State private var gatekeeperDetail: GatekeeperDetail?
    @State private var gatekeeperLoading: Bool = false
    @State private var showRawGatekeeper: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(spacing: 16) {
                    speedupCard
                    interfaceBreakdownCard
                    if isGatekeeperEvaluable {
                        signatureCard
                    }
                    metaCard
                }
                .padding(20)
            }
            Divider()
            footer
        }
        .frame(minWidth: 560, minHeight: 520)
        .task { await evaluateSignatureIfNeeded() }
    }

    // MARK: Signature

    private var isGatekeeperEvaluable: Bool {
        let ext = (entry.outputPath as NSString).pathExtension.lowercased()
        return ["app", "pkg", "dmg", "mpkg"].contains(ext)
            && FileManager.default.fileExists(atPath: entry.outputPath)
    }

    private var signatureCard: some View {
        TitledCard(
            title: "Signature",
            systemImage: "lock.shield.fill",
            accessory: AnyView(signatureAccessory)
        ) {
            if gatekeeperLoading, gatekeeperDetail == nil {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Evaluating signature…")
                        .font(.callout).foregroundStyle(.secondary)
                    Spacer()
                }
            } else if let detail = gatekeeperDetail {
                VStack(alignment: .leading, spacing: 8) {
                    row("Source",   detail.source ?? "—")
                    if let origin = detail.origin {
                        row("Origin", origin)
                    }
                    row("Developer ID", detail.authorities.first ?? "—")
                    row("Team ID",  detail.teamID ?? "—")
                    if let cd = detail.cdHashSHA256 {
                        row("CDHash", String(cd.prefix(16)) + "…")
                    }
                    row("Notarization", notarizationLabel(detail.notarizationStapled))
                    if showRawGatekeeper {
                        Divider().opacity(0.3)
                        ScrollView(.vertical) {
                            Text(detail.raw)
                                .font(.system(.caption2, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 160)
                        .padding(8)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(Color.primary.opacity(0.04))
                        )
                    }
                }
            } else {
                Text("Unavailable.")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var signatureAccessory: some View {
        HStack(spacing: 6) {
            if let detail = gatekeeperDetail {
                StatusPill(
                    text: detail.accepted ? "ACCEPTED" : "REJECTED",
                    style: detail.accepted ? .success : .danger
                )
            }
            Button { showRawGatekeeper.toggle() } label: {
                Image(systemName: showRawGatekeeper ? "chevron.up" : "terminal")
            }
            .buttonStyle(.borderless)
            .help(showRawGatekeeper ? "Hide raw tool output" : "Show raw tool output")
            .disabled(gatekeeperDetail == nil)
        }
    }

    private func notarizationLabel(_ stapled: Bool?) -> String {
        switch stapled {
        case .some(true):  return "Stapled (verified offline)"
        case .some(false): return "Not stapled"
        case .none:        return "Unknown"
        }
    }

    private func evaluateSignatureIfNeeded() async {
        guard isGatekeeperEvaluable, gatekeeperDetail == nil, !gatekeeperLoading else {
            return
        }
        gatekeeperLoading = true
        let url = URL(fileURLWithPath: entry.outputPath)
        let detail = await GatekeeperVerify.evaluateDetail(url)
        await MainActor.run {
            self.gatekeeperDetail = detail
            self.gatekeeperLoading = false
        }
    }

    // MARK: Header

    private var header: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "doc.fill")
                .foregroundStyle(.tint)
                .font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.filename)
                    .font(.system(.headline, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                Text(entry.url)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                    .textSelection(.enabled)
            }
            Spacer()
            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 18))
            }
            .buttonStyle(.plain)
        }
        .padding(16)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: Speedup card

    /// If the history entry carries `secondsSaved`, reconstruct the
    /// multiplier that was shown at completion: single-lane duration
    /// would've been (duration + secondsSaved); multi-path took
    /// `duration`. Factor = singleLane / multiPath.
    private var speedupCard: some View {
        TitledCard(title: "Performance", systemImage: "bolt.fill") {
            let dur = max(entry.durationSeconds, 0.001)
            let saved = entry.secondsSaved ?? 0
            let factor = saved > 0 ? (dur + saved) / dur : 1.0
            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", factor))
                            .font(.system(size: 54, weight: .bold, design: .rounded))
                            .foregroundStyle(factor >= 1.5 ? .green : .primary)
                        Text("×")
                            .font(.system(size: 34, weight: .semibold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Text("vs. best single-path estimate")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Divider().frame(height: 60)
                MetricView(value: formatDuration(dur), caption: "Duration")
                if saved >= 1 {
                    MetricView(value: formatDuration(saved),
                               caption: "Time saved",
                               tint: .green)
                }
                MetricView(value: formatRate(entry.avgThroughputBps),
                           caption: "Avg. throughput",
                           tint: .accentColor)
                Spacer()
            }
        }
    }

    // MARK: Interface breakdown

    private var interfaceBreakdownCard: some View {
        TitledCard(title: "Interface contribution", systemImage: "chart.pie.fill") {
            let total = entry.bytesPerInterface.values.reduce(0, +)
            if total <= 0 || entry.bytesPerInterface.isEmpty {
                Text("No per-interface data recorded for this download.")
                    .font(.callout).foregroundStyle(.secondary)
            } else {
                let sorted = entry.bytesPerInterface.sorted { $0.value > $1.value }
                VStack(alignment: .leading, spacing: 10) {
                    stackedBar(sorted: sorted, total: total)
                    ForEach(Array(sorted.enumerated()), id: \.offset) { idx, pair in
                        let (name, bytes) = pair
                        let frac = Double(bytes) / Double(total)
                        HStack(spacing: 8) {
                            Circle()
                                .fill(color(for: idx))
                                .frame(width: 10, height: 10)
                            Text(name)
                                .font(.system(.callout, design: .monospaced,
                                              weight: .medium))
                                .frame(width: 100, alignment: .leading)
                            Text(String(format: "%.1f%%", frac * 100))
                                .font(.system(.callout, design: .monospaced,
                                              weight: .semibold))
                                .frame(width: 70, alignment: .leading)
                                .monospacedDigit()
                            Text(formatBytes(bytes))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Spacer()
                        }
                    }
                }
            }
        }
    }

    /// Horizontal stacked bar — one colour per interface, widths
    /// proportional to contribution.
    private func stackedBar(sorted: [(key: String, value: Int64)],
                             total: Int64) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(Array(sorted.enumerated()), id: \.offset) { idx, pair in
                    let frac = Double(pair.value) / Double(total)
                    Rectangle()
                        .fill(color(for: idx))
                        .frame(width: max(1, geo.size.width * frac))
                }
            }
            .frame(height: 14)
            .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .frame(height: 14)
    }

    private func color(for idx: Int) -> Color {
        let palette: [Color] = [
            .accentColor, .green, .orange, .pink, .purple, .cyan, .yellow
        ]
        return palette[idx % palette.count]
    }

    // MARK: Meta

    private var metaCard: some View {
        TitledCard(title: "Details", systemImage: "info.circle") {
            VStack(alignment: .leading, spacing: 8) {
                row("Size",      formatBytes(entry.totalBytes))
                row("Started",   entry.startedAt.formatted(date: .abbreviated, time: .shortened))
                row("Finished",  entry.finishedAt.formatted(date: .abbreviated, time: .shortened))
                if let sha = entry.sha256, !sha.isEmpty {
                    row("SHA-256", String(sha.prefix(16)) + "…")
                }
                row("Output",    entry.outputPath)
            }
        }
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
                .textCase(.uppercase).tracking(0.6)
                .frame(width: 80, alignment: .leading)
            Text(value)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1).truncationMode(.middle)
            Spacer(minLength: 0)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([
                    URL(fileURLWithPath: entry.outputPath)
                ])
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
            .buttonStyle(.bordered)
            .disabled(!FileManager.default.fileExists(atPath: entry.outputPath))

            Button {
                NSWorkspace.shared.open(URL(fileURLWithPath: entry.outputPath))
            } label: {
                Label("Open", systemImage: "arrow.up.right.square")
            }
            .buttonStyle(.bordered)
            .disabled(!FileManager.default.fileExists(atPath: entry.outputPath))

            Spacer()

            Button {
                onDismiss()
            } label: {
                Text("Done")
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
    }
}
