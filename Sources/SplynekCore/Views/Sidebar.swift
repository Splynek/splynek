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
    /// IA v2 Phase 7 (2026-05-23): optional binding so the first-run
    /// welcome splash can render with no row highlighted.  Selecting
    /// any row transitions nil → tab; RootView's `.onChange` dismisses
    /// the splash by flipping `hasCompletedOnboarding`.
    @Binding var currentTab: LifecycleTab?
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var torrent: TorrentProgress

    var body: some View {
        // Phase 7.v13 (2026-05-24): back to SwiftUI's standard
        // `List(selection:)` sidebar.  This is the trigger for the
        // macOS 14+ NavigationSplitView auto floating-card styling —
        // rounded corners, inset from window edges, material that
        // extends up to cover the title-bar area.  The "since the
        // start" look the user kept asking for.  The fact that I
        // ever moved away from List(selection:) (Phase 7.v4 commit
        // 23fcb07) was the original mistake.
        //
        // Each row's content carries the tab's tintColor + slogan —
        // the colored richness the user wants — but they live INSIDE
        // a standard List row so we get the auto-styling for free.
        // When a row is selected, the slogan switches to white so it
        // stays readable on the system blue selection highlight.
        VStack(spacing: 0) {
            // Phase 7.v14b (2026-05-24): rich `SidebarTileButton`
            // tiles wrapped inside `List(selection:)` rows.  The List
            // keeps the macOS 14+ NavigationSplitView auto floating-
            // card styling alive (so traffic lights stay INSIDE the
            // sidebar pane); the tile owns its OWN colored
            // background + iconWell + slogan, and the default List
            // selection chrome is neutralised via clear listRow
            // background + hidden separators + plain list style.
            // Result: the rich tile look the user wants AND the
            // floating-card chrome they want, in one view.
            List(selection: $currentTab) {
                ForEach(LifecycleTab.allCases) { tab in
                    SidebarTileButton(
                        tab: tab,
                        isActive: currentTab == tab,
                        accessory: accessory(for: tab)
                    ) {
                        currentTab = tab
                    }
                    .tag(tab)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 7, leading: 10,
                                              bottom: 7, trailing: 10))
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            brandFooter
        }
        // Phase 7.v14 (2026-05-24): the navigationTitle was load-bearing
        // for the d94ab61 chrome — without it the unified toolbar paints
        // a separator strip and the floating-card sidebar gets pushed
        // below the traffic lights.  With it, macOS knows the sidebar
        // owns the leading column and lets its material continue up
        // under the title bar (the look the user has been pointing at).
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

// MARK: - SidebarTileButton

/// Phase 7.v4 (2026-05-23) / restored in v14b (2026-05-24): the
/// rich sidebar row.  Each tab gets a tinted iconWell + title +
/// slogan + colored hover/active background — all anchored to the
/// tab's own `tintColor` so the sidebar reads as the same visual
/// vocabulary as the welcome-splash story tiles, scaled down.
///
/// Lives INSIDE a `List(selection:)` row (Phase 7.v14b) so the
/// macOS 14+ NavigationSplitView auto floating-card chrome (rounded
/// corners, material extending up under the title bar) stays alive.
/// The List's default selection rectangle is neutralised in the
/// parent view via `.listRowBackground(Color.clear)`, leaving the
/// tile's own tinted background as the only selection signal.
///
/// Three states, all anchored to `tab.tintColor`:
///   • idle    — soft tinted background (4%) + no border
///   • hover   — slightly stronger background (8%) + tinted outline
///               (35%) + faint scale-up (1.01) for tactile feedback
///   • active  — strongest background (16%) + bold tinted outline
///               (55%) — matches the tab's identity, keeps the
///               slogan readable (no blue-on-blue collision).
struct SidebarTileButton: View {
    let tab: LifecycleTab
    let isActive: Bool
    let accessory: AnyView?
    let onTap: () -> Void
    @State private var isHovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 11) {
                iconWell
                VStack(alignment: .leading, spacing: 2) {
                    Text(LocalizedStringKey(tab.title))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(LocalizedStringKey(tab.slogan))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(tab.tintColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                Spacer(minLength: 0)
                accessory
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 11)
            .background(rowBackground)
            .overlay(rowBorder)
            .contentShape(Rectangle())
            .scaleEffect(isHovered && !isActive ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help(Text(LocalizedStringKey(tab.title)) +
              Text(verbatim: " — ") +
              Text(LocalizedStringKey(tab.promise)))
    }

    private var rowBackground: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(tab.tintColor.opacity(
                isActive ? 0.22 : (isHovered ? 0.12 : 0.06)
            ))
    }

    private var rowBorder: some View {
        RoundedRectangle(cornerRadius: 12)
            .stroke(
                tab.tintColor.opacity(
                    isActive ? 0.65 : (isHovered ? 0.50 : 0)
                ),
                lineWidth: isActive ? 1.4 : 1.0
            )
    }

    private var iconWell: some View {
        Image(systemName: tab.systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(tab.tintColor)
            .frame(width: 32, height: 32)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tab.tintColor.opacity(0.28),
                                tab.tintColor.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(tab.tintColor.opacity(0.32), lineWidth: 0.5)
            )
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

    /// IA v2 Phase 5 (2026-05-23): open the Concierge as a modal
    /// sheet.  Posted by the "Ask Splynek" pill on Discover + My
    /// Apps; RootView catches it and flips a sheet-presentation flag.
    static let splynekShowConcierge = Notification.Name("splynek.showConcierge")
}
