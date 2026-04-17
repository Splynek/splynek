import Foundation
import AppKit
import ServiceManagement

/// Background-first preferences: hide the dock icon (menu-bar-only mode)
/// and launch at login. Both are user-toggleable and persisted to
/// UserDefaults; `apply()` reconciles the live app state against the
/// saved preferences on launch + on every toggle.
///
/// Design choices:
///   - `NSApp.setActivationPolicy(.accessory)` is the runtime twin of
///     `LSUIElement=YES` in Info.plist. We use the runtime path so
///     users can switch on/off without relaunching.
///   - `SMAppService.mainApp` (macOS 13+) is the modern login-item
///     API, replacing the deprecated `SMLoginItemSetEnabled`. It
///     fails gracefully for ad-hoc-signed builds; we report status
///     back to the UI instead of raising.
///   - Before hiding the dock icon we make sure at least one window
///     is either open or reachable by the menu bar / popover — users
///     who toggle into background mode with no window visible would
///     otherwise find themselves unable to surface the app.
@MainActor
final class BackgroundModeController: ObservableObject {

    /// True when the app runs in menu-bar-only mode (no dock icon,
    /// `NSApp.activationPolicy == .accessory`). Toggled from the UI;
    /// persisted so the choice survives relaunch.
    @Published var menuBarOnly: Bool {
        didSet {
            UserDefaults.standard.set(menuBarOnly, forKey: "menuBarOnly")
            applyActivationPolicy()
        }
    }

    /// Current SMAppService status for the main-app login item, mirrored
    /// to the UI. `.enabled` = registered and allowed by the user.
    @Published private(set) var loginItemStatus: LoginItemStatus = .unknown

    enum LoginItemStatus: Equatable {
        case enabled
        case disabled
        case requiresApproval
        case unavailable(String)   // ad-hoc build / API call failed
        case unknown
    }

    init() {
        self.menuBarOnly = UserDefaults.standard.bool(forKey: "menuBarOnly")
        refreshLoginItemStatus()
    }

    /// Call on launch (after the first window has a chance to appear).
    /// Idempotent — safe to call as often as you like.
    func apply() {
        applyActivationPolicy()
        refreshLoginItemStatus()
    }

    private func applyActivationPolicy() {
        let target: NSApplication.ActivationPolicy = menuBarOnly ? .accessory : .regular
        if NSApp.activationPolicy() != target {
            NSApp.setActivationPolicy(target)
        }
        // When switching INTO background mode, hide every visible window
        // so the user's next interaction is via the menu bar. The main
        // window's restore state is preserved so reshowing it later
        // lands in the same place.
        if menuBarOnly {
            for w in NSApp.windows where w.isVisible {
                w.orderOut(nil)
            }
        } else {
            // Switching OUT of background mode: bring the main window up
            // so the user has an obvious signal the toggle took effect.
            NSApp.activate(ignoringOtherApps: true)
            (NSApp.windows.first { $0.canBecomeMain })?.makeKeyAndOrderFront(nil)
        }
    }

    // MARK: Login item

    func setLoginItemEnabled(_ enabled: Bool) {
        guard #available(macOS 13.0, *) else {
            loginItemStatus = .unavailable("Requires macOS 13+.")
            return
        }
        let service = SMAppService.mainApp
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
            refreshLoginItemStatus()
        } catch {
            loginItemStatus = .unavailable(error.localizedDescription)
        }
    }

    func refreshLoginItemStatus() {
        guard #available(macOS 13.0, *) else {
            loginItemStatus = .unavailable("Requires macOS 13+.")
            return
        }
        let s = SMAppService.mainApp.status
        switch s {
        case .enabled:            loginItemStatus = .enabled
        case .notRegistered:      loginItemStatus = .disabled
        case .notFound:           loginItemStatus = .unavailable("App not found in expected path.")
        case .requiresApproval:   loginItemStatus = .requiresApproval
        @unknown default:         loginItemStatus = .unknown
        }
    }

    /// Convenience: the UI renders a simple Bool toggle and binds to this.
    /// Writing `true` registers, writing `false` unregisters; reading
    /// returns `.enabled` iff the user hasn't revoked in System Settings.
    var loginItemEnabled: Bool {
        get { loginItemStatus == .enabled }
        set { setLoginItemEnabled(newValue) }
    }
}
