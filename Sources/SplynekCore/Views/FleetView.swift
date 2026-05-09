import SwiftUI

struct FleetView: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject private var fleet: FleetCoordinator

    @MainActor
    init(vm: SplynekViewModel) {
        self.vm = vm
        _fleet = ObservedObject(wrappedValue: vm.fleet)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ContextCard(
                    systemImage: "laptopcomputer.and.arrow.down",
                    subtitle: "Other Splynek Macs on your LAN, advertised over Bonjour. Shared files skip the internet — downloads go Mac-to-Mac at gigabit.",
                    tint: .cyan
                )
                thisDeviceCard
                peersCard
                localActivityCard
                // 2026-05-09: householdTokenCard + securityCard
                // migrated from Settings.  Both are LAN-scoped:
                // the swarm token is the household identity boundary,
                // the security toggles control privacy mode +
                // loopback-only binding.  They configure the same
                // surface this tab visualises.
                householdTokenCard
                securityCard
            }
            .padding(20)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Fleet")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    fleet.refreshAll()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .help("Re-query every fleet peer for current downloads")
            }
        }
    }

    // MARK: This device

    private var thisDeviceCard: some View {
        TitledCard(
            title: "This Mac",
            systemImage: "laptopcomputer",
            accessory: AnyView(
                StatusPill(text: fleet.port > 0 ? "ADVERTISED" : "STARTING", style: .info)
            )
        ) {
            HStack(spacing: 24) {
                MetricView(value: fleet.deviceName, caption: "Name")
                MetricView(
                    value: String(fleet.deviceUUID.prefix(8)),
                    caption: "Device ID", monospaced: true
                )
                MetricView(
                    value: fleet.port > 0 ? "\(fleet.port)" : "—",
                    caption: "Port", tint: .accentColor, monospaced: true
                )
                MetricView(
                    value: "\(fleet.local.active.count)",
                    caption: "Active",
                    tint: fleet.local.active.isEmpty ? .primary : .accentColor
                )
                MetricView(
                    value: "\(fleet.local.completed.count)",
                    caption: "Shareable"
                )
                MetricView(
                    value: "\(fleet.sharedByHashCount)",
                    caption: "Hashed",
                    tint: fleet.sharedByHashCount > 0 ? .green : .primary
                )
                Spacer()
            }
        }
    }

    // MARK: Peers

    private var peersCard: some View {
        TitledCard(title: "Peers on this LAN", systemImage: "antenna.radiowaves.left.and.right") {
            if fleet.peers.isEmpty {
                EmptyStateView(
                    systemImage: "laptopcomputer.slash",
                    title: "No other Splynek Macs found",
                    message: "Fleet advertises every Splynek install on this network over Bonjour. Anything else with Splynek open will show up here and can lend completed downloads to this Mac."
                )
            } else {
                VStack(spacing: 8) {
                    ForEach(fleet.peers) { peer in
                        peerRow(peer)
                    }
                }
            }
        }
    }

    private func peerRow(_ peer: FleetPeer) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 22))
                .foregroundStyle(.tint)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(peer.name)
                        .font(.headline)
                    if peer.isResolved {
                        StatusPill(text: "\(peer.resolvedPort ?? 0)", style: .info)
                    } else {
                        StatusPill(text: "RESOLVING", style: .warning)
                    }
                    if let seen = peer.lastOK {
                        StatusPill(
                            text: "LAST \(Int(-seen.timeIntervalSinceNow))s",
                            style: .neutral
                        )
                    }
                    // v1.9.5: badge for active swarms the peer is
                    // serving — sourced from vm.peerSwarms which is
                    // refreshed every 10s by SwarmAnnouncementObserver.
                    // Tooltip lists the swarm jobIDs so power users
                    // can confirm what's available without opening a
                    // browser to /swarm/list.
                    if let swarms = vm.peerSwarms[peer.uuid], !swarms.isEmpty {
                        StatusPill(text: "\(swarms.count) SWARM", style: .success)
                            .help(swarmTooltip(for: swarms))
                    }
                }
                Text(peer.uuid)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                if !peer.state.active.isEmpty {
                    Text("Downloading now:")
                        .font(.caption).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.6)
                    ForEach(peer.state.active, id: \.url) { job in
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .foregroundStyle(.secondary)
                            Text(job.filename)
                                .font(.callout)
                            Spacer()
                            Text("\(job.completedChunks.count) chunks · \(formatBytes(job.totalBytes))")
                                .font(.caption).foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
                if !peer.state.completed.isEmpty {
                    Text("Shareable (\(peer.state.completed.count)):")
                        .font(.caption).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.6)
                    ForEach(peer.state.completed.prefix(6), id: \.url) { done in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green.opacity(0.8))
                            Text(done.filename)
                                .font(.callout)
                            Spacer()
                            Text(formatBytes(done.totalBytes))
                                .font(.caption).foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
    }

    // MARK: Local activity
    //
    // 2026-05-08 revolution.  Three problems with the prior layout:
    //   - Same file appearing 4× when Finder had renamed (`X (1).zip`)
    //     made the card look broken.  Now deduped by `outputPath`
    //     with a "× N" badge + "saved at <date>" tooltip.
    //   - The eye-slash button was styled as `.foregroundStyle(.secondary)`
    //     which made it indistinguishable from the byte-count text
    //     next to it.  Users couldn't tell it was a button.  Now each
    //     row has a hover-revealed action group: Reveal · Stop sharing
    //     · Trash, with explicit labels and a context-menu mirror.
    //   - No way to reclaim disk space.  Trash now moves the file to
    //     the macOS Trash via `NSWorkspace.recycle` and prunes every
    //     matching history entry so the row disappears.

    /// One displayable row in the "What this Mac is sharing" list.
    /// 2026-05-08 dedupe v2: groups by `sha256` when present ("same
    /// content under different paths" — e.g. same URL downloaded
    /// twice with Finder rename), falling back to `(filename,
    /// totalBytes)` for legacy entries without SHA, falling back to
    /// outputPath when even the size is missing.  Each row tracks
    /// every URL + outputPath that mapped to it so Stop-sharing /
    /// Trash actions can fan out across all underlying entries.
    fileprivate struct ShareRow: Identifiable {
        let id: String              // dedup key (sha256 │ filename|size │ outputPath)
        let filename: String
        let outputPath: String      // representative path (the first that exists on disk)
        let allURLs: [String]       // every URL pointed at this content
        let allOutputPaths: [String]
        let totalBytes: Int64
        let copies: Int
        let mostRecent: Date
    }

    private var dedupedCompleted: [ShareRow] {
        // Build the dedup key.  SHA-256 is the strongest signal
        // (content-addressed); fall back to (filename, totalBytes)
        // which catches Finder-rename twins; final fallback is
        // outputPath when neither is available.
        func keyFor(_ done: FleetCoordinator.LocalState.CompletedFile) -> String {
            if let sha = done.sha256, !sha.isEmpty {
                return "sha:\(sha.lowercased())"
            }
            if done.totalBytes > 0 && !done.filename.isEmpty {
                return "name:\(done.filename)|\(done.totalBytes)"
            }
            return "path:\(done.outputPath)"
        }

        let fm = FileManager.default
        var byKey: [String: ShareRow] = [:]
        for done in fleet.local.completed {
            let key = keyFor(done)
            if let existing = byKey[key] {
                var paths = existing.allOutputPaths
                if !paths.contains(done.outputPath) { paths.append(done.outputPath) }
                var urls = existing.allURLs
                if !urls.contains(done.url) { urls.append(done.url) }
                let representative = paths.first(where: { fm.fileExists(atPath: $0) })
                    ?? existing.outputPath
                byKey[key] = ShareRow(
                    id: key,
                    filename: existing.filename,
                    outputPath: representative,
                    allURLs: urls,
                    allOutputPaths: paths,
                    totalBytes: existing.totalBytes,
                    copies: existing.copies + 1,
                    mostRecent: max(existing.mostRecent, done.finishedAt)
                )
            } else {
                byKey[key] = ShareRow(
                    id: key,
                    filename: done.filename,
                    outputPath: done.outputPath,
                    allURLs: [done.url],
                    allOutputPaths: [done.outputPath],
                    totalBytes: done.totalBytes,
                    copies: 1,
                    mostRecent: done.finishedAt
                )
            }
        }
        return byKey.values.sorted { $0.totalBytes > $1.totalBytes }
    }

    private var localActivityCard: some View {
        let rows = dedupedCompleted
        let totalBytes = rows.reduce(Int64(0)) { $0 + $1.totalBytes }

        return TitledCard(
            title: "What this Mac is sharing",
            systemImage: "tray.and.arrow.up",
            accessory: rows.isEmpty
                ? nil
                : AnyView(
                    Text("\(rows.count) · \(formatBytes(totalBytes))")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                  )
        ) {
            if fleet.local.active.isEmpty && rows.isEmpty {
                Text("Nothing yet. Start a download — other Splyneks on this LAN will see it and can pull completed chunks from this Mac once they land on disk.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(fleet.local.active, id: \.url) { job in
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.down.circle.fill")
                                .foregroundStyle(Color.accentColor)
                            Text(job.filename).font(.callout)
                            Spacer()
                            Text("\(job.completedChunks.count) chunks")
                                .font(.caption).foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    ForEach(rows) { row in
                        ShareableRowView(row: row, vm: vm)
                    }
                    if !vm.fleetExcludedURLs.isEmpty {
                        Divider().opacity(0.3)
                        HStack(spacing: 6) {
                            Image(systemName: "eye.slash")
                                .foregroundStyle(.secondary)
                            Text("\(vm.fleetExcludedURLs.count) file\(vm.fleetExcludedURLs.count == 1 ? "" : "s") hidden from fleet.")
                                .font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore all") {
                                for url in vm.fleetExcludedURLs {
                                    vm.toggleFleetSharing(url: url)
                                }
                            }
                            .buttonStyle(.splynekHover)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }

    /// v1.9.5: tooltip body for the SWARM badge.  Lists each
    /// listing's short jobID + completion fraction so a power user
    /// hovering can see which swarms are available without opening
    /// a separate inspector.
    private func swarmTooltip(for listings: [FleetChunkSwarm.Listing]) -> String {
        let lines = listings.map { l -> String in
            let pct = Int(l.fractionComplete * 100)
            let head = String(l.jobID.uuidString.prefix(8))
            let bytes = ByteCountFormatter.string(
                fromByteCount: l.totalBytes, countStyle: .file
            )
            return "• \(head)…  \(pct)%  (\(bytes))"
        }
        return ([listings.count == 1
                ? "1 active swarm:"
                : "\(listings.count) active swarms:"] + lines)
            .joined(separator: "\n")
    }
}

// MARK: - ShareableRowView (separate so @State / .onHover compose cleanly)
//
// SwiftUI doesn't allow @State inside a @ViewBuilder local function;
// extracting the hover-state-bearing row to a tiny struct keeps the
// FleetView body readable.

private struct ShareableRowView: View {
    let row: FleetView.ShareRow
    @ObservedObject var vm: SplynekViewModel

    @State private var hovered: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text(row.filename)
                .font(.callout)
                .lineLimit(1).truncationMode(.middle)
            if row.copies > 1 {
                Text("×\(row.copies)")
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(
                        Capsule().fill(Color.secondary.opacity(0.15))
                    )
                    .help("\(row.copies) history entries point at this same file. Trashing here removes them all.")
            }
            Spacer()

            if hovered {
                HStack(spacing: 4) {
                    Button {
                        vm.revealInFinder(outputPath: row.outputPath)
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .buttonStyle(.splynekHover)
                    .help("Reveal in Finder")

                    Button {
                        // 2026-05-08: fan out across every URL that
                        // mapped to this dedup’d row.  The previous
                        // single-URL toggle only excluded one of the
                        // underlying entries, so the row stayed in
                        // the share pool via its peers.
                        for url in row.allURLs {
                            vm.toggleFleetSharing(url: url)
                        }
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .buttonStyle(.splynekHover)
                    .help("Stop sharing this file with other Splyneks on the LAN.")

                    Button(role: .destructive) {
                        // Trash the representative path (file is the
                        // same content under every dedup’d entry);
                        // history rows under any of the alt paths
                        // get pruned by trashAndForgetCompletedFile.
                        for path in row.allOutputPaths {
                            vm.trashAndForgetCompletedFile(outputPath: path)
                        }
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.85))
                    }
                    .buttonStyle(.splynekHover)
                    .keyboardShortcut(.delete, modifiers: .command)
                    .help("Move the file to the Trash and remove it from Splynek's history.")
                }
            } else {
                Text(formatBytes(row.totalBytes))
                    .font(.caption).foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .contextMenu {
            Button("Reveal in Finder") {
                vm.revealInFinder(outputPath: row.outputPath)
            }
            Button("Stop sharing on the LAN") {
                for url in row.allURLs {
                    vm.toggleFleetSharing(url: url)
                }
            }
            Divider()
            Button("Move to Trash", role: .destructive) {
                for path in row.allOutputPaths {
                    vm.trashAndForgetCompletedFile(outputPath: path)
                }
            }
        }
    }
}

// MARK: - Household token + Security (migrated from SettingsView 2026-05-09)
//
// Both cards configure the LAN/swarm surface this tab visualises:
// • householdTokenCard — identity boundary for the swarm (peers
//   with the same string can lend bytes to each other; empty
//   disables peer-to-peer transfers).
// • securityCard — privacy mode (hide downloads from peers) +
//   loopback-only (block dashboard from reaching the LAN).
//
// They were buried in Settings; configuration of HOW the LAN
// behaves now lives next to the LAN view itself.

extension FleetView {

    fileprivate var householdTokenCard: some View {
        TitledCard(title: "Household swarm token", systemImage: "person.3.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Set the same string on every Mac in your household to let them share download bytes over the LAN. Empty disables peer-to-peer transfers; phone QR + same-Mac flows still work.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    SecureField("Shared token (any string)", text: $vm.swarmHouseholdToken)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 360)
                    Button {
                        vm.swarmHouseholdToken = ""
                    } label: {
                        Label("Clear", systemImage: "xmark.circle")
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.swarmHouseholdToken.isEmpty)
                }
                if vm.swarmHouseholdToken.isEmpty {
                    StatusPill(text: "OFF", style: .neutral)
                } else {
                    StatusPill(text: "ACTIVE", style: .success)
                }
                Text("Best practice: pick a short memorable phrase, type it on each Mac. Every chunk is still SHA-256 verified before it lands on disk — a malicious peer cannot inject corrupt bytes.")
                    .font(.caption).foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    fileprivate var securityCard: some View {
        TitledCard(title: "Security & privacy", systemImage: "lock.shield.fill") {
            VStack(alignment: .leading, spacing: 12) {
                Text("Controls over what the LAN can see and who can submit downloads to this Mac.")
                    .font(.callout).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Toggle(isOn: Binding(
                    get: { vm.fleet.privacyMode },
                    set: { vm.fleet.privacyMode = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Privacy mode")
                        Text("Hide active + completed downloads from other Splyneks on this LAN. Cooperative cache disabled.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                Toggle(isOn: Binding(
                    get: { vm.fleet.loopbackOnly },
                    set: { vm.fleet.loopbackOnly = $0 }
                )) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loopback only (takes effect at next launch)")
                        Text("Bind the dashboard + API to 127.0.0.1 only. Your phone won't reach it over Wi-Fi.")
                            .font(.caption).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .toggleStyle(.switch)

                Divider().opacity(0.3)

                HStack(spacing: 10) {
                    Button {
                        vm.fleet.regenerateWebToken()
                    } label: {
                        Label("Regenerate token", systemImage: "arrow.triangle.2.circlepath.circle")
                    }
                    .buttonStyle(.bordered)
                    .help("Invalidate any QR code you've already shared. CLI / Raycast / Alfred re-pair automatically.")
                    Text("Rate limit: 60 req / 10 s per remote IP.")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
            }
        }
    }
}
