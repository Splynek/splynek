import SwiftUI

struct QueueView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContextCard(
                    systemImage: "line.3.horizontal.decrease.circle",
                    subtitle: "URLs waiting their turn. Splynek starts each one automatically when an active slot frees up.",
                    tint: .indigo
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
                // 2026-05-09: schedule + watched folder migrated
                // here from Settings.  Both configure HOW the queue
                // behaves (gating + ingestion); they belong on the
                // tab they affect, not two screens away.
                scheduleCard
                watchedFolderCard
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
        // v0.47 redesign. Prior version was four bare MetricViews in
        // a row — readable but visually flat, no sense of scale,
        // and no way to act on the numbers. New layout:
        //   Top    — total count, large, with a subtitle line that
        //            switches between "idle" and "running" language.
        //   Middle — four status pills with coloured dots.
        //   Bottom — contextual bulk-action buttons (Retry all
        //            failed, Clear finished). Only show when useful.
        let total     = vm.queue.count
        let pending   = vm.queue.filter { $0.status == .pending }.count
        let running   = vm.queue.filter { $0.status == .running }.count
        let done      = vm.queue.filter { $0.status == .completed }.count
        let failed    = vm.queue.filter { $0.status == .failed }.count
        let cancelled = vm.queue.filter { $0.status == .cancelled }.count
        let finishedTotal = done + failed + cancelled
        return TitledCard(title: "Summary", systemImage: "list.clipboard") {
            VStack(alignment: .leading, spacing: 14) {
                // Hero line
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text("\(total)")
                        .font(.system(size: 40, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(total == 1 ? "entry" : "entries")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text(summarySubtitle(running: running, pending: pending, finished: finishedTotal))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }

                // Status dots + counts
                HStack(spacing: 14) {
                    statusTag(count: running,   label: "Running",   color: .accentColor)
                    statusTag(count: pending,   label: "Pending",   color: .secondary)
                    statusTag(count: done,      label: "Done",      color: .green)
                    statusTag(count: failed,    label: "Failed",    color: .red)
                    if cancelled > 0 {
                        statusTag(count: cancelled, label: "Cancelled", color: .orange)
                    }
                    Spacer()
                }

                // Action bar — only render if there's something to do.
                let failureCount = failed + cancelled
                if failureCount > 0 || finishedTotal > 0 {
                    Divider().opacity(0.3)
                    HStack(spacing: 10) {
                        if failureCount > 0 {
                            Button {
                                vm.retryAllFailed()
                            } label: {
                                Label("Retry \(failureCount) failed", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Re-queue every failed or cancelled entry. Runs immediately if nothing else is running.")
                        }
                        if finishedTotal > 0 {
                            Button(role: .destructive) {
                                vm.clearFinishedQueue()
                            } label: {
                                Label("Clear \(finishedTotal) finished", systemImage: "trash")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("Remove every completed, failed, and cancelled entry. Running and pending entries are kept.")
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    /// One-liner narrating queue state beneath the big total.
    private func summarySubtitle(running: Int, pending: Int, finished: Int) -> String {
        if running > 0 && pending > 0 { return "Running \(running), \(pending) queued." }
        if running > 0                { return "Running \(running) right now." }
        if pending > 0                { return "\(pending) waiting to start." }
        if finished > 0               { return "All clear — \(finished) finished." }
        return "Empty. Paste a URL on the Downloads tab to queue one."
    }

    /// Compact status "dot + count + label" chip.
    @ViewBuilder
    private func statusTag(count: Int, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(count > 0 ? color : color.opacity(0.25))
                .frame(width: 8, height: 8)
            Text("\(count)")
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .monospacedDigit()
                .foregroundStyle(count > 0 ? .primary : .secondary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
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

// MARK: - Schedule + Watched folder (migrated from SettingsView 2026-05-09)
//
// Both configure HOW the queue behaves: schedule gates the START of
// queued items inside a time window; watched folder INGESTS new
// items into the queue from a polled directory.  Putting them on
// this tab means the configuration lives next to the data it
// affects — no more "I have to find the toggle in Settings two
// screens away."

extension QueueView {

    // MARK: Download schedule

    @ViewBuilder
    fileprivate var scheduleCard: some View {
        if vm.license.isPro {
            scheduleCardUnlocked
        } else {
            ProLockedView(
                featureTitle: "Download schedule",
                summary: "Only run downloads inside a time window — e.g., overnight on home Wi-Fi — with weekday rules and a cellular-off option. Running downloads are never interrupted; the schedule only gates starts.",
                systemImage: "clock.badge.checkmark",
                onUnlock: { vm.requestProUnlock() }
            )
        }
    }

    fileprivate var scheduleCardUnlocked: some View {
        let schedule = Binding(
            get: { vm.downloadSchedule },
            set: { vm.updateSchedule($0) }
        )
        return TitledCard(
            title: "Download schedule",
            systemImage: "clock.badge.checkmark",
            accessory: AnyView(StatusPill(
                text: schedule.wrappedValue.enabled ? "ON" : "OFF",
                style: schedule.wrappedValue.enabled ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Only start queued downloads inside a time window — e.g., overnight on home Wi-Fi. Running downloads are never interrupted; the schedule only gates starts.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: Binding(
                    get: { schedule.wrappedValue.enabled },
                    set: { var s = schedule.wrappedValue; s.enabled = $0; schedule.wrappedValue = s }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Respect schedule")
                        Text(schedule.wrappedValue.summary)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)

                if schedule.wrappedValue.enabled {
                    hourWindowControls(schedule)
                    Divider().opacity(0.3)
                    weekdayPicker(schedule)
                    Divider().opacity(0.3)
                    Toggle(isOn: Binding(
                        get: { schedule.wrappedValue.pauseOnCellular },
                        set: { var s = schedule.wrappedValue; s.pauseOnCellular = $0; schedule.wrappedValue = s }
                    )) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Pause on cellular")
                            Text("Block starts while any selected interface is cellular. Complements the per-day bytes cap.")
                                .font(.caption).foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .toggleStyle(.switch)
                    currentStateRow
                }
            }
        }
    }

    fileprivate func hourWindowControls(_ schedule: Binding<DownloadSchedule>) -> some View {
        HStack(spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Start").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { schedule.wrappedValue.startHour },
                    set: { var s = schedule.wrappedValue; s.startHour = $0; schedule.wrappedValue = s }
                )) {
                    ForEach(0..<24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 90)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("End").font(.caption).foregroundStyle(.secondary)
                Picker("", selection: Binding(
                    get: { schedule.wrappedValue.endHour },
                    set: { var s = schedule.wrappedValue; s.endHour = $0; schedule.wrappedValue = s }
                )) {
                    ForEach(1...24, id: \.self) { Text(String(format: "%02d:00", $0)).tag($0) }
                }
                .labelsHidden()
                .frame(width: 90)
            }
            Spacer()
            if schedule.wrappedValue.startHour > schedule.wrappedValue.endHour {
                StatusPill(text: "WRAPS MIDNIGHT", style: .info)
            }
        }
    }

    fileprivate func weekdayPicker(_ schedule: Binding<DownloadSchedule>) -> some View {
        let order: [(Int, String)] = [
            (2, "Mon"), (3, "Tue"), (4, "Wed"), (5, "Thu"),
            (6, "Fri"), (7, "Sat"), (1, "Sun")
        ]
        return VStack(alignment: .leading, spacing: 6) {
            Text("Active days").font(.caption).foregroundStyle(.secondary)
            HStack(spacing: 6) {
                ForEach(order, id: \.0) { item in
                    let active = schedule.wrappedValue.weekdays.contains(item.0)
                    Button {
                        var s = schedule.wrappedValue
                        if active { s.weekdays.remove(item.0) }
                        else      { s.weekdays.insert(item.0) }
                        schedule.wrappedValue = s
                    } label: {
                        Text(item.1)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(width: 36, height: 24)
                            .foregroundStyle(active ? .white : .primary)
                            .background(
                                RoundedRectangle(cornerRadius: 6, style: .continuous)
                                    .fill(active ? Color.accentColor : Color.primary.opacity(0.08))
                            )
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button("Weekdays") {
                    var s = schedule.wrappedValue
                    s.weekdays = [2, 3, 4, 5, 6]
                    schedule.wrappedValue = s
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                Button("Every day") {
                    var s = schedule.wrappedValue
                    s.weekdays = Set(1...7)
                    schedule.wrappedValue = s
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    @ViewBuilder fileprivate var currentStateRow: some View {
        let eval = vm.scheduleEvaluation
        HStack(spacing: 8) {
            Image(systemName: eval == .allowed ? "checkmark.seal.fill" : "hourglass")
                .foregroundStyle(eval == .allowed ? .green : .orange)
            switch eval {
            case .allowed:
                Text("Window is open — queued items will start as slots free up.")
                    .font(.caption).foregroundStyle(.secondary)
            case .blocked(let reason, let nextAllowed):
                if let next = nextAllowed {
                    Text("\(reason.displayText) — next opening \(formatRelative(next)).")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("\(reason.displayText).")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.04))
        )
    }

    // MARK: Watched folder

    fileprivate var watchedFolderCard: some View {
        TitledCard(
            title: "Watched folder",
            systemImage: "folder.badge.gearshape",
            accessory: AnyView(StatusPill(
                text: vm.watchEnabled ? "ON" : "OFF",
                style: vm.watchEnabled ? .success : .neutral
            ))
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Drop `.txt` (one URL per line), `.torrent`, or `.metalink` files here. Splynek queues each new file within 5 seconds, then moves it to a `processed/` subfolder.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: Binding(
                    get: { vm.watchEnabled },
                    set: { vm.setWatchEnabled($0) }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Watch folder for drops")
                        Text("Polled every 5 s. `# comments` and blank lines in .txt files are ignored.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(vm.watchFolder.path)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change…") { pickWatchFolder() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Button {
                        NSWorkspace.shared.selectFile(nil,
                            inFileViewerRootedAtPath: vm.watchFolder.path)
                    } label: {
                        Label("Reveal", systemImage: "magnifyingglass")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Open the watched folder in Finder.")
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(0.04))
                )
            }
        }
    }

    fileprivate func pickWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Watch"
        panel.directoryURL = vm.watchFolder
        guard panel.runModal() == .OK, let url = panel.url else { return }
        vm.setWatchFolder(url)
    }
}
