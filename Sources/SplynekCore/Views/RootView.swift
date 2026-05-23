import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject private var torrent: TorrentProgress
    /// IA v2 (2026-05-13): the active LifecycleTab — set by the
    /// sidebar, drives the chip strip in the detail column.
    @State private var currentTab: LifecycleTab = .download
    /// The active subview within the current tab.  Set by either the
    /// chip strip (LifecycleTopBar) or by deep-link notifications
    /// from the menu bar / splynek:// URL handlers.
    @State private var section: SidebarSection = .queue

    @MainActor
    init(vm: SplynekViewModel) {
        self.vm = vm
        _torrent = ObservedObject(wrappedValue: vm.torrentProgress)
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(currentTab: $currentTab, vm: vm, torrent: torrent)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            VStack(spacing: 0) {
                // IA v2: chip strip for subview switching.  Renders
                // only when the current subview's parent tab matches
                // currentTab — hides itself when the user is on a
                // Settings/Legal/About route (those have no tab
                // parent and live in a sheet long-term).
                if LifecycleTabMapping.parent(of: section) == currentTab {
                    LifecycleTopBar(
                        currentTab: currentTab,
                        section: $section,
                        accessory: { _ in nil }
                    )
                }
                detail
            }
            .navigationSplitViewColumnWidth(min: 640, ideal: 880)
        }
        .navigationSplitViewStyle(.balanced)
        // IA v2: when the user clicks a sidebar tab, drop into the
        // tab's default subview.  Without this the chip strip would
        // light up an arbitrary subview based on prior state.
        // Older single-closure form for macOS 13 compatibility.
        // The two-closure form `.onChange(of:initial:_:)` is 14+.
        .onChange(of: currentTab) { newTab in
            section = LifecycleTabMapping.defaultSubview(for: newTab)
        }
        .task { await vm.refreshInterfaces() }
        // v1.6.1: first-launch onboarding sheet.  Auto-presents when
        // the persisted flag is false; user dismisses (Skip / Finish)
        // and the flag flips so it never reappears.  Bound to a
        // computed Binding so dismiss-by-X-button still flips the
        // flag (otherwise the sheet would re-present on next launch).
        .sheet(isPresented: Binding(
            get: { !vm.hasCompletedOnboarding },
            set: { newValue in
                if !newValue { vm.hasCompletedOnboarding = true }
            }
        )) {
            OnboardingSheet(vm: vm)
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
        // v0.49: menu-bar → sidebar-routing. Apple menu → Settings…
        // (⌘,) / About, Help menu → Legal… — each posts one of
        // these notifications; here we route to the matching
        // SidebarSection destination. Uses the splash route so
        // users see the panels exactly like they would from the
        // sidebar (no separate windows).
        // IA v2: notification routing also updates currentTab via
        // LifecycleTabMapping.parent so the sidebar highlight
        // follows the deep link.  Settings / Legal / About have no
        // tab parent (nil) — they leave currentTab unchanged so the
        // sidebar stays on whatever tab the user was on.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSettings)) { _ in
            section = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowLegal)) { _ in
            section = .legal
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowAbout)) { _ in
            section = .about
        }
        // v1.6: Spotlight deep-link routing.  Activating a Sovereignty
        // or Trust hit from the system search bar fires the matching
        // `splynek://<tab>/<bundle-id>` URL, which posts these
        // notifications.  Update both section + currentTab so the
        // chip strip + sidebar both follow.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSovereignty)) { note in
            section = .sovereignty
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
