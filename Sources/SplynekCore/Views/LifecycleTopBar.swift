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

    /// Optional trailing accessory shown right-aligned in the chip
    /// strip.  Used by Phase 5 to surface the "Ask Splynek" pill on
    /// Discover + My Apps without making Concierge a chip
    /// destination.  Per-tab, not per-section — the closure is invoked
    /// once with the current LifecycleTab and may return nil.
    let trailing: (LifecycleTab) -> AnyView?

    var body: some View {
        let subviews = LifecycleTabMapping.subviews(of: currentTab)
        let trailingView = trailing(currentTab)

        // Hide the bar entirely only if there's nothing to show on
        // either side.  Single-subview tabs with a trailing action
        // still render the bar (Phase 5 — My Apps would otherwise
        // lose its "Ask Splynek" pill on tabs whose chip list
        // collapses to one item later).
        if subviews.count <= 1 && trailingView == nil {
            EmptyView()
        } else {
            HStack(spacing: 4) {
                if subviews.count > 1 {
                    ForEach(subviews) { sub in
                        chip(for: sub)
                    }
                }
                Spacer()
                if let trailingView {
                    trailingView
                }
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

// MARK: - IA v2 Phase 5 — Ask Splynek trailing pill

/// Trailing-accessory pill rendered on the right edge of the chip
/// strip on Discover + My Apps.  Posts `.splynekShowConcierge`; the
/// notification is caught by `RootView` which flips its
/// `@State showingConcierge` so the `ConciergeSheetContainer` sheet
/// presents.
///
/// Lives here (next to the chip strip) rather than as a SwiftUI
/// `.toolbar` item so it visually anchors to the same material bar
/// the chips sit on — matches `docs/mocks/discover.html` /
/// `docs/mocks/my-apps.html`.
struct AskSplynekPill: View {
    var body: some View {
        Button {
            NotificationCenter.default.post(
                name: .splynekShowConcierge, object: nil
            )
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .semibold))
                Text(LocalizedStringKey("Ask Splynek"))
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.purple.opacity(0.18),
                                Color.accentColor.opacity(0.18)
                            ],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
            )
            .foregroundStyle(.primary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(Text(LocalizedStringKey("Ask Splynek — your local concierge")))
        .accessibilityLabel("Ask Splynek")
    }
}
