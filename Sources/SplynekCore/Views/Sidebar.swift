import SwiftUI

/// Which top-level section the sidebar is currently displaying.
///
/// 2026-05-07 sidebar consolidation: `install` + `updates` collapsed
/// into a single `apps` row backed by `AppsView`'s segmented control.
/// `agents` moved into the Library section (was the only resident of
/// a "Connect" section, which felt orphaned).  `settings` / `legal` /
/// `about` are still here as routing destinations even though they're
/// no longer in the sidebar — they're driven from the macOS menu bar
/// via Notifications (see RootView.onReceive).
enum SidebarSection: String, Hashable, CaseIterable, Identifiable {
    case downloads, live, torrents, concierge, recipes, sovereignty, trust,
         savings,
         queue, fleet, apps, agents, benchmark, history,
         settings, legal, about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .downloads:   return "Downloads"
        case .live:        return "Live"
        case .torrents:    return "Torrents"
        case .concierge:   return "Concierge"
        case .recipes:     return "Recipes"
        case .sovereignty: return "Sovereignty"
        case .trust:       return "Trust"
        case .savings:     return "Savings"
        case .agents:      return "Agents"
        case .queue:       return "Queue"
        case .fleet:       return "Fleet"
        case .apps:        return "Apps"
        case .benchmark:   return "Benchmark"
        case .history:     return "History"
        case .settings:    return "Settings"
        case .legal:       return "Legal"
        case .about:       return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .downloads:   return "arrow.down.circle"
        case .live:        return "waveform.circle.fill"
        case .torrents:    return "antenna.radiowaves.left.and.right"
        case .concierge:   return "sparkles"
        case .recipes:     return "list.star"
        case .sovereignty: return "shield.lefthalf.filled"
        case .trust:       return "checkmark.seal"
        case .savings:     return "dollarsign.circle"
        case .agents:      return "antenna.radiowaves.left.and.right"
        case .queue:       return "line.3.horizontal.decrease.circle"
        case .fleet:       return "laptopcomputer.and.arrow.down"
        case .apps:        return "shippingbox.fill"
        case .benchmark:   return "bolt.fill"
        case .history:     return "clock.arrow.circlepath"
        case .settings:    return "gearshape"
        case .legal:       return "doc.text"
        case .about:       return "info.circle"
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
                            // v1.5.1: pills invert on selection so they
                            // stay readable on the selected-row accent.
                            accessory: vm.license.isPro
                                ? (vm.aiAvailable
                                    ? AnyView(StatusPill(text: "AI", style: .info,
                                                         inverted: selection == .concierge))
                                    : nil)
                                : AnyView(StatusPill(text: "PRO", style: .warning,
                                                     inverted: selection == .concierge))
                        )
                    }
                    NavigationLink(value: SidebarSection.recipes) {
                        sidebarRow(
                            title: "Recipes",
                            systemImage: "list.star",
                            accessory: vm.license.isPro
                                ? (vm.currentRecipe != nil
                                    ? AnyView(StatusPill(text: "DRAFT", style: .warning,
                                                         inverted: selection == .recipes))
                                    : (vm.recipeGenerating
                                        ? AnyView(ProgressView().controlSize(.mini))
                                        : nil))
                                : AnyView(StatusPill(text: "PRO", style: .warning,
                                                     inverted: selection == .recipes))
                        )
                    }
                    // v1.2: Sovereignty tab — scan installed apps and
                    // recommend EU / open-source alternatives.  Free
                    // tier; no PRO gate.  The scanning itself is local
                    // and zero-cost; it's a statement of values before
                    // it's a feature, and gating it behind payment
                    // would undermine that statement.
                    NavigationLink(value: SidebarSection.sovereignty) {
                        sidebarRow(
                            title: "Sovereignty",
                            systemImage: "shield.lefthalf.filled",
                            accessory: nil
                        )
                    }
                    // v1.5: Trust tab — public-record audit of installed
                    // apps (App Store privacy labels, regulatory rulings,
                    // CVEs, breaches).  Free-tier; no PRO gate.  Pairs
                    // with Sovereignty: Trust surfaces concerns,
                    // Sovereignty surfaces alternatives.
                    NavigationLink(value: SidebarSection.trust) {
                        sidebarRow(
                            title: "Trust",
                            systemImage: "checkmark.seal",
                            accessory: AnyView(StatusPill(text: "NEW", style: .info,
                                                          inverted: selection == .trust))
                        )
                    }
                    // 2026-05-07 product expansion: Savings tab.
                    // Maps installed paid apps to free alternatives,
                    // shows annualized cost + potential savings.
                    NavigationLink(value: SidebarSection.savings) {
                        sidebarRow(
                            title: "Savings",
                            systemImage: "dollarsign.circle",
                            accessory: AnyView(StatusPill(text: "NEW", style: .info,
                                                          inverted: selection == .savings))
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
                                        StatusPill(text: "LIVE", style: .success,
                                                   inverted: selection == .downloads)
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
                                    style: torrent.seeding != nil ? .info : .success,
                                    inverted: selection == .torrents))
                                : nil
                        )
                    }
                    NavigationLink(value: SidebarSection.live) {
                        sidebarRow(
                            title: "Live",
                            systemImage: "waveform.circle.fill",
                            accessory: vm.isRunning
                                ? AnyView(StatusPill(text: "NOW", style: .success,
                                                     inverted: selection == .live))
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
                    // 2026-05-07: Apps — Install + Updates merged.
                    // 2026-05-08: badge prefers pending update count
                    // (action item) over installed count (info-only).
                    // When updates are pending the pill becomes a
                    // warning-style "↑ N" so it draws the eye; when
                    // everything's current we fall back to the
                    // monospaced installed-count text.
                    NavigationLink(value: SidebarSection.apps) {
                        sidebarRow(
                            title: "Apps",
                            systemImage: "shippingbox.fill",
                            accessory: {
                                let updates = vm.availableUpdateCount
                                if updates > 0 {
                                    return AnyView(
                                        StatusPill(
                                            text: "↑ \(updates)",
                                            style: .warning,
                                            inverted: selection == .apps
                                        )
                                    )
                                }
                                let n = InstalledAppRegistry.load().count
                                return n == 0
                                    ? nil
                                    : AnyView(Text("\(n)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .monospacedDigit())
                            }()
                        )
                    }
                    // 2026-05-07: Agents folded into Library (was its
                    // own one-item "Connect" section, which felt
                    // orphaned).  Pairs naturally with Fleet — both
                    // are connectivity / sharing surfaces.  MCP is
                    // still the primary tenant; the door's still open
                    // for future agents (Spotlight bridge, IPC API).
                    NavigationLink(value: SidebarSection.agents) {
                        sidebarRow(
                            title: "Agents",
                            systemImage: "antenna.radiowaves.left.and.right",
                            accessory: vm.mcpEnabled
                                ? AnyView(StatusPill(text: "ON", style: .success,
                                                     inverted: selection == .agents))
                                : nil
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

            // 2026-05-07: brand footer removed.  The 28pt logo +
            // version + Settings gear used to live here; in practice
            // it ate a sidebar row at every window height and Settings
            // is already in the macOS menu bar (Cmd+,) per the v0.49
            // layout note.  About is also reachable from the Apple
            // menu.  The footer added zero navigation value.
        }
        .navigationTitle("Splynek")
    }

    @ViewBuilder
    private func sidebarRow(title: String, systemImage: String, accessory: AnyView? = nil) -> some View {
        // v1.6.2: route the title String through LocalizedStringKey so
        // the Localizable.xcstrings catalog gets a chance to resolve
        // it.  `Label(_:systemImage:)`'s String overload uses
        // verbatim text — bypasses localization entirely, which left
        // every sidebar tab label in English even when the rest of
        // the UI was rendering in pt-PT / fr / de / etc.
        HStack {
            Label {
                Text(LocalizedStringKey(title))
            } icon: {
                Image(systemName: systemImage)
            }
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

    /// v1.6: Spotlight deep-link routing.  `userInfo["bundleID"]`
    /// carries the focused bundle, when present.  Posted from
    /// `SplynekApp.handleSplynekURL` for `splynek://sovereignty/<id>`
    /// and `splynek://trust/<id>`.
    static let splynekShowSovereignty = Notification.Name("splynek.showSovereignty")
    static let splynekShowTrust       = Notification.Name("splynek.showTrust")

    /// v1.6.1: posted by `OnboardingSheet` when the user clicks
    /// "Run audit + finish".  SovereigntyView's onReceive catches
    /// this and triggers its `@StateObject` scanner.scan().
    static let splynekRunSovereigntyScan = Notification.Name("splynek.runSovereigntyScan")
}
