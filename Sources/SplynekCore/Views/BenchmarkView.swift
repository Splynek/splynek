import SwiftUI
import AppKit

struct BenchmarkView: View {
    @ObservedObject var vm: SplynekViewModel
    // 2026-05-06 fix: was @StateObject — got destroyed on tab switch +
    // re-created with empty state.  Now points at the VM-owned
    // singleton so the in-flight probe state persists across tab
    // switches (user switches away, comes back, sees the same live
    // throughput readout instead of a "cancelled" appearance).
    @ObservedObject private var runner: BenchmarkRunner
    @State private var urlText: String = BenchmarkRunner.defaultURLString

    init(vm: SplynekViewModel) {
        self.vm = vm
        _runner = ObservedObject(wrappedValue: vm.benchmarkRunner)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContextCard(
                    systemImage: "bolt.fill",
                    subtitle: "Measure single-path versus multi-path throughput against a CDN-backed URL. Real engine, real bytes — export the result as a shareable PNG.",
                    tint: .yellow
                )
                sourceCard
                interfacesCard
                if !runner.results.isEmpty || runner.isRunning {
                    resultsCard
                }
                explainerCard
            }
            .padding(20)
            .animation(.easeInOut(duration: 0.2), value: runner.results.count)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Benchmark")
        .toolbar {
            // v0.46: the Run button moved inline into the source
            // card below the URL field — much more discoverable than
            // tucked in the toolbar corner. Toolbar keeps only the
            // post-run Copy + Save image actions, which make sense
            // here because they export the whole-tab state.
            ToolbarItemGroup(placement: .primaryAction) {
                if !runner.results.isEmpty && !runner.isRunning {
                    Button {
                        let text = runner.plainTextSummary(
                            url: URL(string: urlText)
                                ?? URL(string: BenchmarkRunner.defaultURLString)!
                        )
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(text, forType: .string)
                    } label: {
                        Label("Copy results", systemImage: "doc.on.clipboard")
                    }
                    .help("Copy a plain-text summary of the results to the clipboard.")
                    Button {
                        saveShareableImage()
                    } label: {
                        Label("Save image…", systemImage: "photo")
                    }
                    .help("Render a 1200×630 PNG for sharing on social media.")
                }
            }
        }
    }

    /// Render the shareable PNG and pop a save panel. 1200×630 is
    /// Twitter / X / Bluesky / LinkedIn's OG-image aspect ratio, so
    /// the card looks right wherever it's posted.
    private func saveShareableImage() {
        guard let url = URL(string: urlText)
                ?? URL(string: BenchmarkRunner.defaultURLString) else { return }
        let device = Host.current().localizedName
            ?? ProcessInfo.processInfo.hostName
        guard let image = BenchmarkImage.render(
            url: url, probes: runner.results, device: device
        ), let png = BenchmarkImage.pngData(image) else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "splynek-benchmark.png"
        panel.allowedContentTypes = [.png]
        panel.canCreateDirectories = true
        if panel.runModal() == .OK, let dest = panel.url {
            try? png.write(to: dest, options: .atomic)
        }
    }

    // MARK: Source

    private var sourceCard: some View {
        TitledCard(title: "Benchmark target", systemImage: "link") {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "globe").foregroundStyle(.secondary)
                    TextField(BenchmarkRunner.defaultURLString, text: $urlText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .disabled(runner.isRunning)
                    Button("Reset") {
                        urlText = BenchmarkRunner.defaultURLString
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                    .disabled(runner.isRunning)
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                Text("Pick a CDN-backed URL with `Accept-Ranges: bytes`. The default is Hetzner's 100 MB speed-test file.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                // v0.46 fix: the Run button used to live only in the
                // toolbar (top-right corner), which many users never
                // found. Also surface it prominently here, right
                // under the target URL where the eye is already
                // looking. The toolbar copy still works for keyboard
                // shortcuts and muscle memory.
                if runner.isRunning {
                    // 2026-05-06 fix: previous UI was just a 1-line
                    // spinner + phase text — users couldn't tell
                    // anything was happening for the 5-30s a probe
                    // takes.  Now: spinner + phase + LIVE throughput
                    // + bytes / expected progress bar so progress is
                    // visible second-by-second.
                    runningProgressBlock
                } else {
                    HStack(spacing: 10) {
                        Button { runBenchmark() } label: {
                            Label("Run benchmark", systemImage: "bolt.fill")
                                .frame(minWidth: 140)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .keyboardShortcut(.return)
                        .disabled(URL(string: urlText) == nil
                                  || vm.interfaces.filter { $0.nwInterface != nil }.isEmpty)
                        .help("Run the benchmark: single-path vs multi-path throughput across every selected interface (⏎).")
                        if !runner.results.isEmpty {
                            Text("Results below ↓")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    /// Live progress block while a probe is running.  Shows three rows:
    ///   1. Spinner + phase text ("Single-path through en0…")
    ///   2. Progress bar (live bytes / expected)
    ///   3. Throughput stat (live MB/s + bytes downloaded / expected)
    ///
    /// Plus a Cancel button so users can abort without waiting for
    /// the whole probe ladder to finish.  (Cancel just sets a flag
    /// the runner observes — implemented in BenchmarkRunner.cancel().)
    private var runningProgressBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text(runner.phase)
                    .font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            // Progress bar: indeterminate-looking when totalBytes
            // is unknown (server didn't report Content-Length yet),
            // determinate as soon as we have a target size.
            if runner.liveExpectedBytes > 0 {
                let fraction = min(1.0, Double(runner.liveBytes)
                                          / Double(runner.liveExpectedBytes))
                GradientProgressBar(fraction: fraction, height: 6)
            } else {
                ProgressView().progressViewStyle(.linear)
            }
            // Stat row.  formatBytes / formatThroughput already exist
            // in this file (used by the results table).
            HStack(spacing: 14) {
                if runner.liveBytes > 0 {
                    Text(formatBytes(runner.liveBytes))
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                    if runner.liveExpectedBytes > 0 {
                        Text("/ \(formatBytes(runner.liveExpectedBytes))")
                            .font(.system(.callout, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
                if runner.liveThroughputBps > 0 {
                    Text("·")
                        .foregroundStyle(.secondary)
                    Text(formatRate(runner.liveThroughputBps))
                        .font(.system(.callout, design: .monospaced).weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                }
                Spacer()
            }
        }
        .padding(.top, 4)
    }

    // MARK: Interfaces (read-only preview)

    private var interfacesCard: some View {
        TitledCard(title: "Interfaces in play", systemImage: "network") {
            if vm.interfaces.isEmpty {
                EmptyStateView(
                    systemImage: "network.slash",
                    title: "Discovering interfaces…",
                    message: nil
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(vm.interfaces.filter { $0.nwInterface != nil }) { iface in
                        HStack(spacing: 12) {
                            Image(systemName: icon(for: iface.kind))
                                .foregroundStyle(kindTint(iface.kind))
                                .frame(width: 22)
                            Text(iface.name)
                                .font(.system(.body, design: .monospaced))
                            Text(iface.label)
                                .font(.caption2).foregroundStyle(.secondary)
                            Spacer()
                            Text(iface.primaryIP)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.primary.opacity(0.03))
                        )
                    }
                }
            }
        }
    }

    // MARK: Results — single-path vs multi-path side-by-side

    private var resultsCard: some View {
        let maxBps = runner.results.map(\.throughputBps).max() ?? 1
        return TitledCard(
            title: "Results",
            systemImage: "chart.bar.fill",
            accessory: summaryPillComputed
        ) {
            VStack(spacing: 10) {
                ForEach(runner.results) { (probe: BenchmarkRunner.Probe) in
                    ProbeRow(probe: probe, maxBps: maxBps)
                }
            }
        }
    }

    @ViewBuilder
    /// Speedup pill computed via a single-expression chain.  The
    /// previous shapes (var with conditional return, func with
    /// guard return) both tripped Swift's implicit @ViewBuilder
    /// treatment of properties on View-conforming structs.
    /// Single-expression body via `flatMap` produces no return
    /// statement at all → no builder conflict.
    private var summaryPillComputed: AnyView? {
        speedupFactor.map { factor in
            AnyView(StatusPill(
                text: String(format: "%.1f×", factor),
                style: .success
            ))
        }
    }

    /// Pure data accessor for the speedup factor — extracted from
    /// `summaryPillComputed` so the View-bearing property has a
    /// single-expression body.
    private var speedupFactor: Double? {
        let single = runner.results.filter { !$0.label.hasPrefix("Multi") }
        guard let multi = runner.results.first(where: { $0.label.hasPrefix("Multi") }),
              let bestSingle = single.map(\.throughputBps).max(),
              bestSingle > 0
        else { return nil }
        return multi.throughputBps / bestSingle
    }

    private var explainerCard: some View {
        TitledCard(title: "What this measures", systemImage: "info.circle") {
            Text("Splynek downloads the target URL through each interface individually, then through all of them aggregated. Temp files are placed in `/tmp/` and deleted after each probe, so the benchmark touches only network + CPU. The multi-path number is the real-world aggregate using keep-alive HTTP/1.1 lanes bound via `IP_BOUND_IF`.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Actions

    private func runBenchmark() {
        guard let url = URL(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        let ifaces = vm.interfaces
        Task { await runner.run(url: url, interfaces: ifaces) }
    }

    // MARK: Styling helpers

    private func icon(for kind: DiscoveredInterface.Kind) -> String {
        switch kind {
        case .wifi:      return "wifi"
        case .ethernet:  return "cable.connector"
        case .cellular:  return "antenna.radiowaves.left.and.right"
        case .iPhoneUSB: return "iphone"
        case .other:     return "network"
        }
    }

    private func kindTint(_ kind: DiscoveredInterface.Kind) -> Color {
        switch kind {
        case .wifi:      return .blue
        case .ethernet:  return .green
        case .cellular:  return .pink
        case .iPhoneUSB: return .cyan
        case .other:     return .secondary
        }
    }
}

/// One row of the results table. Extracted so the type-checker
/// doesn't have to solve the whole ForEach body as one expression.
private struct ProbeRow: View {
    let probe: BenchmarkRunner.Probe
    let maxBps: Double

    private var isMulti: Bool { probe.label.hasPrefix("Multi") }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: probe.kindIcon)
                    .foregroundStyle(isMulti ? Color.yellow : Color.accentColor)
                    .frame(width: 18)
                Text(probe.label)
                    .font(.system(.body, design: .monospaced))
                    .fontWeight(isMulti ? .semibold : .regular)
                Spacer()
                Text(formatRate(probe.throughputBps))
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .monospacedDigit()
                    .foregroundStyle(probe.error == nil ? Color.primary : Color.red)
                Text(String(format: "%.1fs", probe.durationSeconds))
                    .font(.caption).foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 50, alignment: .trailing)
            }
            if probe.error == nil {
                BenchmarkBar(
                    fraction: maxBps > 0 ? probe.throughputBps / maxBps : 0,
                    isMulti: isMulti
                )
            } else if let err = probe.error {
                Text(err).font(.caption).foregroundStyle(.red)
            }
        }
    }
}

/// Thin horizontal bar used in the benchmark results. The multi-path row
/// gets a yellow gradient so it stands out against single-path rows.
private struct BenchmarkBar: View {
    let fraction: Double
    let isMulti: Bool

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color.primary.opacity(0.08))
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: isMulti
                                ? [.yellow.opacity(0.85), .orange]
                                : [.accentColor.opacity(0.85), .accentColor],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, min(1, fraction)) * geo.size.width)
                    .animation(.spring(response: 0.5, dampingFraction: 0.85),
                               value: fraction)
            }
        }
        .frame(height: 10)
    }
}
