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
            Sidebar(currentTab: sidebarTabBinding,
                    vm: vm, torrent: torrent)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                // Phase 7.v3 (2026-05-23): the splash gate is now the
                // persisted flag directly, not currentTab.  macOS
                // state restoration / SwiftUI auto-selection can set
                // currentTab to a non-nil value at launch — we don't
                // want that to silently dismiss a splash the user
                // hasn't seen yet.  The sidebar gets a custom binding
                // (sidebarTabBinding) so during splash it always reads
                // nil (= no row highlighted) regardless of what
                // currentTab carries underneath.
                if !vm.hasCompletedOnboarding {
                    DiscoverWelcomeCard(
                        vm: vm,
                        onPick: { tab in
                            pickTab(tab)
                        }
                    )
                } else if let tab = currentTab {
                    // Normal app — chip strip + detail.
                    if LifecycleTabMapping.parent(of: section) == tab {
                        LifecycleTopBar(
                            currentTab: tab,
                            section: $section,
                            accessory: { _ in nil },
                            trailing: askSplynekTrailing(for:)
                        )
                    }
                    detail
                }
            }
            .navigationSplitViewColumnWidth(min: 640, ideal: 880)
        }
        .navigationSplitViewStyle(.balanced)
        // IA v2: when currentTab changes (sidebar click via the
        // sidebarTabBinding, welcome tile via onPick, or a Spotlight
        // deep-link), sync the section to the tab's default subview.
        //
        // Phase 7.v3 (2026-05-23): NO auto-flip of
        // hasCompletedOnboarding here.  macOS state restoration /
        // SwiftUI auto-selection can fire .onChange with a tab value
        // during launch; we don't want that to silently dismiss the
        // splash.  Dismissal is now explicit — either via `pickTab`
        // (called by the welcome tile or the sidebarTabBinding) or
        // by the deep-link notification handlers below.
        .onChange(of: currentTab) { newTab in
            guard let newTab else { return }
            section = LifecycleTabMapping.defaultSubview(for: newTab)
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
            // Spotlight deep-link to a Sovereignty bundle: dismiss
            // any active splash explicitly (Phase 7.v3 — splash gate
            // is now hasCompletedOnboarding, not currentTab), then
            // route to the Sovereignty subview.
            if !vm.hasCompletedOnboarding {
                vm.hasCompletedOnboarding = true
            }
            section = .sovereignty
            if let parent = LifecycleTabMapping.parent(of: .sovereignty) {
                currentTab = parent
            }
            vm.sovereigntyFocusedBundleID = note.userInfo?["bundleID"] as? String
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowTrust)) { note in
            if !vm.hasCompletedOnboarding {
                vm.hasCompletedOnboarding = true
            }
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

    /// Phase 7.v3 (2026-05-23): the sidebar's selection binding.
    /// During the welcome splash (!hasCompletedOnboarding) it
    /// always reads `nil` so no row is highlighted, regardless of
    /// what `currentTab` carries underneath (which macOS state
    /// restoration likes to set to whatever was selected last
    /// session).  The setter routes through `pickTab(_:)`, which is
    /// the single dismissal path that flips `hasCompletedOnboarding`.
    private var sidebarTabBinding: Binding<LifecycleTab?> {
        Binding(
            get: {
                vm.hasCompletedOnboarding ? currentTab : nil
            },
            set: { newValue in
                if let newValue {
                    pickTab(newValue)
                } else {
                    currentTab = nil
                }
            }
        )
    }

    /// The single "user picked a tab" entry point.  Called by the
    /// welcome tiles and by the sidebar's setter when the user
    /// clicks a row.  Flips `hasCompletedOnboarding` so the splash
    /// dismisses on next render, sets `currentTab` so the chosen
    /// tab becomes active, and loads its default subview.
    private func pickTab(_ tab: LifecycleTab) {
        currentTab = tab
        section = LifecycleTabMapping.defaultSubview(for: tab)
        if !vm.hasCompletedOnboarding {
            vm.hasCompletedOnboarding = true
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
