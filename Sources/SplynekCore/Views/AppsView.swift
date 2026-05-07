// Copyright © 2026 Splynek. MIT.
//
// AppsView — sidebar consolidation (2026-05-07).
//
// Hosts both InstallView and UpdatesView under a single sidebar row,
// switching between them with a top-of-pane segmented Picker.  Both
// surfaces operate on the same InstalledAppRegistry and the same
// install pipeline; merging them removes a redundant sidebar row
// without sacrificing either surface's depth.
//
// The segmented control is intentionally minimal — no icons, no
// counters, just two tabs.  The badges that used to live on the
// sidebar rows (Install count + UPDATES NEW pill) now live on the
// segments themselves so the consolidation doesn't lose information.
//
// Both child views are unchanged — this file is purely a shell.

#if canImport(SwiftUI) && canImport(AppKit)
import SwiftUI
import AppKit

@MainActor
struct AppsView: View {
    @ObservedObject var vm: SplynekViewModel

    /// Which segment is active.  Defaults to Install — the more
    /// frequently used surface (drop a .dmg, install it).  Updates
    /// is the periodic-check surface.
    enum Tab: String, CaseIterable, Identifiable {
        case install, updates
        var id: String { rawValue }
        var title: LocalizedStringKey {
            switch self {
            case .install: return "Install"
            case .updates: return "Updates"
            }
        }
    }

    @State private var tab: Tab = .install

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { t in
                    Text(t.title).tag(t)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 8)

            Divider()

            switch tab {
            case .install:
                InstallView(vm: vm)
            case .updates:
                UpdatesView(vm: vm)
            }
        }
    }
}

#endif
