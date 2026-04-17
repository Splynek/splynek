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
        default:
            break
        }
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
        .windowResizability(.contentSize)
        .windowToolbarStyle(.unified(showsTitle: true))
        .commands {
            CommandGroup(replacing: .newItem) { }
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
