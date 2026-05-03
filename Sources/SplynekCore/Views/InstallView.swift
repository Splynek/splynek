import SwiftUI
import UniformTypeIdentifiers

// =====================================================================
// ARCHITECTURAL INVARIANT — App Store Review Guideline 2.5.2
// =====================================================================
// InstallView is a SwiftUI surface over `InstallerEngine.run(...)`.
// Every install decision the user can make (kick off install, accept
// Trust warning, switch to Sovereignty alternative, cancel) is an
// explicit button.  The pipeline never auto-launches the installed
// .app — the post-install card surfaces the install path; the user
// double-clicks to launch.
// =====================================================================

/// v1.8: drag-and-drop installer surface.  Drop a `.dmg`, `.app`, or
/// `.zip` onto the panel; Splynek runs the verified-installer pipeline
/// (preflight Trust + Sovereignty → SHA-256 + Gatekeeper verify →
/// install → register).
///
/// The view is **stateful by design** — it keeps a single
/// `InstallerEngine.Stage` per install run so the UI can show the
/// current pipeline position (verifying / installing / etc.) and
/// surface failures inline.  Multiple concurrent installs aren't
/// supported in v1.8 (queue + state machine work for v1.8.x).
struct InstallView: View {
    @ObservedObject var vm: SplynekViewModel

    /// Currently-selected install candidate (the .dmg / .app / .zip
    /// the user dropped or picked).  Cleared when the install
    /// completes or the user cancels.
    @State private var pickedPayload: URL?

    /// Most recent stage emitted by the pipeline.  Drives the
    /// progress card.  `nil` before the first run.
    @State private var lastStage: InstallerEngine.Stage?

    /// Whether a run is in flight.  Disables the Install button +
    /// drop target.
    @State private var running: Bool = false

    /// Drag-hover state for the drop target's visual feedback.
    @State private var dragHover: Bool = false

    /// Result of the last completed run.  Cleared when a new install
    /// starts.
    @State private var lastResult: InstallerEngine.PipelineResult?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContextCard(
                    systemImage: "shippingbox.fill",
                    subtitle: "Drop a .dmg, .zip, or .app onto Splynek and we'll verify, Trust-check, and install it. The user double-clicks to launch — Splynek never auto-runs an installed binary.",
                    tint: .accentColor
                )

                if let payload = pickedPayload {
                    candidateCard(payload: payload)
                } else {
                    dropTarget
                }

                if let stage = lastStage {
                    progressCard(stage: stage)
                }

                if let result = lastResult {
                    resultCard(result: result)
                }

                installedAppsList
                if !installedRecords.isEmpty {
                    autoUpdateActivityCard
                }
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Install")
    }

    // MARK: - Drop target

    private var dropTarget: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.down.doc.fill")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(dragHover ? Color.accentColor : Color.secondary)
            Text("Drop a .dmg, .zip, or .app here")
                .font(.system(.title3, design: .rounded, weight: .medium))
            Text("Or click to pick a file.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                pickedPayload = pickPayload()
            } label: {
                Label("Choose file…", systemImage: "folder")
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    dragHover ? Color.accentColor : Color.secondary.opacity(0.4),
                    style: StrokeStyle(lineWidth: 1.5, dash: [6, 4])
                )
        )
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(dragHover ? Color.accentColor.opacity(0.05) : Color.clear)
        )
        .onDrop(of: [.fileURL], isTargeted: $dragHover) { providers in
            providers.first?.loadObject(ofClass: URL.self) { url, _ in
                if let url = url {
                    DispatchQueue.main.async { pickedPayload = url }
                }
            }
            return true
        }
    }

    private func pickPayload() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true   // for .app bundles
        panel.allowedContentTypes = [.diskImage, .zip, .application]
        panel.message = "Choose a .dmg, .zip, or .app to install."
        return panel.runModal() == .OK ? panel.url : nil
    }

    // MARK: - Candidate card

    @ViewBuilder
    private func candidateCard(payload: URL) -> some View {
        TitledCard(title: "Ready to install", systemImage: "shippingbox.fill") {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    Image(systemName: iconFor(payload))
                        .font(.title2)
                        .foregroundStyle(.tint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(payload.lastPathComponent)
                            .font(.callout.weight(.semibold))
                        Text(payload.path)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    Spacer()
                    Button {
                        pickedPayload = nil
                        lastStage = nil
                        lastResult = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
                HStack(spacing: 8) {
                    Button {
                        startInstall(payload: payload)
                    } label: {
                        Label(running ? "Installing…" : "Install", systemImage: "arrow.down.to.line.alt")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(running)
                    Spacer()
                }
            }
        }
    }

    private func iconFor(_ url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "dmg":  return "externaldrive.fill"
        case "pkg":  return "shippingbox"
        case "zip":  return "archivebox"
        case "app":  return "app.fill"
        default:     return "doc"
        }
    }

    // MARK: - Progress card

    @ViewBuilder
    private func progressCard(stage: InstallerEngine.Stage) -> some View {
        TitledCard(title: "Pipeline", systemImage: "list.bullet.indent") {
            VStack(alignment: .leading, spacing: 8) {
                stageRow(label: "Resolving",         done: progressOrder(stage) >= 1, current: progressOrder(stage) == 1)
                stageRow(label: "Trust check",       done: progressOrder(stage) >= 2, current: progressOrder(stage) == 2)
                stageRow(label: "Sovereignty check", done: progressOrder(stage) >= 3, current: progressOrder(stage) == 3)
                stageRow(label: "Downloading",       done: progressOrder(stage) >= 4, current: progressOrder(stage) == 4)
                stageRow(label: "Verifying",         done: progressOrder(stage) >= 5, current: progressOrder(stage) == 5)
                stageRow(label: "Installing",        done: progressOrder(stage) >= 6, current: progressOrder(stage) == 6)
                stageRow(label: "Registering",       done: progressOrder(stage) >= 7, current: progressOrder(stage) == 7)
            }
        }
    }

    /// Stage labels are routed through LocalizedStringKey so the
    /// catalog can localise them.  Calling `Text(_ verbatim:)` with
    /// a String parameter would render verbatim and break i18n.
    private func stageRow(label: LocalizedStringKey, done: Bool, current: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: done ? "checkmark.circle.fill" :
                              current ? "circle.dotted" : "circle")
                .foregroundStyle(done ? Color.green : current ? Color.accentColor : Color.secondary.opacity(0.6))
            Text(label)
                .font(.callout)
                .foregroundStyle(done || current ? .primary : .secondary)
            Spacer()
        }
    }

    /// Map a Stage value to its position in the linear pipeline so
    /// the progress card can show "step N of 7."
    private func progressOrder(_ stage: InstallerEngine.Stage) -> Int {
        switch stage {
        case .resolving:        return 1
        case .trustCheck:       return 2
        case .sovereigntyCheck: return 3
        case .downloading:      return 4
        case .verifying:        return 5
        case .installing:       return 6
        case .registering:      return 7
        case .completed:        return 8
        case .failed:           return 0
        }
    }

    // MARK: - Result card

    @ViewBuilder
    private func resultCard(result: InstallerEngine.PipelineResult) -> some View {
        switch result {
        case .success(let record):
            TitledCard(title: "Installed", systemImage: "checkmark.seal.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 10) {
                        Image(systemName: "app.fill").foregroundStyle(.green)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(record.spec.name)
                                .font(.callout.weight(.semibold))
                            Text(record.installedAt.path)
                                .font(.caption.monospaced())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                    }
                    Text("Double-click to launch — Splynek never auto-runs an installed binary.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        Button {
                            NSWorkspace.shared.activateFileViewerSelecting([record.installedAt])
                        } label: {
                            Label("Reveal in Finder", systemImage: "magnifyingglass")
                        }
                        .controlSize(.small)
                        Spacer()
                    }
                }
            }
        case .failure(let err):
            TitledCard(title: "Install failed", systemImage: "exclamationmark.triangle.fill") {
                Text(err.errorDescription ?? "Unknown error.")
                    .font(.callout)
                    .foregroundStyle(.primary)
            }
        }
    }

    // MARK: - Installed apps list

    @ViewBuilder
    private var installedAppsList: some View {
        let records = installedRecords
        if !records.isEmpty {
            TitledCard(title: "Installed via Splynek (\(records.count))", systemImage: "checkmark.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(records) { r in
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "app").foregroundStyle(.tint)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(r.spec.name).font(.callout.weight(.medium))
                                if let v = r.installedVersion {
                                    Text("v\(v)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            // v1.8.3: per-record auto-update toggle.
                            // Flipping persists immediately to the
                            // registry; the next periodic sweep picks
                            // up the change.  Tooltip clarifies what
                            // gets checked when on.
                            Toggle("Auto-update", isOn: Binding(
                                get: { r.autoUpdate },
                                set: { newVal in
                                    InstalledAppRegistry.setAutoUpdate(r.id, enabled: newVal)
                                    bumpRegistryRefresh()
                                }
                            ))
                            .toggleStyle(.switch)
                            .controlSize(.mini)
                            .help("When on, Splynek re-runs the installer pipeline every 6 hours and replaces this app if the publisher's URL serves new bytes.")
                            Text(relativeDate(r.installedDate))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 70, alignment: .trailing)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var autoUpdateActivityCard: some View {
        TitledCard(title: "Auto-update activity", systemImage: "arrow.triangle.2.circlepath") {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(autoUpdateSummary)
                        .font(.callout)
                        .foregroundStyle(.primary)
                    Spacer()
                    Button {
                        Task { await vm.runAutoUpdateSweep() }
                    } label: {
                        Label("Check now", systemImage: "arrow.clockwise")
                    }
                    .controlSize(.small)
                }
                if let sweep = vm.lastAutoUpdateSweep {
                    if !sweep.updates.isEmpty {
                        Divider()
                        ForEach(sweep.updates.indices, id: \.self) { i in
                            let upd = sweep.updates[i]
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: updateIcon(for: upd))
                                    .foregroundStyle(updateColour(for: upd))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(upd.record.spec.name)
                                        .font(.callout.weight(.semibold))
                                    Text(updateDescription(for: upd))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                    if !sweep.errors.isEmpty {
                        Divider()
                        ForEach(sweep.errors.indices, id: \.self) { i in
                            let entry = sweep.errors[i]
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.record.spec.name)
                                        .font(.callout.weight(.semibold))
                                    Text(entry.message)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    /// Auto-update summary text.  Shown in the activity-card header
    /// regardless of whether a sweep has run yet.
    private var autoUpdateSummary: String {
        let candidates = installedRecords.filter { $0.autoUpdate }.count
        if candidates == 0 {
            return "No apps opted in to auto-update.  Toggle one above to enable."
        }
        if let sweep = vm.lastAutoUpdateSweep {
            let n = sweep.updates.count
            let e = sweep.errors.count
            if n == 0 && e == 0 {
                return "All \(candidates) auto-updating apps are current."
            }
            return "Last sweep: \(n) update(s), \(e) error(s) across \(candidates) candidate(s)."
        }
        return "\(candidates) app(s) opted in.  No sweep yet — periodic runs every 6 hours."
    }

    private func updateIcon(for u: AutoUpdateScheduler.Sweep.Update) -> String {
        switch u.result {
        case .success: return "checkmark.circle.fill"
        case .failure: return "xmark.octagon.fill"
        }
    }

    private func updateColour(for u: AutoUpdateScheduler.Sweep.Update) -> Color {
        switch u.result {
        case .success: return .green
        case .failure: return .red
        }
    }

    private func updateDescription(for u: AutoUpdateScheduler.Sweep.Update) -> String {
        switch u.result {
        case .success(let rec):
            return "Updated to digest \(u.newDigest.prefix(12))…"
                + (rec.installedVersion.map { " (v\($0))" } ?? "")
        case .failure(let err):
            return err.errorDescription ?? "Update failed."
        }
    }

    // MARK: - Registry refresh
    //
    // The InstalledAppRegistry persists to disk and isn't @Published.
    // To trigger a re-render after a toggle flip, we bump a local
    // counter that drives `installedRecords` re-computation.  Cheap
    // (registry load reads a small JSON file).

    @State private var registryRefreshCounter: Int = 0

    private var installedRecords: [InstalledAppRecord] {
        _ = registryRefreshCounter   // dependency, force re-eval on bump
        return InstalledAppRegistry.load()
    }

    private func bumpRegistryRefresh() {
        registryRefreshCounter &+= 1
    }

    // MARK: - Pipeline driver

    private func startInstall(payload: URL) {
        lastStage = nil
        lastResult = nil
        running = true

        // Build a minimal spec.  v1.8.x will look up catalog metadata
        // (Trust score, Sovereignty alternatives) by hashing or by
        // bundle-ID extraction.
        let spec = InstallSpec(
            name: payload.deletingPathExtension().lastPathComponent,
            bundleID: nil,
            downloadURL: payload,  // already-on-disk; pipeline accepts it as-is
            kind: kindFor(payload),
            expectedDigest: nil,
            source: .directURL
        )

        Task {
            let result = await InstallerEngine.run(
                spec: spec,
                downloadedPayload: payload,
                onStage: { stage in
                    Task { @MainActor in
                        self.lastStage = stage
                    }
                }
            )
            await MainActor.run {
                self.lastResult = result
                self.running = false
            }
        }
    }

    private func kindFor(_ url: URL) -> InstallSpec.Kind {
        InstallerEngine.kindFor(url: url)
    }

    /// Compact relative-time formatter matching Splynek's existing
    /// "2 days ago" / "3 weeks ago" convention from HistoryView.
    private func relativeDate(_ date: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .abbreviated
        return f.localizedString(for: date, relativeTo: Date())
    }
}
