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
}

final class SplynekAppDelegate: NSObject, NSApplicationDelegate {
    var menuBar: MenuBarController?
    weak var state: AppState?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Phase 7.v5 (2026-05-23): make every Splynek window's title
        // bar transparent + opt into full-size content view, so the
        // first-run welcome splash can flow edge-to-edge through the
        // title bar area instead of stopping at a visible seam.  The
        // traffic-light controls still render (no styleMask removal),
        // and normal tabs that declare their own .toolbar items get
        // the standard system treatment — the transparent title bar
        // just lets the view's background paint through.
        DispatchQueue.main.async {
            for window in NSApp.windows {
                Self.configureWindowChrome(window)
            }
            // Catch any windows created after launch (Pro upsell,
            // sheets, etc.) — they all inherit the same treatment.
            NotificationCenter.default.addObserver(
                forName: NSWindow.didBecomeKeyNotification,
                object: nil, queue: .main
            ) { note in
                if let window = note.object as? NSWindow {
                    Self.configureWindowChrome(window)
                }
            }
        }

        let menu = MenuBarController { [weak self] in
            guard let vm = self?.state?.vm else { return (0, 0, 0, 0) }
            let bps = vm.aggregateThroughputBps
            let active = vm.activeJobs.filter { $0.lifecycle == .running }.count
                + (vm.isTorrenting ? 1 : 0)
            let seedingPeers = vm.torrentProgress.seeding?.connectedPeers ?? 0
            return (bps, active, seedingPeers, vm.aggregateFraction)
        }
        // Popover / drag-drop ingestion on the menu bar item — same
        // path the Drop handler on the main window uses.
        menu.onIngest = { [weak self] raw in
            guard let vm = self?.state?.vm else { return }
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
        menu.onCancelAll = { [weak self] in self?.state?.vm.cancelAll() }
        menuBar = menu
        // Global ⌘⇧D — bring main window forward (and surface the dock
        // icon if we're in menu-bar-only mode).
        GlobalHotkey.shared.install { [weak self] in
            self?.showMainWindow()
        }
        // Restore any in-flight jobs the previous session was carrying.
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000)
            self?.state?.vm.restoreSession()
            // Apply background-mode preferences AFTER session restore so
            // any window brought up during restore can be ordered out.
            self?.state?.background.apply()
            // 2026-05-08: warm the Apps-row badge so the user sees an
            // accurate "↑ N" count without ever opening the Updates
            // tab.  Fires ~3 s after launch (1.5 s after restore) so
            // the boot path stays fast — the network fan-out happens
            // off the main thread via UpdateSweep.run.
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self?.state?.vm.warmUpdateCount()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Persist any non-terminal jobs so they come back on relaunch.
        Task { @MainActor [weak self] in
            self?.state?.vm.saveSession()
        }
        // Take a short moment for the save to flush.
        Thread.sleep(forTimeInterval: 0.1)
    }

    /// File → Open Recent / Finder double-click / dock drop routes here.
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let vm = state?.vm else { return }
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
        guard let vm = state?.vm else { return }
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
    /// becomeKey notification.
    static func configureWindowChrome(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.styleMask.insert(.fullSizeContentView)
        // Don't change titleVisibility — RootView's per-tab toolbars
        // still want to render their own titles when the splash is
        // dismissed.
    }

    /// Dock menu (right-click / long-press on the Dock icon).
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        let menu = NSMenu()
        menu.addItem(makeItem("Show Splynek", selector: #selector(showMainWindow)))
        menu.addItem(.separator())
        if let vm = state?.vm {
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
        (NSApp.windows.first { $0.canBecomeMain && !$0.isVisible } ?? NSApp.windows.first)?
            .makeKeyAndOrderFront(nil)
    }

    @objc private func cancelAll() {
        Task { @MainActor in self.state?.vm.cancelAll() }
    }

    @objc private func resumeAll() {
        Task { @MainActor in
            guard let vm = self.state?.vm else { return }
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
    @StateObject private var state = AppState()

    public var body: some Scene {
        WindowGroup {
            ContentView(vm: state.vm)
                .environmentObject(state.background)
                .onAppear { delegate.state = state }
                .frame(minWidth: 900, minHeight: 640)
        }
        // 2026-05-07 / 2026-05-23 (Phase 7.v5): defaultSize bumped
        // from the (implicit) minimum so first-launch users land on
        // a window tall enough to show every sidebar row + the
        // full first-run welcome splash (4 lifecycle tiles + hero
        // + trust strip) without clipping or scrolling.  The minimum
        // frame is still 900×640 — anyone who shrinks the window
        // keeps the Pro layout — but the *initial* frame is now
        // generous.
        .defaultSize(width: 1200, height: 880)
        .windowResizability(.contentSize)
        // Phase 7.v5 (2026-05-23): hiddenTitleBar — the title bar
        // becomes transparent, traffic lights stay in the top-left,
        // and any SwiftUI view's background paints continuously from
        // the very top of the window to the bottom.  Kills the seam
        // the welcome splash was showing between the toolbar area
        // and the gradient body.  unifiedCompact keeps per-tab
        // toolbars (Sovereignty, Trust, etc.) lean.
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
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
                    if let vm = (NSApp.delegate as? SplynekAppDelegate)?.state?.vm {
                        vm.publishManifest()
                    }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])
            }
        }
    }
}
