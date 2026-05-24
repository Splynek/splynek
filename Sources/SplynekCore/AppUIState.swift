// Copyright © 2026 Splynek. MIT.
//
// AppUIState — Phase 7.v9 (2026-05-23).
//
// UI state shared between the sidebar and detail columns of the
// main window.  Previously these fields lived as `@State` on the
// old `RootView`; after the refactor to `MainSplitViewController`
// (an AppKit-driven NSSplitViewController), each column is hosted in
// its own NSHostingController and they communicate through this
// ObservableObject.
//
// Why ObservableObject (not @State + bindings everywhere): two
// SwiftUI trees in separate NSHostingController instances do not
// share `@State` automatically.  An ObservableObject is the
// idiomatic way to give them a shared, observable source of truth.

import SwiftUI

@MainActor
final class AppUIState: ObservableObject {
    /// Active lifecycle tab.  `nil` means the first-run welcome
    /// splash is showing — no sidebar row is highlighted, and the
    /// detail column renders `DiscoverWelcomeCard` instead of any
    /// tab's content.  Set non-nil when the user picks a tab from
    /// the welcome splash or clicks a sidebar row.
    @Published var currentTab: LifecycleTab?

    /// Active subview within the current tab.  Drives the chip strip
    /// in `LifecycleTopBar` and the per-section `switch` in
    /// `DetailRoot`.  Set by the chip strip, by Spotlight deep
    /// links, or by `LifecycleTabMapping.defaultSubview(for:)` when
    /// the tab changes.
    @Published var section: SidebarSection = .queue

    /// Concierge sheet presentation flag.  Flipped true by the "Ask
    /// Splynek" pill (LifecycleTopBar) or by the
    /// `.splynekShowConcierge` notification; the `.sheet` modifier
    /// on `DetailRoot` observes this directly.
    @Published var showingConcierge: Bool = false

    /// Settings/Legal/About sheet route.  `nil` means no sheet.
    /// Set by the gear-icon footer + the three menu-bar
    /// notifications (`.splynekShowSettings` / `.showLegal` /
    /// `.showAbout`); `DetailRoot`'s `.sheet(item:)` modifier opens
    /// the requested pane.
    @Published var settingsRoute: SettingsRoute?

    init(initialTab: LifecycleTab? = .download) {
        self.currentTab = initialTab
    }
}
