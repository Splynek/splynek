import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject private var torrent: TorrentProgress
    /// IA v2 (2026-05-13) / Phase 7 (2026-05-23): the active
    /// LifecycleTab.  **Optional** so the first-run welcome screen
    /// can render without any tab highlighted in the sidebar — the
    /// welcome is a splash, not a tab destination.  A non-nil value
    /// means "the user is in the app proper"; nil means "show the
    /// welcome splash".  The sidebar's selection binding follows
    /// this, so during welcome no row is highlighted; when the user
    /// clicks a sidebar row (or any welcome-card story tile),
    /// currentTab transitions nil → tab and the welcome dismisses
    /// via `.onChange`.
    @State private var currentTab: LifecycleTab? = .download
    /// The active subview within the current tab.  Set by either the
    /// chip strip (LifecycleTopBar) or by deep-link notifications
    /// from the menu bar / splynek:// URL handlers.
    @State private var section: SidebarSection = .queue
    /// IA v2 Phase 5 (2026-05-23): the Concierge sheet presentation
    /// flag.  Flipped true by the "Ask Splynek" pill in
    /// LifecycleTopBar (Discover + My Apps) and by the
    /// `.splynekShowConcierge` notification.
    @State private var showingConcierge: Bool = false
    /// IA v2 Phase 6 (2026-05-23): the active Settings/Legal/About
    /// sheet route.  `nil` means no sheet.  Set by the gear-icon
    /// footer button and by the three legacy menu-bar notifications
    /// (`.splynekShowSettings` / `.showLegal` / `.showAbout`) so the
    /// menu items, Cmd+, shortcut, and the gear-icon footer all land
    /// on the same sheet — sometimes pre-focused on a specific pane.
    @State private var settingsRoute: SettingsRoute? = nil

    @MainActor
    init(vm: SplynekViewModel) {
        self.vm = vm
        _torrent = ObservedObject(wrappedValue: vm.torrentProgress)
        // IA v2 Phase 7 (2026-05-23): first-run users see the welcome
        // splash with NO sidebar tab highlighted — currentTab = nil.
        // Tapping any story tile or sidebar row transitions nil →
        // that tab; the .onChange handler flips
        // hasCompletedOnboarding so subsequent launches skip the
        // splash.  Returning users default to Download (Queue) so a
        // daily "what's downloading right now?" launch doesn't reroute.
        if !vm.hasCompletedOnboarding {
            _currentTab = State(initialValue: nil)
        }
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(currentTab: $currentTab, vm: vm, torrent: torrent)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                if let tab = currentTab {
                    // IA v2: chip strip for subview switching.  Renders
                    // only when the current subview's parent tab matches
                    // currentTab — hides itself when the user is on a
                    // Settings/Legal/About route (those have no tab
                    // parent and live in a sheet long-term).
                    if LifecycleTabMapping.parent(of: section) == tab {
                        LifecycleTopBar(
                            currentTab: tab,
                            section: $section,
                            accessory: { _ in nil },
                            trailing: askSplynekTrailing(for:)
                        )
                    }
                    detail
                } else {
                    // IA v2 Phase 7: welcome splash.  Active when
                    // currentTab is nil (first-run).  Each story tile
                    // is a button that sets currentTab to that tab,
                    // which triggers .onChange below to flip
                    // hasCompletedOnboarding + load the default
                    // subview.  No tab is highlighted in the sidebar
                    // because the welcome is a splash, not a tab.
                    DiscoverWelcomeCard(
                        vm: vm,
                        onPick: { tab in
                            currentTab = tab
                        }
                    )
                }
            }
            .navigationSplitViewColumnWidth(min: 640, ideal: 880)
        }
        .navigationSplitViewStyle(.balanced)
        // IA v2: when the user clicks a sidebar tab (or a welcome-
        // card story tile), drop into the tab's default subview.
        // Phase 7: the same handler dismisses the welcome — flipping
        // hasCompletedOnboarding once currentTab transitions from
        // nil → a tab.  newTab being nil shouldn't happen in normal
        // flow (only the welcome init can set it), so we just no-op.
        // Older single-closure onChange form for macOS-13 compat;
        // the two-closure form is macOS-14+.
        .onChange(of: currentTab) { newTab in
            guard let newTab else { return }
            section = LifecycleTabMapping.defaultSubview(for: newTab)
            if !vm.hasCompletedOnboarding {
                vm.hasCompletedOnboarding = true
            }
        }
        .task { await vm.refreshInterfaces() }
        // IA v2 Phase 7 (2026-05-23): the v1.6.1 OnboardingSheet was
        // retired here.  First-run UX is now the DiscoverWelcomeCard
        // surfaced inside the detail column — see `shouldShowWelcomeCard`
        // + the welcome branch in the `detail` VStack.
        //
        // IA v2 Phase 5: Concierge as a sheet.  Visible from the
        // "Ask Splynek" pill on Discover + My Apps and from any
        // future caller that posts `.splynekShowConcierge`.
        .sheet(isPresented: $showingConcierge) {
            ConciergeSheetContainer(vm: vm)
        }
        // IA v2 Phase 6: Settings/Legal/About as a sheet.  Bound to
        // `settingsRoute` so the same sheet handles all three entry
        // points — the route also determines which pane the sheet
        // opens on.  Apple's Cmd+, convention says preferences are a
        // panel, not a tab destination.
        .sheet(item: $settingsRoute) { route in
            SettingsSheet(initialPane: route, vm: vm)
        }
        .onDrop(of: [.url, .fileURL, .plainText], isTargeted: nil) { providers in
            vm.handleDrop(providers: providers)
        }
        .alert("Large download",
               isPresented: $vm.sizeConfirmationPending) {
            Button("Cancel", role: .cancel) { vm.declineLargeDownload() }
            Button("Download anyway") { vm.confirmLargeDownload() }
        } message: {
            Text("This download is \(formatBytes(vm.pendingSizeBytes)). Continue?")
        }
        .alert("Daily cap reached",
               isPresented: $vm.hostCapAlertPending) {
            Button("Cancel", role: .cancel) { vm.declineOverCapDownload() }
            Button("Download anyway", role: .destructive) { vm.confirmOverCapDownload() }
        } message: {
            Text("Today you've already used \(formatBytes(vm.hostCapAlertUsed)) from \(vm.hostCapAlertHost), past your \(formatBytes(vm.hostCapAlertLimit)) daily cap. Downloading anyway will clear today's cap for this host.")
        }
        // v0.49 / IA v2 Phase 6: menu-bar + gear-icon routing for
        // Settings / Legal / About.  The Apple menu's "Settings…"
        // (Cmd+,) and "About Splynek", and the Help menu's "Legal…",
        // each post one of these three notifications.  Phase 6
        // (2026-05-23) redirects them from a detail-column section
        // assignment to the unified `SettingsSheet` — Apple's macOS
        // convention says preferences are a panel, not a tab.  The
        // sidebar tab stays on whatever LifecycleTab the user was
        // on; the sheet floats over the active content.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSettings)) { _ in
            settingsRoute = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowLegal)) { _ in
            settingsRoute = .legal
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowAbout)) { _ in
            settingsRoute = .about
        }
        // v1.6: Spotlight deep-link routing.  Activating a Sovereignty
        // or Trust hit from the system search bar fires the matching
        // `splynek://<tab>/<bundle-id>` URL, which posts these
        // notifications.  Update both section + currentTab so the
        // chip strip + sidebar both follow.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSovereignty)) { note in
            section = .sovereignty
            // Phase 7: optional currentTab — Spotlight deep links to
            // a Sovereignty bundle implicitly dismiss the welcome
            // splash because currentTab transitions to a non-nil
            // value (the .onChange handler above then flips
            // hasCompletedOnboarding).
            if let parent = LifecycleTabMapping.parent(of: .sovereignty) {
                currentTab = parent
            }
            vm.sovereigntyFocusedBundleID = note.userInfo?["bundleID"] as? String
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowTrust)) { note in
            section = .trust
            if let parent = LifecycleTabMapping.parent(of: .trust) {
                currentTab = parent
            }
            vm.trustFocusedBundleID = note.userInfo?["bundleID"] as? String
        }
        // IA v2 Phase 5: open the Concierge sheet from any caller.
        // Posted by the "Ask Splynek" pill, the menu bar item, and
        // any future `splynek://concierge` deep link.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowConcierge)) { _ in
            showingConcierge = true
        }
    }

    /// IA v2 Phase 5: trailing-accessory builder for `LifecycleTopBar`.
    /// Returns the "Ask Splynek" pill on tabs where the Concierge is
    /// contextually useful — Discover (pre-install decisions) and My
    /// Apps (post-install care).  Other tabs return nil so the
    /// trailing slot stays empty.
    private func askSplynekTrailing(for tab: LifecycleTab) -> AnyView? {
        switch tab {
        case .discover, .myApps:
            return AnyView(AskSplynekPill())
        case .download, .coordinate:
            return nil
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .downloads:   DownloadView(vm: vm)
        case .live:        LiveView(vm: vm)
        case .torrents:    TorrentView(vm: vm, progress: torrent)
        case .concierge:   ConciergeView(vm: vm)
        case .recipes:     RecipeView(vm: vm)
        case .sovereignty: SovereigntyView(vm: vm)
        case .trust:       TrustView(vm: vm)
        case .savings:     SavingsView(vm: vm)
        case .agents:      AgentsView(vm: vm)
        case .queue:       QueueView(vm: vm)
        case .fleet:       FleetView(vm: vm)
        case .apps:        AppsView(vm: vm)
        case .benchmark:   BenchmarkView(vm: vm)
        case .history:     HistoryView(vm: vm)
        case .settings:    SettingsView(vm: vm)
        case .legal:       LegalView(vm: vm)
        case .about:       AboutView(vm: vm)
        // IA v2 Phase 3 — new My Apps subviews.
        case .installedInventory: InstalledInventoryView(vm: vm)
        case .trustWatcherInbox:  TrustWatcherInboxView(vm: vm)
        }
    }

}
