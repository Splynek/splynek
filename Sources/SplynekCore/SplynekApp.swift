import SwiftUI
import AppKit

extension Notification.Name {
    /// Broadcast by the ⌘L command; DownloadView's URL field listens and
    /// grabs focus.
    static let splynekFocusURL = Notification.Name("splynek.focusURL")
}

@MainActor
final class AppState: ObservableObject {
    let vm = SplynekViewModel()
    let background = BackgroundModeController()
    let ui: AppUIState

    init() {
        // Phase 7.v9 (2026-05-23): first-run users see the welcome
        // splash with no sidebar selection — currentTab starts nil.
        // Returning users default to Download (Queue) so a daily
        // "what's downloading right now?" launch doesn't reroute.
        let initial: LifecycleTab? = vm.hasCompletedOnboarding ? .download : nil
        ui = AppUIState(initialTab: initial)
    }
}

@MainActor
final class SplynekAppDelegate: NSObject, NSApplicationDelegate {
    var menuBar: MenuBarController?
    /// Phase 7.v9 (2026-05-23): AppState is now OWNED by the delegate,
    /// not bridged in via SwiftUI's @StateObject.  Reason: the main
    /// window is now created in `applicationDidFinishLaunching`
    /// (so we can use an NSWindow with `fullSizeContentView` +
    /// `MainSplitViewController` as contentViewController), which
    /// runs BEFORE any SwiftUI scene's body — there's no
    /// `@StateObject` to read at that point.  Strong reference,
    /// lifetime = process lifetime.
    let state = AppState()
    /// The main window's controller.  Strong reference here keeps
    /// the controller and its window alive for the process lifetime
    /// (the window has `isReleasedWhenClosed = false` so a close
    /// just hides it; clicking the dock icon re-opens via
    /// `applicationShouldHandleReopen`).
    var mainWindowController: MainWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase 7.v9 (2026-05-23): the main window is created here in
        // pure AppKit (MainWindowController) so we can use
        // NSSplitViewController + `NSSplitViewItem.allowsFullHeightLayout`
        // for the Apple-TV-style chrome.  See MainSplitViewController.swift.
        let mainController = MainWindowController(
            vm: state.vm,
            ui: state.ui,
            background: state.background
        )
        mainController.window?.makeKeyAndOrderFront(nil)
        mainWindowController = mainController

        let menu = MenuBarController { [weak self] in
            guard let vm = self?.state.vm else { return (0, 0, 0, 0) }
            let bps = vm.aggregateThroughputBps
            let active = vm.activeJobs.filter { $0.lifecycle == .running }.count
                + (vm.isTorrenting ? 1 : 0)
            let seedingPeers = vm.torrentProgress.seeding?.connectedPeers ?? 0
            return (bps, active, seedingPeers, vm.aggregateFraction)
        }
        // Popover / drag-drop ingestion on the menu bar item — same
        // path the Drop handler on the main window uses.
        menu.onIngest = { [weak self] raw in
            guard let vm = self?.state.vm else { return }
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("magnet:") {
                vm.magnetText = trimmed
                vm.parseMagnet()
            } else if let url = URL(string: trimmed),
                      url.scheme?.lowercased().hasPrefix("http") == true {
                vm.urlText = trimmed
                vm.start()
            }
        }
        menu.onCancelAll = { [weak self] in self?.state.vm.cancelAll() }
        menuBar = menu
        // Global ⌘⇧D — bring main window forward (and surface the dock
        // icon if we're in menu-bar-only mode).
        GlobalHotkey.shared.install { [weak self] in
            self?.showMainWindow()
        }
        // Restore any in-flight jobs the previous session was carrying.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.state.vm.restoreSession()
            // Apply background-mode preferences AFTER session restore so
            // any window brought up during restore can be ordered out.
            self?.state.background.apply()
            // 2026-05-08: warm the Apps-row badge so the user sees an
            // accurate "↑ N" count without ever opening the Updates
            // tab.  Fires ~3 s after launch (1.5 s after restore) so
            // the boot path stays fast — the network fan-out happens
            // off the main thread via UpdateSweep.run.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.state.vm.warmUpdateCount()
        }
    }

    /// Re-open the main window when the user clicks the dock icon
    /// (which doesn't fire `applicationDidFinishLaunching`).  The
    /// window is kept around (`isReleasedWhenClosed = false`) so
    /// this just orders it back to the front.
    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows: Bool
    ) -> Bool {
        if !hasVisibleWindows {
            showMainWindow()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist any non-terminal jobs so they come back on relaunch.
        Task { @MainActor [weak self] in
            self?.state.vm.saveSession()
        }
        // Take a short moment for the save to flush.
        Thread.sleep(forTimeInterval: 0.1)
    }

    /// File → Open Recent / Finder double-click / dock drop routes here.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        let vm = state.vm
        Task { @MainActor in
            for path in filenames {
                let url = URL(fileURLWithPath: path)
                _ = vm.handleDrop(providers: [NSItemProvider(object: url as NSURL)])
            }
            sender.reply(toOpenOrPrint: .success)
        }
    }

    /// Handle `splynek://download?url=<encoded>&sha256=<hex>&start=1`
    /// invocations. Registered as scheme owner via Info.plist.
    func application(_ application: NSApplication, open urls: [URL]) {
        let vm = state.vm
        Task { @MainActor in
            for url in urls {
                guard url.scheme?.lowercased() == "splynek" else {
                    // Might be a file URL (e.g. Finder double-click on .torrent);
                    // fall through to the drop handler.
                    _ = vm.handleDrop(providers: [NSItemProvider(object: url as NSURL)])
                    continue
                }
                handleSplynekURL(url, vm: vm)
            }
            self.showMainWindow()
        }
    }

    @MainActor
    private func handleSplynekURL(_ url: URL, vm: SplynekViewModel) {
        // Action is encoded as the URL "host" (or first path component) —
        // `splynek://download?url=…`.
        let action = url.host?.lowercased()
            ?? url.pathComponents.dropFirst().first?.lowercased()
            ?? ""
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?
            .queryItems ?? []
        let params = Dictionary(uniqueKeysWithValues: items.compactMap { qi -> (String, String)? in
            guard let v = qi.value else { return nil }
            return (qi.name, v)
        })

        switch action {
        case "download":
            if let target = params["url"] {
                vm.urlText = target
                if let hash = params["sha256"], !hash.isEmpty {
                    vm.sha256Expected = hash
                }
                if params["start"] == "1" {
                    vm.start()
                }
            }
        case "queue":
            if let target = params["url"] {
                vm.urlText = target
                if let hash = params["sha256"], !hash.isEmpty {
                    vm.sha256Expected = hash
                }
                vm.addCurrentToQueue()
            }
        case "torrent":
            if let magnet = params["magnet"] {
                vm.magnetText = magnet
                vm.parseMagnet()
            }
        case "sovereignty":
            // v1.6: Spotlight deep link.  URL shape is
            // `splynek://sovereignty/<bundle-id>` — bundle ID sits in
            // the first path component (URL host == "sovereignty").
            // Route to the Sovereignty tab via the same notification
            // pattern menu items use, carrying the focused bundle ID
            // in `userInfo`.  TrustView/SovereigntyView decide what
            // "focused" means (auto-scroll-to + auto-expand on the
            // current implementation; could become highlight in v1.7).
            let bid = url.pathComponents.dropFirst().first ?? ""
            NotificationCenter.default.post(
                name: .splynekShowSovereignty,
                object: nil,
                userInfo: bid.isEmpty ? [:] : ["bundleID": bid]
            )
        case "trust":
            let bid = url.pathComponents.dropFirst().first ?? ""
            NotificationCenter.default.post(
                name: .splynekShowTrust,
                object: nil,
                userInfo: bid.isEmpty ? [:] : ["bundleID": bid]
            )
        default:
            break
        }
    }

    /// Phase 7.v5: configure a window for the edge-to-edge splash
    /// look — transparent title bar + full-size content view so any
    /// SwiftUI view's background paints all the way under the
    /// traffic-light strip.  Idempotent; safe to call on every
    /// becomeKey notification.  We do NOT touch `window.toolbar` —
    /// the toolbar is what hosts the sidebar toggle button and the
    /// per-tab toolbar items; removing it broke the NavigationSplitView
    /// in Phase 7.v6 (sidebar disappeared).  On macOS 14+ we get the
    /// proper API for hiding the toolbar's bottom separator; on
    /// Dock menu (right-click / long-press on the Dock icon).
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(makeItem("Show Splynek", selector: #selector(showMainWindow)))
        menu.addItem(.separator())
        let vm = state.vm
        let running = vm.activeJobs.filter { $0.lifecycle == .running }
        if running.isEmpty {
            let idle = NSMenuItem(title: "No active downloads", action: nil, keyEquivalent: "")
            idle.isEnabled = false
            menu.addItem(idle)
        } else {
            for job in running {
                let name = job.outputURL.lastPathComponent
                let pct = Int(job.progress.fraction * 100)
                let item = NSMenuItem(title: "\(name) — \(pct)%", action: nil, keyEquivalent: "")
                item.isEnabled = false
                menu.addItem(item)
            }
        }
        if vm.isRunning {
            menu.addItem(.separator())
            menu.addItem(makeItem("Cancel All", selector: #selector(cancelAll)))
        }
        if vm.activeJobs.contains(where: { $0.lifecycle == .paused }) {
            menu.addItem(makeItem("Resume All", selector: #selector(resumeAll)))
        }
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Splynek",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: ""))
        return menu
    }

    // MARK: Actions

    @objc private func showMainWindow() {
        // Bring the dock icon back if we've been running headless, so
        // the `activate` call actually focuses us. The user can toggle
        // back into menu-bar-only from Preferences.
        if NSApp.activationPolicy() == .accessory {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
        mainWindowController?.window?.makeKeyAndOrderFront(nil)
    }

    @objc private func cancelAll() {
        Task { @MainActor in self.state.vm.cancelAll() }
    }

    @objc private func resumeAll() {
        Task { @MainActor in
            let vm = self.state.vm
            for job in vm.activeJobs where job.lifecycle == .paused {
                vm.resumeJob(job)
            }
        }
    }

    private func makeItem(_ title: String, selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }
}

public struct SplynekApp: App {
    public init() {}

    @NSApplicationDelegateAdaptor(SplynekAppDelegate.self) var delegate

    public var body: some Scene {
        // Phase 7.v9 (2026-05-23): the main window is NOT defined by
        // a SwiftUI `WindowGroup` anymore — `SplynekAppDelegate`
        // creates an AppKit-driven `NSWindow` + `MainSplitViewController`
        // so we can use `NSSplitViewItem.allowsFullHeightLayout = true`
        // for the Apple-TV-style chrome (sidebar material + detail
        // gradient extend under the title bar; SwiftUI's
        // NavigationSplitView doesn't expose this).
        //
        // We keep a `Settings` scene as the home of `.commands`
        // because SwiftUI menu bar items are global — they apply to
        // whatever window happens to be key — and need *some* scene
        // to attach to.  The Settings window itself never appears
        // because the user reaches Settings via our custom in-app
        // sheet (`SettingsSheet`).
        Settings { EmptyView() }
        .commands {
            CommandGroup(replacing: .newItem) { }

            // v0.49: Settings / Legal / About moved OUT of the
            // sidebar (user feedback: clutter) and INTO the macOS
            // menu bar where Mac apps traditionally live. Standard
            // Apple-menu slots are used where they exist:
            //   Apple menu → About Splynek   → replaces .appInfo
            //   Apple menu → Settings… (⌘,)  → replaces .appSettings
            //   Help menu  → Legal…          → new command under .help
            // Each posts a Notification that RootView catches and
            // routes to the still-valid SidebarSection destination.
            CommandGroup(replacing: .appInfo) {
                Button("About Splynek") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    NotificationCenter.default.post(name: .splynekShowAbout, object: nil)
                }
            }
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    NotificationCenter.default.post(name: .splynekShowSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
            CommandGroup(after: .help) {
                Button("Legal…") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    NotificationCenter.default.post(name: .splynekShowLegal, object: nil)
                }
            }

            CommandGroup(after: .toolbar) {
                Button("Show Splynek") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                }
                .keyboardShortcut("d", modifiers: [.command, .shift])
                Button("Focus URL") {
                    NSApp.activate(ignoringOtherApps: true)
                    NSApp.windows.first?.makeKeyAndOrderFront(nil)
                    NotificationCenter.default.post(name: .splynekFocusURL, object: nil)
                }
                .keyboardShortcut("l", modifiers: .command)
            }
            CommandMenu("Tools") {
                Button("Publish Splynek Manifest…") {
                    if let vm = (NSApp.delegate as? SplynekAppDelegate)?.state.vm {
                        vm.publishManifest()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
