import SwiftUI

/// Which top-level section the sidebar is currently displaying.
enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case downloads, live, torrents, concierge, queue, fleet, benchmark,
         history, settings, legal, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads: return "Downloads"
        case .live:      return "Live"
        case .torrents:  return "Torrents"
        case .concierge: return "Assistant"
        case .queue:     return "Queue"
        case .fleet:     return "Fleet"
        case .benchmark: return "Benchmark"
        case .history:   return "History"
        case .settings:  return "Settings"
        case .legal:     return "Legal"
        case .about:     return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .downloads: return "arrow.down.circle"
        case .live:      return "waveform.circle.fill"
        case .torrents:  return "antenna.radiowaves.left.and.right"
        case .concierge: return "sparkles"
        case .queue:     return "line.3.horizontal.decrease.circle"
        case .fleet:     return "laptopcomputer.and.arrow.down"
        case .benchmark: return "bolt.fill"
        case .history:   return "clock.arrow.circlepath"
        case .settings:  return "gearshape"
        case .legal:     return "doc.text"
        case .about:     return "info.circle"
        }
    }
}

struct Sidebar: View {
    @Binding var selection: SidebarSection
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var torrent: TorrentProgress

    var body: some View {
        List(selection: $selection) {
            Section {
                NavigationLink(value: SidebarSection.downloads) {
                    sidebarRow(
                        title: "Downloads",
                        systemImage: "arrow.down.circle",
                        accessory: vm.isRunning
                            ? AnyView(
                                HStack(spacing: 4) {
                                    Text(compactRate(vm.aggregateThroughputBps))
                                        .font(.system(size: 10, weight: .semibold,
                                                      design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit()
                                        .contentTransition(.numericText())
                                    StatusPill(text: "LIVE", style: .success)
                                }
                              )
                            : nil
                    )
                }
                NavigationLink(value: SidebarSection.torrents) {
                    sidebarRow(
                        title: "Torrents",
                        systemImage: "antenna.radiowaves.left.and.right",
                        accessory: (vm.isTorrenting || torrent.seeding != nil)
                            ? AnyView(StatusPill(
                                text: torrent.seeding != nil ? "SEED" : "LIVE",
                                style: torrent.seeding != nil ? .info : .success))
                            : nil
                    )
                }
                NavigationLink(value: SidebarSection.live) {
                    sidebarRow(
                        title: "Live",
                        systemImage: "waveform.circle.fill",
                        accessory: vm.isRunning
                            ? AnyView(StatusPill(text: "NOW", style: .success))
                            : nil
                    )
                }
            } header: {
                Text("Active")
            }

            Section {
                NavigationLink(value: SidebarSection.concierge) {
                    sidebarRow(
                        title: "Assistant",
                        systemImage: "sparkles",
                        accessory: vm.aiAvailable
                            ? AnyView(StatusPill(text: "AI", style: .info))
                            : nil
                    )
                }
            } header: {
                Text("Ask")
            }

            Section {
                NavigationLink(value: SidebarSection.queue) {
                    sidebarRow(
                        title: "Queue",
                        systemImage: "line.3.horizontal.decrease.circle",
                        accessory: {
                            let pending = vm.queue.filter { $0.status == .pending }.count
                            return pending == 0
                                ? nil
                                : AnyView(Text("\(pending)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit())
                        }()
                    )
                }
                NavigationLink(value: SidebarSection.fleet) {
                    sidebarRow(
                        title: "Fleet",
                        systemImage: "laptopcomputer.and.arrow.down",
                        accessory: {
                            let n = vm.fleet.peers.count
                            return n == 0
                                ? nil
                                : AnyView(Text("\(n)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit())
                        }()
                    )
                }
                NavigationLink(value: SidebarSection.benchmark) {
                    sidebarRow(title: "Benchmark", systemImage: "bolt.fill")
                }
                NavigationLink(value: SidebarSection.history) {
                    sidebarRow(
                        title: "History",
                        systemImage: "clock.arrow.circlepath",
                        accessory: vm.history.isEmpty
                            ? nil
                            : AnyView(Text("\(vm.history.count)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .monospacedDigit())
                    )
                }
                NavigationLink(value: SidebarSection.settings) {
                    sidebarRow(title: "Settings", systemImage: "gearshape")
                }
                NavigationLink(value: SidebarSection.legal) {
                    sidebarRow(title: "Legal", systemImage: "doc.text")
                }
                NavigationLink(value: SidebarSection.about) {
                    sidebarRow(title: "About", systemImage: "info.circle")
                }
            } header: {
                Text("Library")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Splynek")
    }

    @ViewBuilder
    private func sidebarRow(title: String, systemImage: String, accessory: AnyView? = nil) -> some View {
        HStack {
            Label(title, systemImage: systemImage)
            Spacer()
            accessory
        }
    }

    /// Compact throughput string for the sidebar pill: "1.4 MB/s".
    /// Sidebar real-estate is tight; full-fat `formatRate` is too long.
    private func compactRate(_ bps: Double) -> String {
        let units: [(Double, String)] = [
            (1_000_000_000, "GB/s"), (1_000_000, "MB/s"), (1_000, "KB/s")
        ]
        for (threshold, unit) in units where bps >= threshold {
            return String(format: "%.1f%@", bps / threshold, unit)
        }
        return String(format: "%.0fB/s", bps)
    }
}
