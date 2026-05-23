// Copyright © 2026 Splynek. MIT.
//
// DiscoverWelcomeCard — IA v2 Phase 7 (2026-05-23).
//
// First-run welcome card.  Replaces the v1.6.1 `OnboardingSheet`
// (three-step modal: welcome → output folder → audit) with the
// richer IA-v2 lifecycle introduction.  Designed to give a non-
// technical user the full picture in a single screen:
//
//   1. **Hero** — app icon + gradient brand mark + the "broken
//      downloads" reframe in one paragraph.  Anchors the product
//      in a problem the user recognises.
//   2. **Lifecycle grid** — 2×2 cards, one per LifecycleTab.  Each
//      card carries the canonical short promise (single source of
//      truth: `LifecycleTab.promise`) PLUS three concrete proof
//      points so a curious user can imagine what they'll actually
//      see when they click in.  No jargon — "Survives bad Wi-Fi"
//      not "multi-interface bonded HTTP/Range fetching".
//   3. **Trust strip** — three principle pills (local, no cloud,
//      open source) so a privacy-conscious user knows the stance
//      before installing anything.
//   4. **Actions** — primary "Tap Discover to start →" + ghost
//      "Skip the welcome".  Both flip the persisted flag; nothing
//      is gated.
//
// Surfaced by RootView when `!vm.hasCompletedOnboarding` and the
// active LifecycleTab is `.discover` (the first-run currentTab
// default).  Sovereignty audit-on-first-run is preserved without a
// manual trigger because `SovereigntyView.onAppear` auto-runs
// `scanner.scan()` (since 2026-05-08), so dismissing the welcome
// card lands the user on Discover where the scan kicks off
// automatically.
//
// macOS-13 compatibility notes:
//   • `foregroundStyle` on a `Text` leaf is macOS-14+; everything
//     here uses `foregroundColor`.
//   • The gradient title word is built via overlay + mask so it
//     renders on macOS 13 too.

import SwiftUI
import AppKit

struct DiscoverWelcomeCard: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 22) {
                hero
                lifecycleGrid
                trustStrip
                actions
            }
            .frame(maxWidth: 760)
            .padding(.horizontal, 40)
            .padding(.top, 26)
            .padding(.bottom, 24)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundGradient.ignoresSafeArea())
    }

    /// Soft vertical wash from window bg → faint accent → window bg.
    /// Adds dimension without competing with the content; matches the
    /// "premium native app" feel of the Settings/Concierge sheets.
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(nsColor: .windowBackgroundColor),
                Color.accentColor.opacity(0.05),
                Color(nsColor: .windowBackgroundColor)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 12) {
            appIcon

            // Two-tone brand mark.  "Welcome to " in primary, "Splynek"
            // in a purple→accent gradient (overlay+mask trick keeps
            // this macOS-13-compat; Text-level foregroundStyle is 14+).
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

    /// 64pt app icon at the top of the hero.  Falls back through the
    /// bundle resource → NSApp icon → SF Symbol so this never renders
    /// blank in dev builds where the .icns hasn't been copied.
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
                .frame(width: 58, height: 58)
                .shadow(color: Color.accentColor.opacity(0.20),
                        radius: 12, x: 0, y: 5)
        } else {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.accentColor)
        }
    }

    /// "Splynek" word with a purple→accent gradient.  Built via
    /// overlay+mask so it works on macOS 13 (the Text-level
    /// `foregroundStyle(LinearGradient)` overload is macOS-14+).
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

    // MARK: - Lifecycle 2×2 grid

    private var lifecycleGrid: some View {
        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 14),
                GridItem(.flexible(), spacing: 14)
            ],
            spacing: 14
        ) {
            ForEach(LifecycleTab.allCases) { tab in
                LifecycleStageCard(tab: tab)
            }
        }
    }

    // MARK: - Trust strip

    private var trustStrip: some View {
        HStack(spacing: 8) {
            TrustBadge(icon: "lock.shield.fill", label: "100% local")
            TrustBadge(icon: "icloud.slash", label: "No cloud, no account")
            TrustBadge(icon: "checkmark.seal.fill", label: "Open-source free tier")
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                complete()
            } label: {
                HStack(spacing: 6) {
                    Text(LocalizedStringKey("Tap Discover to start"))
                    Text(verbatim: "→")
                }
                .font(.system(size: 14, weight: .semibold))
                .frame(minWidth: 280)
                .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Button {
                complete()
            } label: {
                Text(LocalizedStringKey("Skip the welcome"))
                    .foregroundColor(.secondary)
                    .font(.callout)
            }
            .buttonStyle(.plain)
            .controlSize(.small)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.top, 4)
    }

    /// Both CTAs flip the same flag — the welcome card is
    /// informational, not a gated decision.  Skipping is a first-class
    /// outcome ("we'd rather a user dismiss than feel trapped"; that
    /// principle survives from the retired OnboardingSheet).
    private func complete() {
        vm.hasCompletedOnboarding = true
    }
}

// MARK: - Lifecycle stage card

/// One card per LifecycleTab.  Title + tab promise + three concrete
/// "what you'll actually see" bullets.  Plain language so a non-techie
/// can imagine the value before clicking in.
private struct LifecycleStageCard: View {
    let tab: LifecycleTab

    /// Welcome-specific marketing copy.  Lives here (not on
    /// LifecycleTab itself) so the tab's `.title` + `.promise` stay
    /// the canonical short labels used in sidebar/tooltips/L10n.
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
        VStack(alignment: .leading, spacing: 10) {
            // Icon row
            HStack(spacing: 10) {
                iconWell
                Text(LocalizedStringKey(tab.title))
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer(minLength: 0)
            }

            // Promise (the canonical tab one-liner)
            Text(LocalizedStringKey(tab.promise))
                .font(.callout)
                .fontWeight(.medium)
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)

            // Three proof-point bullets
            VStack(alignment: .leading, spacing: 5) {
                ForEach(0..<features.count, id: \.self) { i in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.accentColor)
                            .frame(width: 12, alignment: .center)
                        Text(features[i])
                            .font(.footnote)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
    }

    /// Tinted glyph well — 34pt circle with a subtle accent gradient.
    /// Matches the visual rhythm of the AskSplynekPill on the chip
    /// strip so the welcome card and the rest of the IA-v2 surface
    /// feel like the same product.
    private var iconWell: some View {
        Image(systemName: tab.systemImage)
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.accentColor)
            .frame(width: 34, height: 34)
            .background(
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentColor.opacity(0.20),
                                Color.purple.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                Circle()
                    .stroke(Color.accentColor.opacity(0.18), lineWidth: 0.5)
            )
    }
}

// MARK: - Trust badge

/// Capsule pill for the trust-principles strip.  Tinted glyph + label,
/// rounded to match the AskSplynekPill family.
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
