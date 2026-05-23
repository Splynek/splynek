// Copyright © 2026 Splynek. MIT.
//
// SettingsSheet — IA v2 Phase 6 (2026-05-23).
//
// Unified modal sheet that hosts the three "non-tab" destinations the
// pre-IA-v2 sidebar used to surface in the detail column:
//
//   • Settings  — cross-cutting app config (Pro license, Ollama, etc.)
//   • Legal     — bundled EULA / Privacy / AUP markdown viewer
//   • About     — brand hero, version, update banner, credits
//
// Each one was previously its own SidebarSection rendered in the
// detail column when triggered by a menu-bar `.splynek*` notification.
// Phase 6 retires them as destinations and re-presents them as a
// single sheet invoked from the sidebar's gear-icon footer (and from
// the same menu-bar items via the existing notifications).  Matches
// the Apple macOS preferences convention — Cmd+, opens a panel, not
// a tab.
//
// The detail switch cases in `RootView` remain as a compile-time
// safety net for `SidebarSection` exhaustiveness; nothing in normal
// flow reaches them after Phase 6 because the notifications now flip
// `settingsRoute` instead of `section`.
//
// See:
//   IA-PROPOSAL.md           — § "Sheets, not tabs"
//   IA-V2-MIGRATION-STATUS.md — Phase 6 touch points
//   docs/mocks/               — clickable prototype

import SwiftUI

/// Which pane the sheet presents on entry.  Identifiable so it works
/// with `.sheet(item:)`, which gives us automatic dismiss-on-nil and
/// re-present-on-route-change behaviour for free.
enum SettingsRoute: String, Identifiable, Hashable, CaseIterable {
    case settings
    case legal
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .settings: return "Settings"
        case .legal:    return "Legal"
        case .about:    return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .settings: return "gearshape"
        case .legal:    return "doc.text"
        case .about:    return "info.circle"
        }
    }
}

/// Three-pane sheet.  Top bar carries a segmented Picker that switches
/// between the panes; bottom hosts the existing view verbatim so the
/// content code stays untouched.
struct SettingsSheet: View {
    @ObservedObject var vm: SplynekViewModel
    @Environment(\.dismiss) private var dismiss

    /// The currently visible pane.  Initialised from the route the
    /// caller passed (so "Settings…" from the menu bar lands on
    /// Settings; the gear footer also lands on Settings; Legal /
    /// About from the menu bar each land on their respective pane).
    @State private var pane: SettingsRoute

    init(initialPane: SettingsRoute, vm: SplynekViewModel) {
        self.vm = vm
        _pane = State(initialValue: initialPane)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.6)
            content
        }
        .frame(minWidth: 720, idealWidth: 820, maxWidth: 1100,
               minHeight: 540, idealHeight: 680, maxHeight: .infinity)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            Label {
                Text(LocalizedStringKey(pane.title))
                    .font(.system(.headline, design: .rounded, weight: .semibold))
            } icon: {
                Image(systemName: pane.systemImage)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 16)

            // Segmented switcher between the three panes.  Compact
            // enough to share the title bar; users who entered via a
            // menu-bar deep link can still flip to another pane
            // without dismissing the sheet.
            Picker("", selection: $pane) {
                ForEach(SettingsRoute.allCases) { route in
                    Label {
                        Text(LocalizedStringKey(route.title))
                    } icon: {
                        Image(systemName: route.systemImage)
                    }
                    .labelStyle(.titleAndIcon)
                    .tag(route)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(maxWidth: 360)

            Spacer(minLength: 16)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Close")
            .accessibilityLabel("Close")
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch pane {
        case .settings: SettingsView(vm: vm)
        case .legal:    LegalView(vm: vm)
        case .about:    AboutView(vm: vm)
        }
    }
}
