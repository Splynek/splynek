import Foundation
import SwiftUI
import Sparkle

/// 2026-06 direct-sale launch (LAUNCH-WITHOUT-APPLE.md § 6).
///
/// Wires Sparkle 2.x into Splynek's SwiftUI lifecycle.  Auto-update
/// fetches `SUFeedURL` (configured in Resources/Info.plist) on a
/// schedule the user controls; if a newer notarized DMG ships from
/// splynek.app, Sparkle prompts, downloads, validates the EdDSA
/// signature against `SUPublicEDKey` (also in Info.plist), and
/// installs in-place on relaunch.
///
/// Why a bridge object instead of inlining into SplynekApp:
/// - Keeps the SwiftUI App declaration clean.
/// - Centralises the SPUUpdaterDelegate methods (we'll add them when
///   we need them — e.g. to log update activity to the in-app
///   Settings → About pane).
/// - Lets the MAS build path NOT compile this file via Xcode target
///   exclusion (MAS uses Apple's auto-update — no Sparkle bundled).
///
/// **Maintainer prerequisites before this works:**
///   1. SUFeedURL in Resources/Info.plist points to the live appcast
///      (e.g. https://splynek.app/appcast.xml).
///   2. SUPublicEDKey in Resources/Info.plist holds Sparkle's EdDSA
///      public key (NOT the licence-server Ed25519 key — Sparkle has
///      its own separate signing).  Generated with `sign_update` from
///      the Sparkle dev tools.
///   3. Each shipped DMG has a matching `<sparkle:edSignature>`
///      entry in appcast.xml computed via `sign_update build/Splynek.dmg`.
///
/// Without any of these, Sparkle silently no-ops and the user sees no
/// update prompts.  That's the safe fail mode.
@MainActor
final class SparkleBridge {

    /// Singleton — Sparkle's updater is process-wide; one is enough.
    static let shared = SparkleBridge()

    /// The standard Sparkle controller.  Reads SUFeedURL +
    /// SUPublicEDKey from the main bundle's Info.plist on init.
    /// `startingUpdater: true` kicks off the auto-check timer.
    ///
    /// v1.0 ships with no custom updaterDelegate / userDriverDelegate
    /// — the Sparkle default UX (prompt before download, prompt
    /// before install-on-relaunch) is the right behaviour for a
    /// download manager.  v1.0.1 can add an SPUUpdaterDelegate
    /// subclass for finer hooks (suppress prompts during an active
    /// download, surface "last checked" in the About pane, etc.).
    let updaterController: SPUStandardUpdaterController

    private init() {
        self.updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    /// "Check for Updates…" menu item action.  Mirrors the standard
    /// macOS app convention.  Wired from the NSMenu hooks in
    /// SplynekApp.swift's applicationDidFinishLaunching path (see
    /// the `_ = SparkleBridge.shared` reference in main.swift).
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    /// Whether automatic update checks are enabled.  Used by
    /// Settings → About → "Automatically check for updates" checkbox.
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
}
