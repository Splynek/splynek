import SwiftUI
import QuickLook

struct HistoryView: View {
    @ObservedObject var vm: SplynekViewModel
    @State private var searchText: String = ""
    @State private var previewURL: URL?
    /// Entry the user just tapped — drives `HistoryDetailSheet`.
    @State private var detailEntry: HistoryEntry?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    systemImage: "clock.arrow.circlepath",
                    title: "History",
                    subtitle: "Every completed download, searchable by filename, URL or host — and by natural language when a local LLM is available."
                )
                if vm.history.isEmpty {
                    TitledCard(title: "History", systemImage: "clock.arrow.circlepath") {
                        EmptyStateView(
                            systemImage: "tray",
                            title: "Nothing downloaded yet",
                            message: "Finished downloads will show up here."
                        )
                    }
                } else {
                    summaryCard
                    todayByHostCard
                    if vm.aiAvailable {
                        aiSearchBar
                    }
                    searchBar
                    listCard
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("History")
        .quickLookPreview($previewURL)
        .sheet(item: $detailEntry) { entry in
            HistoryDetailSheet(entry: entry) {
                detailEntry = nil
            }
        }
    }

    private var filtered: [HistoryEntry] {
        // AI search wins if present — it's the explicit active filter.
        // The indices it returns are already ranked; preserve that order.
        if !vm.aiHistoryHits.isEmpty {
            return vm.aiHistoryHits.compactMap { idx in
                (0..<vm.history.count).contains(idx) ? vm.history[idx] : nil
            }
        }
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return vm.history.reversed() }
        return vm.history.reversed().filter { entry in
            entry.filename.lowercased().contains(q)
                || entry.url.lowercased().contains(q)
                || (URL(string: entry.url)?.host?.lowercased().contains(q) ?? false)
        }
    }

    /// Natural-language history search — purple-tinted, hidden when
    /// Ollama isn't detected. Mirrors the AI row in DownloadView so the
    /// feature is visually consistent across the app.
    @State private var aiQuery: String = ""
    private var aiSearchBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                    .font(.system(size: 13, weight: .bold))
                TextField("Ask — “that docker iso from last Tuesday”",
                          text: $aiQuery)
                    .textFieldStyle(.plain)
                    .font(.system(.callout))
                    .disabled(vm.aiHistoryThinking)
                    .onSubmit {
                        vm.searchHistoryViaAI(aiQuery)
                    }
                if vm.aiHistoryThinking {
                    ProgressView().controlSize(.small)
                } else if !vm.aiHistoryQuery.isEmpty {
                    Button {
                        aiQuery = ""
                        vm.clearAIHistorySearch()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Button {
                        vm.searchHistoryViaAI(aiQuery)
                    } label: {
                        Label("Ask", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(aiQuery.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.purple.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.purple.opacity(0.25), lineWidth: 0.5)
            )
            if !vm.aiHistoryQuery.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("AI results for “\(vm.aiHistoryQuery)” — \(vm.aiHistoryHits.count) match\(vm.aiHistoryHits.count == 1 ? "" : "es")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }

    private var summaryCard: some View {
        let totalBytes = vm.history.reduce(Int64(0)) { $0 + $1.totalBytes }
        let totalDuration = vm.history.reduce(0.0) { $0 + $1.durationSeconds }
        let avgBps = totalDuration > 0 ? Double(totalBytes) / totalDuration : 0
        let saved = vm.history.reduce(0.0) { $0 + ($1.secondsSaved ?? 0) }
        return TitledCard(title: "Lifetime", systemImage: "chart.bar") {
            HStack(spacing: 24) {
                MetricView(value: "\(vm.history.count)", caption: "Downloads")
                MetricView(value: formatBytes(totalBytes), caption: "Bytes")
                MetricView(value: formatRate(avgBps),
                           caption: "Avg throughput", tint: .accentColor)
                if saved >= 1 {
                    MetricView(value: formatDuration(saved),
                               caption: "Time saved", tint: .green)
                }
                Spacer()
            }
        }
    }

    @ViewBuilder
    private var todayByHostCard: some View {
        if !vm.topHosts.isEmpty {
            TitledCard(title: "Today by host", systemImage: "globe") {
                VStack(spacing: 4) {
                    ForEach(vm.topHosts) { entry in
                        HostRow(entry: entry, vm: vm)
                    }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search by filename, URL, or host", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .default))
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
            }
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
    }

    private var listCard: some View {
        let results = filtered
        return TitledCard(
            title: searchText.isEmpty ? "Recent" : "Results",
            systemImage: "list.bullet.rectangle",
            accessory: searchText.isEmpty ? nil : AnyView(
                Text("\(results.count) of \(vm.history.count)")
                    .font(.caption).foregroundStyle(.secondary)
            )
        ) {
            if results.isEmpty {
                EmptyStateView(
                    systemImage: "magnifyingglass",
                    title: "No matches",
                    message: "Nothing in history matches your search."
                )
            } else {
                VStack(spacing: 6) {
                    ForEach(results, id: \.id) { entry in
                        HistoryRow(
                            entry: entry,
                            previewURL: $previewURL,
                            onShowDetail: { detailEntry = entry }
                        )
                    }
                }
            }
        }
    }
}

private struct HostRow: View {
    let entry: HostUsageEntry
    let vm: SplynekViewModel
    @State private var capGB: Double = 0

    var body: some View {
        HStack(spacing: 10) {
            Text(entry.host)
                .font(.system(.callout, design: .monospaced))
                .lineLimit(1).truncationMode(.middle)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(formatBytes(entry.bytesToday))
                .font(.system(.callout, design: .monospaced, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(entry.isOverCap ? Color.red : Color.primary)
                .frame(width: 100, alignment: .trailing)
            HStack(spacing: 3) {
                Text("cap").font(.caption2).foregroundStyle(.secondary)
                TextField("∞", value: $capGB,
                          format: .number.precision(.fractionLength(1)))
                    .frame(width: 54)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    .onChange(of: capGB) { new in
                        vm.setHostDailyCap(entry.host,
                                           bytes: Int64(new * 1024 * 1024 * 1024))
                    }
                Text("GB").font(.caption2).foregroundStyle(.secondary)
            }
            if entry.isOverCap {
                StatusPill(text: "OVER", style: .danger)
            }
        }
        .padding(.vertical, 4).padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(entry.isOverCap ? Color.red.opacity(0.06) : Color.primary.opacity(0.03))
        )
        .onAppear {
            capGB = Double(entry.dailyCap) / (1024 * 1024 * 1024)
        }
    }
}

private struct HistoryRow: View {
    let entry: HistoryEntry
    @Binding var previewURL: URL?
    var onShowDetail: () -> Void = {}

    private var fileURL: URL { URL(fileURLWithPath: entry.outputPath) }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc")
                .foregroundStyle(.secondary)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.filename)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                Text(URL(string: entry.url)?.host ?? entry.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
            }
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 2) {
                Text(formatBytes(entry.totalBytes))
                    .font(.system(.callout, design: .monospaced))
                    .monospacedDigit()
                Text(formatRate(entry.avgThroughputBps))
                    .font(.caption).foregroundStyle(Color.accentColor)
                    .monospacedDigit()
            }
            Text(entry.finishedAt, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 90, alignment: .trailing)
            Button {
                onShowDetail()
            } label: {
                Image(systemName: "info.circle")
                    .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.borderless)
            .help("Show download analysis (speedup, interface contribution, time saved).")

            Button {
                previewURL = fileURL
            } label: {
                Image(systemName: "eye.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Quick Look.")
            .disabled(!FileManager.default.fileExists(atPath: fileURL.path))

            Button {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            } label: {
                Image(systemName: "magnifyingglass.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Reveal in Finder.")
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onShowDetail() }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .contextMenu {
            Button { previewURL = fileURL } label: {
                Label("Quick Look", systemImage: "eye")
            }
            .disabled(!FileManager.default.fileExists(atPath: fileURL.path))
            Button {
                NSWorkspace.shared.activateFileViewerSelecting([fileURL])
            } label: {
                Label("Reveal in Finder", systemImage: "magnifyingglass")
            }
            Button {
                NSWorkspace.shared.open(fileURL)
            } label: {
                Label("Open", systemImage: "arrow.up.forward.app")
            }
            .disabled(!FileManager.default.fileExists(atPath: fileURL.path))
            Divider()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(entry.url, forType: .string)
            } label: {
                Label("Copy URL", systemImage: "link")
            }
        }
    }
}
