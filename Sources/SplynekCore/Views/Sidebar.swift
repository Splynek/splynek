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
         settings, legal, about,
         // IA v2 Phase 3 (2026-05-23) — new My Apps subviews:
         //   .installedInventory — unified row-per-app view combining
         //     Sovereignty + Trust + Updates + Trust Watcher.  Default
         //     subview of My Apps.
         //   .trustWatcherInbox — alert feed for material policy
         //     changes detected on the user's installed apps.
         installedInventory, trustWatcherInbox

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
        case .installedInventory: return "Installed"
        case .trustWatcherInbox:  return "Trust Watcher"
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
        case .installedInventory: return "shippingbox"
        case .trustWatcherInbox:  return "bell.badge"
        }
    }
}

struct Sidebar: View {
    /// IA v2 (2026-05-13): binding to LifecycleTab, not SidebarSection.
    /// Sidebar now shows only the 4 lifecycle tabs; subview switching
    /// happens in LifecycleTopBar inside the detail column.
    @Binding var currentTab: LifecycleTab
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var torrent: TorrentProgress

    var body: some View {
        // IA v2 layout — 4 lifecycle tabs:
        //   Discover   — find apps worth installing
        //   Download   — get them here, fast
        //   My Apps    — keep what you have safe
        //   Coordinate — sync across your devices
        //
        // Settings / Legal / About are NOT sidebar destinations.
        // They still exist as SidebarSection cases (RootView's detail
        // switch handles them) but reach via gear icon (sidebar
        // footer) → notification → RootView routing.  Phase 6 of
        // the IA migration converts them to a sheet.
        VStack(spacing: 0) {
            List(selection: $currentTab) {
                Section {
                    ForEach(LifecycleTab.allCases) { tab in
                        NavigationLink(value: tab) {
                            sidebarRow(
                                title: tab.title,
                                systemImage: tab.systemImage,
                                accessory: accessory(for: tab)
                            )
                        }
                    }
                }
            }
            brandFooter
        }
        .navigationTitle("Splynek")
    }

    /// Per-tab accessory pill.  Phase 2 keeps this minimal — only
    /// the LIVE indicator on Download survives the migration; the
    /// other v0.49-era pills (PRO on Concierge, NEW on Trust, etc.)
    /// migrate to subview chip badges in Phase 5.
    private func accessory(for tab: LifecycleTab) -> AnyView? {
        switch tab {
        case .download where vm.isRunning:
            return AnyView(
                HStack(spacing: 4) {
                    Text(compactRate(vm.aggregateThroughputBps))
                        .font(.system(size: 10, weight: .semibold,
                                      design: .monospaced))
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    StatusPill(text: "LIVE", style: .success,
                               inverted: currentTab == .download)
                }
            )
        default:
            return nil
        }
    }

    /// Small 28 pt logo + version at the foot of the sidebar, with
    /// a Settings gear on the trailing edge.  The brand area opens
    /// About; the gear opens Settings.  Both still available from
    /// the macOS menu bar — this is the more discoverable click
    /// target since most users never look in the menu bar for
    /// app-internal settings.
    private var brandFooter: some View {
        HStack(spacing: 0) {
            Button {
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
                .padding(.leading, 12)
                .padding(.vertical, 10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("About Splynek")

            // Settings gear on the trailing edge.  Posts the same
            // notification the menu bar's "Settings…" item posts —
            // RootView routes both to the same SidebarSection.settings
            // destination.  Adding the icon doesn't change behaviour;
            // it only adds a second, more discoverable click target.
            Button {
                NotificationCenter.default.post(
                    name: .splynekShowSettings, object: nil
                )
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            .help("Settings")
            .accessibilityLabel("Settings")
        }
        .background(
            Divider()
                .frame(maxWidth: .infinity, alignment: .top)
                .opacity(0.5),
            alignment: .top
        )
    }

    private func appVersion() -> String { SplynekVersion.current }

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

    /// IA v2 Phase 5 (2026-05-23): open the Concierge as a modal
    /// sheet.  Posted by the "Ask Splynek" pill in LifecycleTopBar
    /// (Discover + My Apps) and any future caller (menu bar, Cmd+K,
    /// `splynek://concierge` deep link).  RootView's onReceive flips
    /// `@State showingConcierge` so `.sheet` presents.
    static let splynekShowConcierge = Notification.Name("splynek.showConcierge")
}
