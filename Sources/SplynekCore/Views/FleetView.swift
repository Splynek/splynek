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
    /// Dedupes the underlying `fleet.local.completed` by outputPath,
    /// counts collisions, sums total bytes, and stores the youngest
    /// finishedAt for "saved at" display.
    fileprivate struct ShareRow: Identifiable {
        let id: String              // outputPath — stable across renames
        let filename: String
        let outputPath: String
        let url: String             // a representative URL (any one)
        let totalBytes: Int64
        let copies: Int
        let mostRecent: Date
    }

    private var dedupedCompleted: [ShareRow] {
        var byPath: [String: ShareRow] = [:]
        for done in fleet.local.completed {
            if let existing = byPath[done.outputPath] {
                byPath[done.outputPath] = ShareRow(
                    id: existing.id,
                    filename: existing.filename,
                    outputPath: existing.outputPath,
                    url: existing.url,
                    totalBytes: existing.totalBytes,
                    copies: existing.copies + 1,
                    mostRecent: max(existing.mostRecent, done.finishedAt)
                )
            } else {
                byPath[done.outputPath] = ShareRow(
                    id: done.outputPath,
                    filename: done.filename,
                    outputPath: done.outputPath,
                    url: done.url,
                    totalBytes: done.totalBytes,
                    copies: 1,
                    mostRecent: done.finishedAt
                )
            }
        }
        return byPath.values.sorted { $0.totalBytes > $1.totalBytes }
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
                        vm.toggleFleetSharing(url: row.url)
                    } label: {
                        Image(systemName: "eye.slash")
                    }
                    .buttonStyle(.splynekHover)
                    .help("Stop sharing this file with other Splyneks on the LAN.")

                    Button(role: .destructive) {
                        vm.trashAndForgetCompletedFile(outputPath: row.outputPath)
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
                vm.toggleFleetSharing(url: row.url)
            }
            Divider()
            Button("Move to Trash", role: .destructive) {
                vm.trashAndForgetCompletedFile(outputPath: row.outputPath)
            }
        }
    }
}
