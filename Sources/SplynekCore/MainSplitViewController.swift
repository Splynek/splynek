// Copyright © 2026 Splynek. MIT.
//
// MainSplitViewController + MainWindowController + SidebarRoot +
// DetailRoot — Phase 7.v9 (2026-05-23).
//
// Replaces the SwiftUI `RootView` + `NavigationSplitView` stack with
// an AppKit-driven main window so we can opt the split-view columns
// into `NSSplitViewItem.allowsFullHeightLayout = true` — the AppKit
// property that lets each column's content extend under the title-
// bar strip.  SwiftUI's `NavigationSplitView` does not expose this
// property; my previous `NSViewControllerRepresentable` bridge
// failed because it buried the split-view controller inside SwiftUI's
// content hosting controller, which is one level removed from the
// window's title-bar geometry.  The split VC needs to BE the window's
// `contentViewController` for `allowsFullHeightLayout` to take effect.
//
// What stays in SwiftUI:
//   • The two column views (`SidebarRoot`, `DetailRoot`) and
//     everything inside them — the welcome splash, all per-tab
//     views, sheets, alerts, notifications — are pure SwiftUI hosted
//     via `NSHostingController`.
//   • The `.commands` menu items remain on the SwiftUI `Settings`
//     scene in `SplynekApp` (SwiftUI menus are global, not per-window).
//   • State is shared between the two columns via two
//     `ObservableObject`s: `SplynekViewModel` (the existing
//     application model) and `AppUIState` (new — tab + section +
//     sheet routes).
//
// What moves to AppKit:
//   • `NSWindow` creation (`MainWindowController`) — gives us
//     `fullSizeContentView` + `titlebarAppearsTransparent` +
//     `titlebarSeparatorStyle = .none` (macOS 14+) for clean chrome.
//   • `NSSplitViewController` (`MainSplitViewController`) — owns
//     the two split-view items and listens for
//     `.splynekToggleSidebar` notifications to animate
//     `isCollapsed`.
//
// Result: Apple-TV-style chrome.  The sidebar's `.regularMaterial`
// and the detail's gradient both extend from the very top of the
// window to the very bottom.  Traffic lights float visually inside
// the sidebar's pane (because the sidebar item's content layer
// reaches all the way up).  No system band, no toolbar seam.

import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Notification

public extension Notification.Name {
    /// Posted by the sidebar's custom toggle button (which replaces
    /// the macOS toolbar's built-in sidebar toggle — we don't have
    /// an NSToolbar anymore).  Observed by `MainSplitViewController`
    /// to animate the sidebar item's `isCollapsed`.
    static let splynekToggleSidebar = Notification.Name("splynek.toggleSidebar")
}

// MARK: - MainWindowController

@MainActor
final class MainWindowController: NSWindowController {

    convenience init(
        vm: SplynekViewModel,
        ui: AppUIState,
        background: BackgroundModeController
    ) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1200, height: 880),
            styleMask: [
                .titled, .closable, .miniaturizable, .resizable,
                .fullSizeContentView
            ],
            backing: .buffered,
            defer: false
        )
        window.title = "Splynek"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = false
        window.minSize = NSSize(width: 900, height: 640)
        window.isReleasedWhenClosed = false
        window.setFrameAutosaveName("SplynekMainWindow")
        if #available(macOS 14.0, *) {
            window.titlebarSeparatorStyle = .none
        }

        let split = MainSplitViewController(
            vm: vm, ui: ui, background: background
        )
        window.contentViewController = split

        // Centre on first launch.  `setFrameUsingName` returns false
        // when there's no saved frame yet.
        if !window.setFrameUsingName("SplynekMainWindow") {
            window.center()
        }

        self.init(window: window)
    }
}

// MARK: - MainSplitViewController

@MainActor
final class MainSplitViewController: NSSplitViewController {
    let vm: SplynekViewModel
    let ui: AppUIState
    let background: BackgroundModeController

    private var toggleObserver: NSObjectProtocol?

    init(
        vm: SplynekViewModel,
        ui: AppUIState,
        background: BackgroundModeController
    ) {
        self.vm = vm
        self.ui = ui
        self.background = background
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used — the view is built in code.")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        splitView.dividerStyle = .thin

        installSidebarColumn()
        installDetailColumn()
        installToggleObserver()
    }

    deinit {
        if let toggleObserver {
            NotificationCenter.default.removeObserver(toggleObserver)
        }
    }

    // MARK: - Columns

    private func installSidebarColumn() {
        // Three layers have to agree before SwiftUI content can sit
        // at the absolute top of the window, where the traffic-light
        // strip is:
        //
        //   1. NSWindow.fullSizeContentView (set in MainWindowController) —
        //      lets the window's content view extend under the title bar.
        //   2. NSSplitViewItem.allowsFullHeightLayout (set below) —
        //      tells the split-view item it can extend its layout into
        //      that title-bar area.
        //   3. NSHostingController.safeAreaRegions = [] (set below) —
        //      tells the SwiftUI hosting controller NOT to subtract the
        //      title-bar height from the safe area it hands to its
        //      root SwiftUI view.  Without this, the SwiftUI tree
        //      sees a top safe-area inset and lays out as if the title
        //      bar were a separate region — which is what was leaving
        //      a ~140 pt empty band above the first sidebar tile.
        //
        // On macOS 13.0 / 13.1 / 13.2 (before `safeAreaRegions`
        // existed), we fall back to the `.ignoresSafeArea` modifier
        // on the root view — less reliable but better than nothing.
        let root = SidebarRoot(
            vm: vm, ui: ui, torrent: vm.torrentProgress
        )
        .environmentObject(background)
        .ignoresSafeArea(.all, edges: .top)

        let host = NSHostingController(rootView: root)
        if #available(macOS 13.3, *) {
            host.safeAreaRegions = []
        }

        // We use the REGULAR init (not `sidebarWithViewController:`)
        // because the sidebar-specific item enforces internal content
        // insets that override `allowsFullHeightLayout` — a 70-80 pt
        // top inset was being kept regardless of safe-area handling,
        // pushing the first SwiftUI row below the title-bar y.  The
        // sidebar's `.regularMaterial` background (set in Sidebar.swift)
        // gives the visible "sidebar look" without that magic inset.
        let item = NSSplitViewItem(viewController: host)
        item.minimumThickness = 220
        item.maximumThickness = 320
        item.canCollapse = true
        item.holdingPriority = NSLayoutConstraint.Priority(rawValue: 260)
        item.allowsFullHeightLayout = true
        if #available(macOS 14.0, *) {
            item.titlebarSeparatorStyle = .none
        }
        addSplitViewItem(item)
    }

    private func installDetailColumn() {
        let root = DetailRoot(
            vm: vm, ui: ui, torrent: vm.torrentProgress
        )
        .environmentObject(background)
        .ignoresSafeArea(.all, edges: .top)

        let host = NSHostingController(rootView: root)
        if #available(macOS 13.3, *) {
            host.safeAreaRegions = []
        }

        let item = NSSplitViewItem(viewController: host)
        item.allowsFullHeightLayout = true
        if #available(macOS 14.0, *) {
            item.titlebarSeparatorStyle = .none
        }
        addSplitViewItem(item)
    }

    // MARK: - Sidebar toggle

    private func installToggleObserver() {
        toggleObserver = NotificationCenter.default.addObserver(
            forName: .splynekToggleSidebar,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let item = self?.splitViewItems.first else { return }
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.20
                ctx.allowsImplicitAnimation = true
                item.animator().isCollapsed.toggle()
            }
        }
    }
}

// MARK: - SwiftUI: SidebarRoot

/// SwiftUI root for the sidebar column.  Wraps the existing
/// `Sidebar` view + binds it to the shared `AppUIState`.
struct SidebarRoot: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var ui: AppUIState
    @ObservedObject var torrent: TorrentProgress

    var body: some View {
        Sidebar(
            currentTab: sidebarTabBinding,
            vm: vm, torrent: torrent
        )
    }

    /// During the first-run welcome splash (!hasCompletedOnboarding)
    /// the binding ALWAYS reads `nil` so no sidebar row is
    /// highlighted, regardless of what `ui.currentTab` carries
    /// underneath.  Writes route through `pickTab(_:)` — the single
    /// dismissal path that flips `hasCompletedOnboarding`.
    private var sidebarTabBinding: Binding<LifecycleTab?> {
        Binding(
            get: { vm.hasCompletedOnboarding ? ui.currentTab : nil },
            set: { newValue in
                if let newValue {
                    pickTab(newValue)
                }
            }
        )
    }

    private func pickTab(_ tab: LifecycleTab) {
        ui.currentTab = tab
        ui.section = LifecycleTabMapping.defaultSubview(for: tab)
        if !vm.hasCompletedOnboarding {
            vm.hasCompletedOnboarding = true
        }
    }
}

// MARK: - SwiftUI: DetailRoot

/// SwiftUI root for the detail column.  Hosts the welcome splash
/// (when `!hasCompletedOnboarding`) or the chip strip + per-section
/// view (when in the app proper).  All sheets, alerts, notifications
/// and the drop-receiver moved here from the retired `RootView`.
struct DetailRoot: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject var ui: AppUIState
    @ObservedObject var torrent: TorrentProgress

    var body: some View {
        VStack(spacing: 0) {
            if !vm.hasCompletedOnboarding {
                DiscoverWelcomeCard(
                    vm: vm,
                    onPick: { tab in pickTab(tab) }
                )
            } else if let tab = ui.currentTab {
                if LifecycleTabMapping.parent(of: ui.section) == tab {
                    LifecycleTopBar(
                        currentTab: tab,
                        section: $ui.section,
                        accessory: { _ in nil },
                        trailing: askSplynekTrailing(for:)
                    )
                }
                detail
            }
        }
        // Sheets.
        .sheet(isPresented: $ui.showingConcierge) {
            ConciergeSheetContainer(vm: vm)
        }
        .sheet(item: $ui.settingsRoute) { route in
            SettingsSheet(initialPane: route, vm: vm)
        }
        // Drag-drop.
        .onDrop(of: [.url, .fileURL, .plainText], isTargeted: nil) { providers in
            vm.handleDrop(providers: providers)
        }
        // Alerts.
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
        // Menu-bar / gear-icon → Settings sheet.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSettings)) { _ in
            ui.settingsRoute = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowLegal)) { _ in
            ui.settingsRoute = .legal
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowAbout)) { _ in
            ui.settingsRoute = .about
        }
        // Spotlight deep links — implicitly dismiss the welcome splash
        // by flipping hasCompletedOnboarding if it's still false.
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSovereignty)) { note in
            if !vm.hasCompletedOnboarding {
                vm.hasCompletedOnboarding = true
            }
            ui.section = .sovereignty
            if let parent = LifecycleTabMapping.parent(of: .sovereignty) {
                ui.currentTab = parent
            }
            vm.sovereigntyFocusedBundleID = note.userInfo?["bundleID"] as? String
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowTrust)) { note in
            if !vm.hasCompletedOnboarding {
                vm.hasCompletedOnboarding = true
            }
            ui.section = .trust
            if let parent = LifecycleTabMapping.parent(of: .trust) {
                ui.currentTab = parent
            }
            vm.trustFocusedBundleID = note.userInfo?["bundleID"] as? String
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowConcierge)) { _ in
            ui.showingConcierge = true
        }
        .task { await vm.refreshInterfaces() }
    }

    // MARK: - Per-section content

    @ViewBuilder
    private var detail: some View {
        switch ui.section {
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

    // MARK: - Helpers

    private func pickTab(_ tab: LifecycleTab) {
        ui.currentTab = tab
        ui.section = LifecycleTabMapping.defaultSubview(for: tab)
        if !vm.hasCompletedOnboarding {
            vm.hasCompletedOnboarding = true
        }
    }

    /// Trailing-accessory builder for `LifecycleTopBar`.  Discover +
    /// My Apps get the "Ask Splynek" pill; the others get nil.
    private func askSplynekTrailing(for tab: LifecycleTab) -> AnyView? {
        switch tab {
        case .discover, .myApps:
            return AnyView(AskSplynekPill())
        case .download, .coordinate:
            return nil
        }
    }
}
