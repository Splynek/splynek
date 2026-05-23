// Copyright © 2026 Splynek. MIT.
//
// LifecycleTopBar — the chip strip that sits above the detail content
// in IA v2.  Renders the active LifecycleTab's subviews as horizontal
// chips; clicking one swaps the active subview without changing the
// sidebar tab.
//
// Visual reference: docs/mocks/discover.html etc. — same chip
// component, same SF Symbol icons, same "·" accent dot before the
// label of the selected chip.
//
// Inputs:
//   currentTab      — the active LifecycleTab (read-only here; set by Sidebar)
//   section         — the active SidebarSection (mutable; this view writes)
//   accessories     — per-section badge content, supplied by RootView
//
// Phase 2 of the IA migration.  Phase 3+ will refine the chip groupings
// (e.g. Download collapses live+downloads+queue+torrents into a single
// "Active" chip) and add new chips that don't have legacy SidebarSection
// cases (Trust Watcher, Updates separated from Installed).  For now,
// the chip list comes directly from LifecycleTabMapping.subviews(of:).

import SwiftUI

struct LifecycleTopBar: View {
    let currentTab: LifecycleTab
    @Binding var section: SidebarSection

    /// Optional per-section accessory (badge, count, pill).  RootView
    /// passes a closure so this view stays presentation-only and
    /// doesn't need to know about VM state.
    let accessory: (SidebarSection) -> AnyView?

    var body: some View {
        let subviews = LifecycleTabMapping.subviews(of: currentTab)

        // If the tab has only one subview, the chip strip is noise —
        // hide it.  Single-subview tabs feel like they have content
        // immediately rather than asking the user to make a choice
        // they don't need to make.
        if subviews.count <= 1 {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                ForEach(subviews) { sub in
                    chip(for: sub)
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.regularMaterial)
        }
    }

    @ViewBuilder
    private func chip(for sub: SidebarSection) -> some View {
        let isActive = (section == sub)
        Button {
            section = sub
        } label: {
            HStack(spacing: 6) {
                if isActive {
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 6, height: 6)
                }
                Text(LocalizedStringKey(sub.title))
                    .font(.system(size: 13, weight: .semibold))
                if let acc = accessory(sub) {
                    acc
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive
                          ? Color.primary.opacity(0.08)
                          : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(isActive ? .primary : .secondary)
        .help(Text(LocalizedStringKey(sub.title)))
    }
}
