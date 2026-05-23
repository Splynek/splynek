// Copyright © 2026 Splynek. MIT.
//
// LifecycleTab — IA v2 (2026-05-13).  The four lifecycle tabs that
// replace the 17-case `SidebarSection` enum.
//
// Each tab represents a moment in the user's app-download lifecycle:
//
//   Discover    "What should I install?  Is this app safe?  Are
//                there better alternatives?"
//   Download    "Get this here, fast.  Survive bad Wi-Fi."
//   My Apps     "What's already on this Mac, and is it still OK?"
//   Coordinate  "Multi-device + external automation."
//
// See:
//   IA-PROPOSAL.md        — the rationale + the full mapping table
//   IA-WIREFRAMES.md      — the per-tab visual specs
//   docs/mocks/           — the clickable HTML prototype
//
// **Migration model.**  This is Phase 1 of the IA reorg.  Today's
// `SidebarSection` cases continue to exist; LifecycleTab is layered
// on top via `LifecycleTabMapping`.  Phase 2 (next commit) replaces
// the sidebar with a 4-row layout that displays the lifecycle tabs
// directly; the existing views become subviews of their lifecycle
// parents.  No view code moves in this commit.

import Foundation

/// The four lifecycle tabs.  Stable serialization via `rawValue`
/// (used by `splynek://` deep links + persisted UI state).
enum LifecycleTab: String, Hashable, CaseIterable, Identifiable, Sendable {
    case discover
    case download
    case myApps    = "my-apps"
    case coordinate

    var id: String { rawValue }

    /// Display label.  Matches the chip text in
    /// docs/mocks/.../discover.html etc.
    var title: String {
        switch self {
        case .discover:   return "Discover"
        case .download:   return "Download"
        case .myApps:     return "My Apps"
        case .coordinate: return "Coordinate"
        }
    }

    /// SF Symbol used in the sidebar.  Picked to read as a verb at
    /// 18px, not an abstract icon — sparkles for "help me decide",
    /// arrow.down for "fetching now", shippingbox for "what I have",
    /// laptop+iphone for "across devices".
    var systemImage: String {
        switch self {
        case .discover:   return "sparkles"
        case .download:   return "arrow.down.circle"
        case .myApps:     return "shippingbox"
        case .coordinate: return "laptopcomputer.and.iphone"
        }
    }

    /// One-line promise visible on the welcome card + the tab
    /// tooltip.  Same copy as IA-WIREFRAMES.md Section 4 (kept
    /// short — translation pass uses these as canonical English).
    var promise: String {
        switch self {
        case .discover:   return "Find apps worth installing"
        case .download:   return "Get them here, fast"
        case .myApps:     return "Keep what you have safe"
        case .coordinate: return "Sync across your devices"
        }
    }
}

// MARK: - Mapping

/// Routing table between the legacy `SidebarSection` 17 cases and
/// the 4 lifecycle tabs.  Used during Phase 2 view-shuffling; once
/// `SidebarSection` is fully retired this becomes the canonical
/// resolver for `splynek://<old-tab>` deep links so we never break
/// shortcuts in user installs.
enum LifecycleTabMapping {

    /// The lifecycle home for each existing sidebar section.
    /// `nil` means the section is moving to the gear-icon Settings
    /// sheet (settings, legal, about) and has no tab parent.
    ///
    /// Exhaustive switch — adding a new `SidebarSection` case
    /// without giving it a tab parent here is a compile-time error.
    static func parent(of section: SidebarSection) -> LifecycleTab? {
        switch section {

        // ── Discover ─────────────────────────────────────────────
        // Pre-install decision: alternatives, trust, recommendation,
        // curated stacks, savings motivation.
        case .sovereignty, .trust, .concierge, .recipes, .savings:
            return .discover

        // ── Download ─────────────────────────────────────────────
        // Active fetch: queue, live throughput, history, BitTorrent,
        // benchmarking.
        case .queue, .live, .downloads, .torrents, .benchmark, .history:
            return .download

        // ── My Apps ──────────────────────────────────────────────
        // Post-install care: installed inventory + updates (Apps view
        // already groups these).  Trust Watcher + Migrate surface
        // INSIDE this tab as new subviews — they're not their own
        // SidebarSection today.
        case .apps:
            return .myApps

        // ── Coordinate ───────────────────────────────────────────
        // Multi-device coordination + external automation.
        case .fleet, .agents:
            return .coordinate

        // ── Gear-icon sheet (not a tab) ──────────────────────────
        // Settings / Legal / About move from sidebar destinations
        // to a Settings sheet invoked from the sidebar gear icon
        // (Apple's macOS convention: Cmd+, opens preferences;
        // preferences aren't a tab).
        case .settings, .legal, .about:
            return nil
        }
    }

    /// When the user clicks a `LifecycleTab` in the sidebar, which
    /// of its child SidebarSections is the default content?  IA-
    /// PROPOSAL.md § "What each tab actually looks like" defines
    /// these.
    ///
    /// Phase 2 uses this to render the tab's initial subview; once
    /// the IA migration is complete, each tab will have its own
    /// subview enum + this mapping becomes legacy-routing only.
    static func defaultSubview(for tab: LifecycleTab) -> SidebarSection {
        switch tab {
        case .discover:   return .sovereignty   // Browse alternatives
        case .download:   return .queue         // Current main download view
        case .myApps:     return .apps          // Installed inventory
        case .coordinate: return .fleet         // This LAN
        }
    }

    /// All sibling subviews available within a given tab, ordered
    /// as they should appear in the chip strip (left to right).
    /// Used by the IA-v2 toolbar renderer in Phase 2.
    static func subviews(of tab: LifecycleTab) -> [SidebarSection] {
        // Single source of truth — derived from `parent(of:)` so
        // the two stay in sync automatically.  Order follows the
        // semantic priority documented in IA-PROPOSAL.md.
        switch tab {
        case .discover:
            return [.sovereignty, .trust, .recipes, .savings, .concierge]
        case .download:
            return [.queue, .live, .downloads, .torrents, .history, .benchmark]
        case .myApps:
            return [.apps]
            // Trust Watcher + Migrate land here as new chips in Phase 3
            // (they don't have a SidebarSection case today).
        case .coordinate:
            return [.fleet, .agents]
        }
    }
}
