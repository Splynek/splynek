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
        // v0.49 layout — ASK first (Pro discovery above the fold),
        // then ACTIVE (what most users open next), then LIBRARY.
        //
        // Settings / Legal / About moved OUT of the sidebar and into
        // the macOS menu bar (Splynek menu) + Apple's standard
        // menu items. See SplynekApp.swift — CommandGroup(replacing:
        // .appSettings) + CommandGroup(replacing: .appInfo) +
        // a Legal... item under Help. They trigger Notifications
        // that RootView catches and routes to the still-valid
        // SidebarSection.settings/.legal/.about destinations.
        VStack(spacing: 0) {
            List(selection: $selection) {

                // MARK: ASK — Pro discovery above the fold.
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

                // MARK: ACTIVE — what's happening right now.
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

                // MARK: LIBRARY — persistent state + tooling.
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
                } header: {
                    Text("Library")
                }
            }
            .listStyle(.sidebar)

            // v0.49 compact brand footer — lives at the bottom of
            // the sidebar so it's always visible but never in the way.
            // Replaces the "Welcome to Splynek" brand strip that used
            // to squat at the top of the Downloads tab, stealing the
            // real estate that should be the user's own content.
            brandFooter
        }
        .navigationTitle("Splynek")
    }

    /// Small 32 pt logo + version at the foot of the sidebar.
    /// Tap-able (opens About via the same mechanism as the menu bar
    /// "About Splynek" item).
    private var brandFooter: some View {
        Button {
            // Reuses the same notification the Apple-menu About item
            // posts — clicking the footer feels identical to choosing
            // About from the menu.
            NotificationCenter.default.post(
                name: .splynekShowAbout, object: nil
            )
        } label: {
            HStack(spacing: 10) {
                Group {
                    if let url = Bundle.main.url(forResource: "Splynek", withExtension: "icns"),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .interpolation(.high)
                    } else if let nsImage = NSApp.applicationIconImage {
                        Image(nsImage: nsImage).resizable().interpolation(.high)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                    }
                }
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Splynek")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    Text("v\(appVersion())")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Divider()
                .frame(maxWidth: .infinity, alignment: .top)
                .opacity(0.5),
            alignment: .top
        )
        .help("About Splynek")
    }

    private func appVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.0.0"
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

/// v0.49: Notification names for the menu-bar → RootView routing.
/// Posted from `SplynekApp.commands`; caught in `RootView.onReceive`.
extension Notification.Name {
    static let splynekShowSettings = Notification.Name("splynek.showSettings")
    static let splynekShowLegal    = Notification.Name("splynek.showLegal")
    static let splynekShowAbout    = Notification.Name("splynek.showAbout")
}
