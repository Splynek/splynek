import SwiftUI

/// Which top-level section the sidebar is currently displaying.
enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case downloads, live, torrents, concierge, recipes, queue, fleet, benchmark,
         history, settings, legal, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads: return "Downloads"
        case .live:      return "Live"
        case .torrents:  return "Torrents"
        case .concierge: return "Concierge"
        case .recipes:   return "Recipes"
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
        case .recipes:   return "list.star"
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

            // v0.48 redesign — Pro discovery via visible-but-locked tabs.
            //
            // Prior v0.43 → v0.47 hid the Concierge + Recipes rows
            // entirely for non-Pro users (workaround for a
            // NavigationSplitView layout bug triggered by a state-
            // dependent view-body shape change). Hiding them solved
            // the bug but killed discoverability — users who never
            // see the tabs never know there's a Pro offering.
            //
            // v0.48: always show both tabs. Accessory flips from the
            // info-pill / draft-pill in Pro state to a "PRO" badge in
            // the locked state. The destination views must render a
            // structurally-stable outer container in both states so
            // the old layout bug stays dormant (see the real
            // ConciergeView / RecipeView in splynek-pro for the
            // implementation — outer VStack always present; only
            // inner content swaps).
            Section {
                NavigationLink(value: SidebarSection.concierge) {
                    sidebarRow(
                        title: "Concierge",
                        systemImage: "sparkles",
                        accessory: vm.license.isPro
                            ? (vm.aiAvailable
                                ? AnyView(StatusPill(text: "AI", style: .info))
                                : nil)
                            : AnyView(StatusPill(text: "PRO", style: .warning))
                    )
                }
                NavigationLink(value: SidebarSection.recipes) {
                    sidebarRow(
                        title: "Recipes",
                        systemImage: "list.star",
                        accessory: vm.license.isPro
                            ? (vm.currentRecipe != nil
                                ? AnyView(StatusPill(text: "DRAFT", style: .warning))
                                : (vm.recipeGenerating
                                    ? AnyView(ProgressView().controlSize(.mini))
                                    : nil))
                            : AnyView(StatusPill(text: "PRO", style: .warning))
                    )
                }
            } header: {
                Text("Ask")
            } footer: {
                if !vm.license.isPro {
                    Text("$29 one-time on the Mac App Store.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
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
