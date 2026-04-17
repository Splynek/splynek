import SwiftUI

struct QueueView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    systemImage: "line.3.horizontal.decrease.circle",
                    title: "Queue",
                    subtitle: "URLs waiting their turn. Splynek starts each one automatically when an active slot frees up."
                )
                if vm.queue.isEmpty {
                    TitledCard(title: "Queue", systemImage: "line.3.horizontal.decrease.circle") {
                        EmptyStateView(
                            systemImage: "tray",
                            title: "Queue is empty",
                            message: "Add a URL to the queue from the Downloads tab — Splynek will run it when the current download finishes."
                        )
                    }
                } else {
                    summaryCard
                    listCard
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Queue")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button { vm.importQueue() } label: {
                    Label("Import…", systemImage: "square.and.arrow.down")
                }
                .help("Load queue entries from a JSON file produced by Export.")
                Button { vm.exportQueue() } label: {
                    Label("Export…", systemImage: "square.and.arrow.up")
                }
                .disabled(vm.queue.isEmpty)
                .help("Write the current queue to a JSON file.")
                Button { vm.clearFinishedQueue() } label: {
                    Label("Clear finished", systemImage: "trash")
                }
                .disabled(!vm.queue.contains { $0.status == .completed
                                               || $0.status == .failed
                                               || $0.status == .cancelled })
            }
        }
    }

    private var summaryCard: some View {
        let pending = vm.queue.filter { $0.status == .pending }.count
        let running = vm.queue.filter { $0.status == .running }.count
        let done = vm.queue.filter { $0.status == .completed }.count
        let failed = vm.queue.filter { $0.status == .failed }.count
        return TitledCard(title: "Summary", systemImage: "chart.bar") {
            HStack(spacing: 24) {
                MetricView(value: "\(running)", caption: "Running", tint: .accentColor)
                MetricView(value: "\(pending)", caption: "Pending")
                MetricView(value: "\(done)", caption: "Done", tint: .green)
                MetricView(value: "\(failed)", caption: "Failed", tint: failed > 0 ? .red : .primary)
                Spacer()
            }
        }
    }

    private var listCard: some View {
        TitledCard(title: "Entries", systemImage: "list.bullet.rectangle") {
            VStack(spacing: 6) {
                ForEach(vm.queue, id: \.id) { entry in
                    QueueRow(entry: entry, vm: vm)
                }
            }
        }
    }
}

private struct QueueRow: View {
    let entry: QueueEntry
    let vm: SplynekViewModel

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint)
                .font(.system(size: 14, weight: .medium))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(URL(string: entry.url)?.lastPathComponent ?? entry.url)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1).truncationMode(.middle)
                Text(URL(string: entry.url)?.host ?? entry.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1).truncationMode(.middle)
                if let msg = entry.errorMessage {
                    Text(msg).font(.caption).foregroundStyle(.red)
                        .lineLimit(1).truncationMode(.tail)
                }
            }

            Spacer(minLength: 8)

            StatusPill(text: entry.status.rawValue.uppercased(), style: pillStyle)

            if let finished = entry.finishedAt {
                Text(finished, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            } else {
                Text(entry.addedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }

            Menu {
                if entry.status == .failed || entry.status == .cancelled {
                    Button { vm.retryQueue(id: entry.id) } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                }
                if entry.status != .running {
                    Button(role: .destructive) { vm.removeFromQueue(id: entry.id) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 24)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    private var icon: String {
        switch entry.status {
        case .pending:   return "hourglass"
        case .running:   return "arrow.down.circle.fill"
        case .completed: return "checkmark.circle.fill"
        case .failed:    return "exclamationmark.triangle.fill"
        case .cancelled: return "xmark.circle"
        }
    }

    private var tint: Color {
        switch entry.status {
        case .pending:   return .secondary
        case .running:   return .accentColor
        case .completed: return .green
        case .failed:    return .red
        case .cancelled: return .orange
        }
    }

    private var pillStyle: StatusPill.Style {
        switch entry.status {
        case .pending:   return .neutral
        case .running:   return .info
        case .completed: return .success
        case .failed:    return .danger
        case .cancelled: return .warning
        }
    }
}
