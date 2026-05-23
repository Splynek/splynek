// Copyright © 2026 Splynek. MIT.
//
// DiscoverWelcomeCard — IA v2 Phase 7 (2026-05-23).
//
// First-run welcome **splash**.  Replaces the v1.6.1 OnboardingSheet
// (three-step modal) with a single screen that teaches the whole
// product in one viewport.  Phase 7.v2 (this revision) takes the
// product story further:
//
//   1. Welcome is a true splash — no sidebar tab is highlighted
//      while it's up.  RootView's `currentTab` is optional;
//      nil → splash, non-nil → real app.
//   2. Each lifecycle stage card is a CLICKABLE BUTTON that drops
//      the user into that tab.  No "Tap Discover to start →"
//      button — the cards ARE the entry points.  This makes the
//      welcome a chooser, not a forced funnel.
//   3. Each card carries the tab's own rainbow tint (blue / purple
//      / pink / orange — drawn from the Splynek logo's gradient)
//      so the four moments feel like four distinct chapters.
//   4. A short, memorable VERB-PHRASE slogan per card
//      ("Choose well.", "Get it home.", "Keep watch.", "All in
//      sync.") tells the lifecycle story arc when the four are
//      read together.
//   5. Vertical padding is balanced top↔bottom; only a ghost
//      "Skip the welcome" sits at the bottom for explicit
//      dismissal.
//
// macOS-13 compatibility notes:
//   • `foregroundStyle` on a `Text` leaf is macOS-14+; everything
//     here uses `foregroundColor`.
//   • The gradient title word is built via overlay + mask.
//   • `.onHover` is macOS-11+ (fine).

import SwiftUI
import AppKit

struct DiscoverWelcomeCard: View {
    @ObservedObject var vm: SplynekViewModel
    /// Called when the user picks a lifecycle tab from a story
    /// tile.  RootView translates this into `currentTab = tab`,
    /// which triggers the `.onChange` that dismisses the welcome by
    /// flipping `hasCompletedOnboarding`.
    let onPick: (LifecycleTab) -> Void

    var body: some View {
        // Phase 7.v3 (2026-05-23): full-bleed splash inside a
        // GeometryReader so the four sections (hero / grid /
        // bottom strip) distribute proportionally to whatever
        // window height is available — no ScrollView, no Spacers
        // misbehaving inside NavigationSplitView, no clipped
        // content on smaller windows.
        GeometryReader { geo in
            VStack(spacing: 0) {
                hero
                    .padding(.top, max(20, geo.size.height * 0.04))

                Spacer(minLength: 16)

                lifecycleGrid

                Spacer(minLength: 16)

                bottomStrip
                    .padding(.bottom, max(20, geo.size.height * 0.04))
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 40)
            .frame(width: geo.size.width, height: geo.size.height,
                   alignment: .center)
        }
        .background(backgroundGradient)
        // Hide the right-pane navigation title during the splash;
        // an explicit empty title collapses the toolbar's title slot
        // without nuking the toolbar itself (which broke sidebar +
        // hero rendering in the previous attempt).
        .navigationTitle("")
    }

    /// Solid window-background wash, with a very faint vertical tint
    /// so the splash has a hair of dimension without looking like a
    /// gradient.  Note: NO `.ignoresSafeArea` — extending the
    /// background under the title bar would make the logo sit
    /// beneath a translucent toolbar material (what looked like
    /// "transparency on the logo" in the previous build).
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.04),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 10) {
            appIcon

            HStack(spacing: 0) {
                Text(LocalizedStringKey("Welcome to "))
                    .foregroundColor(.primary)
                gradientTitleWord
                Text(verbatim: ".")
                    .foregroundColor(.primary)
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))

            Text(LocalizedStringKey("Your download lifecycle, fixed."))
                .font(.system(.title3, design: .rounded))
                .foregroundColor(.secondary)

            Text(LocalizedStringKey(
                "Most tools stop at \"file saved\".  Splynek fixes all four moments — pick the right app, fetch it reliably, keep installed apps safe, coordinate across devices."
            ))
            .font(.callout)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 8)
            .padding(.top, 2)
        }
    }

    /// 56pt app icon with a soft accent-tinted shadow.
    @ViewBuilder
    private var appIcon: some View {
        let resolved: NSImage? = {
            if let url = Bundle.main.url(forResource: "Splynek", withExtension: "icns"),
               let img = NSImage(contentsOf: url) {
                return img
            }
            return NSApp.applicationIconImage
        }()

        if let img = resolved {
            Image(nsImage: img)
                .resizable()
                .interpolation(.high)
                .frame(width: 56, height: 56)
                .shadow(color: Color.accentColor.opacity(0.20),
                        radius: 12, x: 0, y: 5)
        } else {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 46))
                .foregroundColor(.accentColor)
        }
    }

    /// "Splynek" with a purple→accent gradient via overlay+mask.
    private var gradientTitleWord: some View {
        Text(LocalizedStringKey("Splynek"))
            .foregroundColor(.clear)
            .overlay(
                LinearGradient(
                    colors: [.purple, .accentColor],
                    startPoint: .leading, endPoint: .trailing
                )
                .mask(
                    Text(LocalizedStringKey("Splynek"))
                        .font(.system(.largeTitle,
                                      design: .rounded, weight: .bold))
                )
            )
            .fixedSize()
    }

    // MARK: - Lifecycle 2×2 grid (clickable story tiles)

    private var lifecycleGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 14
        ) {
            ForEach(LifecycleTab.allCases) { tab in
                LifecycleStageTile(tab: tab) {
                    onPick(tab)
                }
            }
        }
    }

    // MARK: - Bottom strip — trust principles + micro-hint

    /// Trust pills on top, a single muted line below that doubles as
    /// (a) onboarding affordance — "the tiles are clickable" — and
    /// (b) the bottom anchor that mirrors the hero's vertical weight,
    /// so the splash reads balanced top↔bottom.
    private var bottomStrip: some View {
        VStack(spacing: 14) {
            HStack(spacing: 8) {
                TrustBadge(icon: "lock.shield.fill", label: "100% local")
                TrustBadge(icon: "icloud.slash", label: "No cloud, no account")
                TrustBadge(icon: "checkmark.seal.fill", label: "Open-source free tier")
            }
            .frame(maxWidth: .infinity)

            Text(LocalizedStringKey("Pick a tile above to begin →"))
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
                .opacity(0.75)
        }
    }
}

// MARK: - Lifecycle stage tile (clickable card)

/// One tile per LifecycleTab.  Click → drops the user into that
/// tab AND dismisses the welcome.  Hover lifts the tile slightly
/// to telegraph "this is interactive"; press scales down for
/// tactile feedback.
///
/// Each tile is tinted with its tab's `tintColor` (the rainbow
/// drawn from the Splynek logo: blue → purple → pink → orange) so
/// the four moments are visually distinct chapters of the same
/// story.
private struct LifecycleStageTile: View {
    let tab: LifecycleTab
    let onTap: () -> Void
    @State private var isHovered: Bool = false

    /// Concrete proof-points per tab.  Plain language a non-techie
    /// can imagine, specific enough that a power user is intrigued.
    private var features: [LocalizedStringKey] {
        switch tab {
        case .discover:
            return [
                "See privacy + spending scores",
                "Compare with free alternatives",
                "Explore curated app stacks"
            ]
        case .download:
            return [
                "Survives bad Wi-Fi",
                "Resumes across networks",
                "Verifies every byte"
            ]
        case .myApps:
            return [
                "Auto-updates without nagging",
                "Alerts when an app's policy changes",
                "Yearly spending breakdown"
            ]
        case .coordinate:
            return [
                "Pair iPhone + Watch",
                "Share over your LAN",
                "Hand off downloads between Macs"
            ]
        }
    }

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                header
                slogan
                bullets
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tileBackground)
            .overlay(tileBorder)
            .shadow(color: tileShadow,
                    radius: isHovered ? 12 : 6,
                    x: 0, y: isHovered ? 4 : 2)
            .scaleEffect(isHovered ? 1.015 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.12)) {
                isHovered = hovering
            }
        }
        .help(Text(LocalizedStringKey(tab.title)) +
              Text(verbatim: " — ") +
              Text(LocalizedStringKey(tab.promise)))
    }

    // MARK: - Components

    private var header: some View {
        HStack(spacing: 11) {
            iconWell
            Text(LocalizedStringKey(tab.title))
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .foregroundColor(.primary)
            Spacer(minLength: 0)
        }
    }

    /// 44pt circular icon well, tinted with the tab's own colour.
    /// The gradient runs from the tint at 25% → tint at 10% so each
    /// tab gets a visible identity without screaming.
    private var iconWell: some View {
        Image(systemName: tab.systemImage)
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(tab.tintColor)
            .frame(width: 44, height: 44)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                tab.tintColor.opacity(0.25),
                                tab.tintColor.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(tab.tintColor.opacity(0.30), lineWidth: 0.6)
            )
    }

    /// Verb-phrase slogan.  Tab-tinted so the eye groups it with the
    /// icon well — the colour is the "this is what this chapter is
    /// about" signal.
    private var slogan: some View {
        Text(LocalizedStringKey(tab.slogan))
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundColor(tab.tintColor)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var bullets: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(0..<features.count, id: \.self) { i in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(tab.tintColor)
                        .frame(width: 12, alignment: .center)
                    Text(features[i])
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    // MARK: - Tile styling

    /// Slightly tinted background — base bg + a whisper of the
    /// tab's colour so each tile feels like its own micro-zone
    /// without becoming gaudy.  Hover deepens both layers.
    private var tileBackground: some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(Color(nsColor: .controlBackgroundColor)
                  .opacity(isHovered ? 0.85 : 0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .fill(tab.tintColor
                          .opacity(isHovered ? 0.06 : 0.025))
            )
    }

    private var tileBorder: some View {
        RoundedRectangle(cornerRadius: 14)
            .stroke(tab.tintColor.opacity(isHovered ? 0.40 : 0.12),
                    lineWidth: isHovered ? 1.0 : 0.5)
    }

    private var tileShadow: Color {
        tab.tintColor.opacity(isHovered ? 0.18 : 0.06)
    }
}

// MARK: - Trust badge

/// Capsule pill for the trust-principles strip.
private struct TrustBadge: View {
    let systemImage: String
    let label: LocalizedStringKey

    init(icon: String, label: String) {
        self.systemImage = icon
        self.label = LocalizedStringKey(label)
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.accentColor)
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(Color.primary.opacity(0.04))
        )
        .overlay(
            Capsule()
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
    }
}
