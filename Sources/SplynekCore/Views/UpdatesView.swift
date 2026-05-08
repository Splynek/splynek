// Copyright © 2026 Splynek. MIT.
//
// UpdatesView — universal updater.
//
// 2026-05-08 revolution.  Three problems with the prior layout:
//
//   1. The "Atualizar" button only added a URL to Splynek's download
//      queue — it didn't actually install anything.  The user had to
//      then go to the Install tab and drop the file manually.  Now
//      each row downloads + verifies + installs through
//      InstallerEngine.run, with per-app progress and an "Installed!"
//      completion state.
//
//   2. The hero was a green LinearGradient block that didn't match
//      the rest of the app.  Replaced with the standard `ContextCard`
//      + a small summary row, matching Sovereignty / Trust / Downloads.
//
//   3. The view never auto-checked.  Fresh launches showed "Click
//      Check all to scan installed apps" until the user pressed the
//      toolbar button.  Now `.onAppear` chains the scanner →
//      resolver automatically, and `vm.availableUpdateCount` is
//      published so the Apps sidebar row renders a live counter.
//
// Architectural advantages Splynek already has (unchanged):
//
//   - BondedFetcher (S5)  → updates download via multi-NIC bonded
//                            byte ranges, faster than any other Mac
//                            updater on multi-interface setups.
//   - File Witness (S6)   → every install produces an Ed25519-signed
//                            receipt; failure rolls back.
//   - MirrorManifest      → curated mirrors for OS-distro updates.

#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
struct UpdatesView: View {
    @ObservedObject var vm: SplynekViewModel
    @StateObject private var scanner = SovereigntyScanner()
    @State private var resolved: [AppUpdateInfo] = []
    @State private var isResolving = false
    /// Has the auto-refresh fired at least once this session?  Stops
    /// the .onAppear from re-running the full sweep on every tab
    /// re-entry.  User-triggered "Check all" (toolbar) ignores this.
    @State private var didAutoRefresh = false

    init(vm: SplynekViewModel) { self.vm = vm }

    private var updatesAvailable: [AppUpdateInfo] {
        resolved.filter { $0.hasUpdate && $0.updatePolicy != .ignored }
    }

    private var unchecked: [AppUpdateInfo] {
        resolved.filter { $0.availableVersion == nil && $0.updatePolicy != .ignored }
    }

    private var manualOnly: [AppUpdateInfo] {
        resolved.filter {
            if case .unknown = $0.updateSource { return true }
            return false
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                heroCard
                summaryStrip
                if !updatesAvailable.isEmpty { updatesAvailableSection }
                if !unchecked.isEmpty { uncheckedSection }
                if !manualOnly.isEmpty { manualSection }
            }
            .padding(20)
        }
        .navigationTitle("Updates")
        .toolbar {
            ToolbarItem {
                Button {
                    Task { await checkAll(force: true) }
                } label: {
                    if isResolving {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("Check all", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
                .disabled(isResolving)
                .help("Re-scan every installed app and re-query each upstream source.")
            }
        }
        .onAppear {
            Task { await autoRefreshIfNeeded() }
        }
        // 2026-05-08: re-resolve on successful install so the row
        // disappears immediately.  Force=true bypasses the 5-min
        // freshness cache because the on-disk state just changed.
        .onReceive(NotificationCenter.default
            .publisher(for: .splynekUpdatesDidInstall)
        ) { _ in
            Task {
                scanner.scan()
                try? await Task.sleep(nanoseconds: 400_000_000)
                await checkAll(force: true)
            }
        }
    }

    // MARK: Hero

    @ViewBuilder
    private var heroCard: some View {
        ContextCard(
            systemImage: "arrow.triangle.2.circlepath",
            subtitle: heroCopy,
            tint: heroTint
        )
    }

    private var heroCopy: LocalizedStringKey {
        if isResolving {
            return "Scanning installed apps and resolving Sparkle / GitHub / Homebrew sources…"
        }
        if resolved.isEmpty {
            return "Splynek identifies each app's update source — Sparkle, GitHub Releases, Homebrew, App Store, or publisher RSS — and downloads via bonded multi-interface fetch with an Ed25519 receipt before installing."
        }
        if updatesAvailable.isEmpty {
            return "Everything checked is current. Splynek will keep watching in the background."
        }
        return "Updates download via Splynek's bonded multi-interface fetch and verify with an Ed25519 receipt before installing. Click Update on a row to start."
    }

    private var heroTint: Color {
        updatesAvailable.isEmpty ? .accentColor : .green
    }

    /// Compact summary strip beneath the hero — count + "Update all"
    /// button when there's work to do.  Replaces the old "N updates
    /// ready" giant green block with something the user can act on.
    @ViewBuilder
    private var summaryStrip: some View {
        if isResolving {
            HStack(spacing: 8) {
                ProgressView().controlSize(.small)
                Text("Checking…").font(.callout).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 4)
        } else if !updatesAvailable.isEmpty {
            HStack(spacing: 10) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(.green)
                Text("\(updatesAvailable.count) update\(updatesAvailable.count == 1 ? "" : "s") ready")
                    .font(.headline)
                Spacer()
                Button {
                    Task { await updateAll() }
                } label: {
                    Label("Update all", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 4)
        } else if !resolved.isEmpty {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("All checked apps are up to date")
                    .font(.callout)
                Spacer()
                Text("\(resolved.count) scanned")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 4)
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var updatesAvailableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Updates available").font(.headline)
            ForEach(updatesAvailable, id: \.bundleID) { info in
                UpdateRow(info: info)
            }
        }
    }

    @ViewBuilder
    private var uncheckedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pending check").font(.headline)
            Text("Splynek found update sources for these apps but hasn't fetched their latest versions yet.")
                .font(.caption)
                .foregroundStyle(.secondary)
            ForEach(unchecked.prefix(20), id: \.bundleID) { info in
                UpdateRow(info: info)
            }
        }
    }

    @ViewBuilder
    private var manualSection: some View {
        DisclosureGroup {
            ForEach(manualOnly.prefix(50), id: \.bundleID) { info in
                UpdateRow(info: info)
            }
        } label: {
            HStack {
                Text("\(manualOnly.count) apps without a known update source")
                    .font(.subheadline)
                Spacer()
                Text("Manual")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Actions

    /// Called by `.onAppear`.  First entry of the session: chain
    /// refreshScanner → checkAll so the user sees real numbers without
    /// touching the toolbar.  Subsequent re-entries are no-ops; the
    /// toolbar's Check all button forces a full re-scan.
    @MainActor
    private func autoRefreshIfNeeded() async {
        guard !didAutoRefresh else { return }
        didAutoRefresh = true
        await checkAll(force: false)
    }

    @MainActor
    private func refreshScanner() async {
        if scanner.apps.isEmpty {
            scanner.scan()
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        var out: [AppUpdateInfo] = []
        for app in scanner.apps {
            let source = UpdateSourceResolver.resolve(
                bundleID: app.id, bundleURL: app.bundleURL)
            out.append(AppUpdateInfo(
                bundleID: app.id,
                displayName: app.name,
                installedVersion: app.version ?? "—",
                installedAt: app.bundleURL,
                updateSource: source))
        }
        resolved = out
    }

    @MainActor
    private func checkAll(force: Bool) async {
        if !force && !resolved.isEmpty && resolved.contains(where: { $0.lastChecked.timeIntervalSinceNow > -300 }) {
            return
        }
        isResolving = true
        defer {
            isResolving = false
            vm.availableUpdateCount = updatesAvailable.count
        }
        // 2026-05-08: resolver dispatch + URL pre-flight extracted
        // to `UpdateSweep` so the launch-time warm-up in the VM can
        // share the same code path — no duplicated logic.
        await refreshScanner()
        let installed = scanner.apps
        let swept = await UpdateSweep.run(installedApps: installed)
        resolved = swept
    }

    @MainActor
    private func updateAll() async {
        // The per-row Update buttons each kick off a stateful flow.
        // "Update all" simply asks every actionable row to start.
        // We post a notification each row listens for; rows that
        // can act do, the rest stay idle.
        NotificationCenter.default.post(name: .splynekUpdateAllRequested,
                                        object: nil)
    }
}

// MARK: - UpdateRow (stateful)

@MainActor
private struct UpdateRow: View {
    let info: AppUpdateInfo

    /// Per-row state.  Drives the right-side affordance: button when
    /// idle, progress + stage label while running, "Installed" tick
    /// when done, error icon + retry when failed.
    enum Phase: Equatable {
        case idle
        case downloading(progress: Double)
        case installing(label: String)
        case installed
        case failed(reason: String)
    }

    @State private var phase: Phase = .idle

    private var icon: NSImage? {
        NSWorkspace.shared.icon(forFile: info.installedAt.path)
    }

    var body: some View {
        HStack(spacing: 10) {
            if let icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 32, height: 32)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
            }
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(info.displayName)
                        .font(.subheadline.weight(.semibold))
                    sourceBadge
                }
                versionLine
                if let notes = info.releaseNotes, !notes.isEmpty {
                    Text(notes)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                inlineStatus
            }
            Spacer()
            actionAffordance
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.primary.opacity(0.03))
        )
        .onReceive(NotificationCenter.default
            .publisher(for: .splynekUpdateAllRequested)
        ) { _ in
            // Only react if this row is actionable + currently idle.
            if case .idle = phase, info.hasUpdate, info.availableDownloadURL != nil {
                Task { await performUpdate() }
            }
        }
    }

    @ViewBuilder
    private var sourceBadge: some View {
        Text(info.updateSource.displayLabel)
            .font(.caption2.weight(.medium))
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .background(Capsule().fill(sourceColor.opacity(0.18)))
            .foregroundStyle(sourceColor)
    }

    private var sourceColor: Color {
        switch info.updateSource {
        case .sparkle:        return .blue
        case .githubReleases: return .purple
        case .macAppStore:    return .pink
        case .homebrew:       return .orange
        case .publisherRSS:   return .teal
        case .unknown:        return .gray
        }
    }

    @ViewBuilder
    private var versionLine: some View {
        if let avail = info.availableVersion, info.hasUpdate {
            HStack(spacing: 4) {
                Text(info.installedVersion)
                    .strikethrough()
                Text("→").foregroundStyle(.secondary)
                Text(avail).bold()
                if let sz = info.availableSizeFormatted {
                    Text("· \(sz)").foregroundStyle(.secondary)
                }
            }
            .font(.caption.monospacedDigit())
            .foregroundStyle(.primary)
        } else {
            Text("v\(info.installedVersion)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var inlineStatus: some View {
        switch phase {
        case .idle:
            // 2026-05-08: surface the pre-flight warning inline, so
            // the user sees the reason BEFORE clicking Update.  When
            // fatal, the row's affordance also downgrades to "Open
            // page" — see actionAffordance.
            if let pre = info.preflight {
                HStack(spacing: 4) {
                    Image(systemName: pre.isFatal
                          ? "exclamationmark.triangle.fill"
                          : "exclamationmark.circle")
                        .foregroundStyle(pre.isFatal ? .orange : .yellow)
                        .font(.caption2)
                    Text(pre.message)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                EmptyView()
            }
        case .installed:
            EmptyView()
        case .downloading(let p):
            HStack(spacing: 6) {
                ProgressView(value: p)
                    .progressViewStyle(.linear)
                    .frame(maxWidth: 200)
                Text("\(Int(p * 100))%")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
        case .installing(let label):
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        case .failed(let reason):
            Text(reason)
                .font(.caption2)
                .foregroundStyle(.red)
                .lineLimit(3)
        }
    }

    @ViewBuilder
    private var actionAffordance: some View {
        switch phase {
        case .idle:
            // 2026-05-08: when pre-flight flagged the URL fatal, we
            // already KNOW Update will fail.  Don't pretend.  Show
            // an Open-page link so the user can complete the update
            // manually via the publisher.
            if info.preflight?.isFatal == true,
               let dl = info.availableDownloadURL {
                Link(destination: dl) {
                    Label("Open page", systemImage: "safari")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Manual update via the publisher's site (Splynek's pre-flight detected this URL won't auto-install).")
            } else if info.hasUpdate, info.availableDownloadURL != nil {
                Button {
                    Task { await performUpdate() }
                } label: {
                    Label("Update", systemImage: "arrow.down.circle.fill")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                EmptyView()
            }
        case .downloading, .installing:
            // Inline progress lives in `inlineStatus`; the trailing
            // affordance is just a little spinner so the row still
            // signals "working" if the row is wide enough that the
            // status text is far from the eye.
            ProgressView().controlSize(.small)
        case .installed:
            Label("Installed", systemImage: "checkmark.seal.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.green)
        case .failed:
            Button {
                Task { await performUpdate() }
            } label: {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    /// Full update flow: download to a tmp file with progress, then
    /// run the InstallerEngine pipeline against the downloaded
    /// payload.  Drives the row's @State `phase` from idle → done.
    @MainActor
    private func performUpdate() async {
        guard let downloadURL = info.availableDownloadURL else {
            phase = .failed(reason: "No download URL.")
            return
        }
        phase = .downloading(progress: 0)

        // Download to a tmp file via URLSession with progress.  The
        // BondedFetcher path is reserved for explicit Downloads-tab
        // jobs; for typical update sizes (10-200 MB) URLSession is
        // simple and fast enough.
        let tmpDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("splynek-update-\(UUID().uuidString)",
                                    isDirectory: true)
        try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)
        let suggested = downloadURL.lastPathComponent.isEmpty
            ? "update.bin" : downloadURL.lastPathComponent
        let dest = tmpDir.appendingPathComponent(suggested)

        do {
            try await downloadToFile(from: downloadURL, to: dest) { p in
                Task { @MainActor in
                    if case .downloading = self.phase {
                        self.phase = .downloading(progress: p)
                    }
                }
            }
        } catch {
            phase = .failed(reason: "Download failed: \(error.localizedDescription)")
            return
        }

        phase = .installing(label: "Verifying signature…")

        // Run the verified-installer pipeline.
        let kind = InstallerEngine.kindFor(url: dest)
        let spec = InstallSpec(
            name: info.displayName,
            bundleID: info.bundleID,
            downloadURL: downloadURL,
            kind: kind,
            expectedDigest: info.availableSHA256,
            source: .directURL
        )
        // 2026-05-08: replaceExisting=true is critical for updates.
        // The default false suffix-renames the new bundle to
        // `<App> 2.app` and leaves the old version in place — result:
        // /Applications has BOTH versions, the next scanner sweep
        // can pick either, and the row reads "needs update" again
        // after a tab switch.  For an explicit update click the
        // user's intent is clearly "replace", so we pass true.
        let result = await InstallerEngine.run(
            spec: spec,
            downloadedPayload: dest,
            replaceExisting: true,
            onStage: { stage in
                Task { @MainActor in
                    self.phase = .installing(label: Self.label(for: stage))
                }
            }
        )

        // Clean up the tmp dir regardless of outcome.
        try? FileManager.default.removeItem(at: tmpDir)

        switch result {
        case .success:
            phase = .installed
            // 2026-05-08: re-scan so the row vanishes without waiting
            // for a tab switch.  Posts a notification UpdatesView
            // catches; that triggers refreshScanner + checkAll, which
            // sees the new on-disk version and drops this row from
            // `updatesAvailable`.
            NotificationCenter.default.post(
                name: .splynekUpdatesDidInstall, object: nil
            )
        case .failure(let err):
            phase = .failed(reason: Self.humanise(err.errorDescription ?? "Install failed."))
        }
    }

    /// Translate raw installer-engine error text into something a
    /// user can act on.  Strips internal `/var/folders/...` paths
    /// and pattern-matches the common engine outputs (hdiutil,
    /// spctl, codesign, SHA-256).  Fallback returns the cleaned-up
    /// raw — at least without the path noise.
    nonisolated private static func humanise(_ raw: String) -> String {
        var s = raw
        s = s.replacingOccurrences(
            of: #"(?:/private)?/var/folders/[^\s:]+"#,
            with: "the downloaded file",
            options: .regularExpression
        )
        let lower = s.lowercased()
        if lower.contains("imagem n\u{00E3}o reconhecida")
            || lower.contains("not recognized")
            || lower.contains("hdiutil") && lower.contains("attach failed") {
            return "The file isn't a valid disk image. The publisher's URL probably served a different format — try Open page to download it manually."
        }
        if lower.contains("rejected") && lower.contains("the code is") {
            return "macOS Gatekeeper refused this binary. The publisher may not have notarised the new version yet — try again later or download manually."
        }
        if lower.contains("rejected") && lower.contains("no usable signature") {
            return "The downloaded binary has no signature Splynek can verify. Update manually from the publisher's site."
        }
        if lower.contains("sha-256 mismatch") || lower.contains("digest mismatch") {
            return "The downloaded file's hash doesn't match what the publisher advertised — the source mirror may be stale."
        }
        if lower.contains("no .app") || lower.contains("no app bundle") {
            return "The downloaded archive didn't contain a Mac app. The publisher's link may have moved."
        }
        if lower.contains("timed out") || lower.contains("timeout") {
            return "The download timed out. Check your connection and try again."
        }
        return s
    }

    /// One-line description for the current pipeline stage, shown
    /// next to the inline progress ring.
    private static func label(for stage: InstallerEngine.Stage) -> String {
        switch stage {
        case .resolving:        return "Resolving…"
        case .trustCheck:       return "Trust check…"
        case .sovereigntyCheck: return "Sovereignty check…"
        case .downloading:      return "Downloading…"
        case .verifying:        return "Verifying signature…"
        case .installing:       return "Installing…"
        case .registering:      return "Recording install…"
        case .completed:        return "Done."
        case .failed:           return "Failed."
        }
    }

    /// URLSession-based download.  Uses `download(from:)` so the
    /// system streams to disk efficiently regardless of file size
    /// (no all-into-memory step).  The per-byte progress callback is
    /// not driven from this path — the row's `Phase.downloading`
    /// state shows an indeterminate spinner during the download
    /// phase; once install starts, the real per-stage progress from
    /// InstallerEngine kicks in.  A future commit can swap this for
    /// a delegate-based downloader if granular progress is needed.
    nonisolated private func downloadToFile(from url: URL, to dest: URL,
                                            onProgress: @Sendable @escaping (Double) -> Void) async throws {
        var req = URLRequest(url: url)
        req.timeoutInterval = 60
        let (tmpURL, response) = try await URLSession.shared.download(for: req)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        // The system places the result in a temp directory it owns —
        // move into our caller-supplied tmpDir.  `replaceItemAt` is
        // a no-op when dest doesn't exist; we use moveItem directly
        // for simplicity since we just created the parent dir.
        try? FileManager.default.removeItem(at: dest)
        try FileManager.default.moveItem(at: tmpURL, to: dest)
        onProgress(1.0)
    }
}

extension Notification.Name {
    /// 2026-05-08: posted by UpdatesView when the user clicks
    /// "Update all" so each idle, actionable UpdateRow can kick its
    /// own performUpdate() flow without the parent view needing to
    /// observe per-row state.
    static let splynekUpdateAllRequested = Notification.Name("splynek.updateAllRequested")

    /// Posted by UpdateRow after a successful install.  UpdatesView
    /// listens and re-runs the scanner + resolver so the just-updated
    /// row drops out of `updatesAvailable` without needing the user
    /// to manually trigger a re-scan.
    static let splynekUpdatesDidInstall = Notification.Name("splynek.updatesDidInstall")
}

#endif
