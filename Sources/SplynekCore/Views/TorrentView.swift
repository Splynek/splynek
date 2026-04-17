import SwiftUI

struct TorrentView: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var progress: TorrentProgress

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PageHeader(
                    systemImage: "antenna.radiowaves.left.and.right",
                    title: "Torrents",
                    subtitle: "Native BitTorrent v1 + v2 + hybrid. Paste a magnet, load a .torrent, or pick a web-seed mirror. Integrity is verified per piece."
                )
                sourceCard
                interfaceCard
                if let info = vm.torrentInfo {
                    infoCard(info)
                }
                if vm.isTorrenting || progress.finished || progress.errorMessage != nil {
                    progressCard
                }
                if let seed = progress.seeding, seed.listening {
                    seedingCard(seed)
                }
            }
            .padding(20)
            .animation(.easeInOut(duration: 0.2), value: progress.finished)
            .animation(.easeInOut(duration: 0.2), value: progress.seeding?.listening)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Torrents")
        .toolbar { torrentToolbar }
    }

    @ToolbarContentBuilder
    private var torrentToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            if vm.isTorrenting {
                Button(role: .destructive) { vm.cancelTorrent() } label: {
                    Label("Cancel", systemImage: "stop.fill")
                }
                .keyboardShortcut(".", modifiers: .command)
            } else if vm.torrentInfo != nil {
                Button { vm.startTorrent() } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return)
            }
        }
    }

    // MARK: Source card

    private var sourceCard: some View {
        TitledCard(title: "Source", systemImage: "link") {
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "magnet")
                        .foregroundStyle(.secondary)
                    TextField("magnet:?xt=urn:btih:…", text: $vm.magnetText)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .disabled(vm.isTorrenting)
                    Button("Parse") { vm.parseMagnet() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(vm.isTorrenting || vm.magnetText.isEmpty)
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

                HStack {
                    Button { vm.loadTorrentFile() } label: {
                        Label("Load .torrent file…", systemImage: "doc.badge.arrow.up")
                    }
                    .buttonStyle(.bordered)
                    .disabled(vm.isTorrenting)
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Toggle("Seed when complete", isOn: $vm.seedAfterCompletion)
                            .toggleStyle(.switch)
                            .disabled(vm.isTorrenting)
                            .help("Once the download finishes, keep serving pieces to other peers.")
                        Toggle("Seed while leeching", isOn: $vm.seedWhileLeeching)
                            .toggleStyle(.switch)
                            .disabled(vm.isTorrenting)
                            .help("Serve completed pieces to other peers before the download finishes.")
                    }
                }

                HStack(spacing: 8) {
                    Image(systemName: "folder")
                        .foregroundStyle(.secondary)
                    Text(vm.outputDirectory.path)
                        .font(.system(.callout, design: .monospaced))
                        .lineLimit(1).truncationMode(.middle)
                    Spacer()
                    Button("Change…") { vm.chooseOutputDirectory() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(vm.isTorrenting)
                }
            }
        }
    }

    // MARK: Interface card

    private var interfaceCard: some View {
        TitledCard(
            title: "Interface",
            systemImage: "network",
            accessory: AnyView(
                Button { Task { await vm.refreshInterfaces() } } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .disabled(vm.isTorrenting)
            )
        ) {
            if vm.interfaces.isEmpty {
                EmptyStateView(systemImage: "network.slash",
                               title: "Discovering interfaces…", message: nil)
            } else {
                VStack(spacing: 6) {
                    ForEach(vm.interfaces) { iface in
                        InterfaceRow(
                            interface: iface,
                            selected: Binding(
                                get: { vm.selected.contains(iface.name) },
                                set: { on in
                                    if on { vm.selected.insert(iface.name) }
                                    else  { vm.selected.remove(iface.name) }
                                }),
                            historicalBps: vm.laneProfile[iface.name],
                            disabled: vm.isTorrenting || iface.nwInterface == nil,
                            capBps: Binding(
                                get: { vm.interfaceCapsBps[iface.name] ?? 0 },
                                set: { vm.setInterfaceCap(iface.name, bytesPerSecond: $0) }
                            )
                        )
                    }
                }
            }
        }
    }

    // MARK: Info card

    private func infoCard(_ info: TorrentInfo) -> some View {
        let httpTrackers = info.announceURLs.filter { $0.scheme?.lowercased().hasPrefix("http") == true }.count
        let udpTrackers = info.announceURLs.filter { $0.scheme?.lowercased() == "udp" }.count
        return TitledCard(title: "Torrent", systemImage: "doc.fill") {
            HStack(spacing: 24) {
                if info.totalLength > 0 {
                    MetricView(value: formatBytes(info.totalLength), caption: "Size")
                } else {
                    MetricView(value: "—", caption: "Size (metadata pending)", tint: .orange)
                }
                if info.numPieces > 0 {
                    MetricView(value: "\(info.numPieces)", caption: "Pieces")
                }
                if info.isMultiFile {
                    MetricView(value: "\(info.files.count)", caption: "Files")
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        StatusPill(text: "\(httpTrackers) HTTP", style: .info)
                        StatusPill(text: "\(udpTrackers) UDP", style: .info)
                    }
                    Text("Trackers")
                        .font(.caption).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.6)
                }
                VStack(alignment: .leading, spacing: 2) {
                    StatusPill(
                        text: info.metaVersion.displayLabel,
                        style: info.metaVersion == .hybrid ? .success
                             : info.metaVersion == .v2     ? .info
                             : .neutral
                    )
                    Text("Format")
                        .font(.caption).foregroundStyle(.secondary)
                        .textCase(.uppercase).tracking(0.6)
                }
                Spacer()
            }
            .padding(.vertical, 4)
            Text(info.name)
                .font(.system(.callout, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1).truncationMode(.middle)
        }
    }

    // MARK: Progress card

    private var progressCard: some View {
        TitledCard(title: "Progress", systemImage: "chart.line.uptrend.xyaxis",
                   accessory: progressAccessory) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 24) {
                    MetricView(
                        value: String(format: "%.1f%%", progress.fraction * 100),
                        caption: "Complete",
                        tint: progress.finished ? .green : .accentColor
                    )
                    MetricView(
                        value: "\(progress.piecesDone)/\(progress.pieces)",
                        caption: "Pieces"
                    )
                    MetricView(
                        value: "\(progress.activePeers)",
                        caption: "Active peers",
                        tint: .accentColor
                    )
                    MetricView(
                        value: "\(progress.peers)",
                        caption: "Known peers"
                    )
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(formatBytes(progress.downloaded))
                            .font(.system(.headline, design: .rounded))
                            .monospacedDigit()
                        Text("of \(formatBytes(progress.totalBytes))")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
                GradientProgressBar(fraction: progress.fraction, height: 10)
                HStack(spacing: 8) {
                    if !progress.phase.isEmpty {
                        Text(progress.phase)
                            .font(.callout).foregroundStyle(.secondary)
                    }
                    if progress.endgame {
                        StatusPill(text: "ENDGAME", style: .warning)
                    }
                    Spacer()
                }
                if let err = progress.errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(err).font(.callout)
                    }
                }
            }
        }
    }

    private var progressAccessory: AnyView? {
        if progress.finished && progress.seeding == nil {
            return AnyView(StatusPill(text: "COMPLETE", style: .success))
        }
        if progress.errorMessage != nil {
            return AnyView(StatusPill(text: "ERROR", style: .danger))
        }
        if vm.isTorrenting {
            return AnyView(StatusPill(text: "DOWNLOADING", style: .info))
        }
        return nil
    }

    // MARK: Seeding

    private func seedingCard(_ seed: SeedingProgress) -> some View {
        TitledCard(
            title: "Seeding",
            systemImage: "antenna.radiowaves.left.and.right",
            accessory: AnyView(StatusPill(text: "LIVE", style: .info))
        ) {
            HStack(spacing: 24) {
                MetricView(value: "\(seed.port)", caption: "Port", tint: .accentColor, monospaced: true)
                MetricView(value: "\(seed.connectedPeers)", caption: "Connected peers", tint: .accentColor)
                MetricView(value: formatBytes(seed.bytesServed), caption: "Uploaded")
                MetricView(value: formatDuration(seed.uptime), caption: "Uptime")
                Spacer()
            }
        }
    }
}
