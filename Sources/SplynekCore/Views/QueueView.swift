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
        // QA P2 #6 (v0.43): `chart.bar` reads as Wi-Fi signal
        // strength at small sizes. `rectangle.stack.badge.person.crop`
        // is too thematic; `list.clipboard` conveys "queue summary"
        // without the signal-bars ambiguity.
        return TitledCard(title: "Summary", systemImage: "list.clipboard") {
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
        // First pending entry is the one the scheduler would start next;
        // if the schedule is blocking, we badge it with "WAITING" so the
        // user understands why nothing is running.
        let headPendingID = vm.queue.first(where: { $0.status == .pending })?.id
        let blocked: DownloadSchedule.Evaluation? = {
            if case .blocked = vm.scheduleEvaluation { return vm.scheduleEvaluation }
            return nil
        }()
        return TitledCard(title: "Entries", systemImage: "list.bullet.rectangle") {
            VStack(spacing: 6) {
                ForEach(vm.queue, id: \.id) { entry in
                    QueueRow(
                        entry: entry,
                        vm: vm,
                        scheduleBlock: entry.id == headPendingID ? blocked : nil
                    )
                }
            }
        }
    }
}

private struct QueueRow: View {
    let entry: QueueEntry
    let vm: SplynekViewModel
    /// If non-nil, this row is the head-of-queue and the schedule is
    /// currently blocking starts. Shown as a "WAITING" pill + relative
    /// "next opening 2h" caption under the filename.
    let scheduleBlock: DownloadSchedule.Evaluation?

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
                if let block = scheduleBlock,
                   case .blocked(_, let nextAllowed) = block,
                   let next = nextAllowed {
                    Text("Next opening \(Self.relative(next)).")
                        .font(.caption).foregroundStyle(.orange)
                }
            }

            Spacer(minLength: 8)

            if scheduleBlock != nil {
                StatusPill(text: "WAITING", style: .warning)
            }
            StatusPill(text: entry.status.rawValue.uppercased(), style: pillStyle)

            // QA P2 #4/#5 (v0.43): on terminal states the "time ago"
            // clock is noise. For COMPLETED we show the actual
            // download duration (took Xs) when we have a startedAt.
            // For FAILED / CANCELLED we hide the clock entirely —
            // the error message carries the timing context that
            // matters. PENDING / RUNNING keep the addedAt clock so
            // users can see staleness.
            switch entry.status {
            case .completed:
                if let started = entry.startedAt, let finished = entry.finishedAt {
                    Text("took \(formatDuration(finished.timeIntervalSince(started)))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 90, alignment: .trailing)
                } else {
                    Spacer().frame(width: 90)
                }
            case .failed, .cancelled:
                Spacer().frame(width: 90)
            case .pending, .running:
                Text(entry.addedAt, style: .relative)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 90, alignment: .trailing)
            }

            // v0.46 fix: previously the menu on completed rows held a
            // single "Remove" item, which rendered as an apparently
            // empty click target on macOS 14. Now every state has at
            // least two entries so the menu reads as actually
            // functional:
            //   pending   → Remove
            //   running   → Open URL · (no Remove — in-flight)
            //   completed → Open URL · Copy URL · Remove
            //   failed    → Retry · Open URL · Copy URL · Remove
            //   cancelled → Retry · Open URL · Copy URL · Remove
            Menu {
                if entry.status == .failed || entry.status == .cancelled {
                    Button { vm.retryQueue(id: entry.id) } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                    Divider()
                }
                if let url = URL(string: entry.url) {
                    Button {
                        NSWorkspace.shared.open(url)
                    } label: {
                        Label("Open URL in browser", systemImage: "safari")
                    }
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(entry.url, forType: .string)
                    } label: {
                        Label("Copy URL", systemImage: "doc.on.doc")
                    }
                }
                if entry.status != .running {
                    Divider()
                    Button(role: .destructive) { vm.removeFromQueue(id: entry.id) } label: {
                        Label("Remove from queue", systemImage: "trash")
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

    private static func relative(_ date: Date) -> String { formatRelative(date) }
}
