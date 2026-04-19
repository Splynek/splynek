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
                PageHeader(
                    systemImage: "laptopcomputer.and.arrow.down",
                    title: "Fleet",
                    subtitle: "Other Splynek Macs on your LAN, advertised over Bonjour. Shared files skip the internet — downloads go Mac-to-Mac at gigabit."
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

    private var localActivityCard: some View {
        TitledCard(title: "What this Mac is sharing", systemImage: "tray.and.arrow.up") {
            if fleet.local.active.isEmpty && fleet.local.completed.isEmpty {
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
                    ForEach(fleet.local.completed.prefix(10), id: \.url) { done in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(done.filename).font(.callout)
                                .lineLimit(1).truncationMode(.middle)
                            Spacer()
                            Text(formatBytes(done.totalBytes))
                                .font(.caption).foregroundStyle(.secondary)
                                .monospacedDigit()
                            // v0.46: per-file "stop sharing" button.
                            // Clicking this removes the file from
                            // fleet offerings on this Mac but keeps
                            // the file + the history entry intact.
                            // The exclusion list is persisted; a
                            // re-toggle from History puts the file
                            // back in the share pool.
                            Button(role: .destructive) {
                                vm.toggleFleetSharing(url: done.url)
                            } label: {
                                Image(systemName: "eye.slash")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .help("Stop sharing this file with other Splyneks on the LAN. The file and history entry are kept; only fleet sharing stops.")
                        }
                    }
                    // v0.46: if any files are excluded, surface a
                    // small restore link at the bottom so users can
                    // undo without digging through history.
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
                            .buttonStyle(.borderless)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
    }
}
