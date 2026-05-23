// Copyright © 2026 Splynek. MIT.
//
// DiscoverWelcomeCard — IA v2 Phase 7 (2026-05-23).
//
// First-run welcome card.  Replaces the v1.6.1 `OnboardingSheet`
// (three-step modal: welcome → output folder → audit) with the
// simpler IA-v2 lifecycle introduction described in
// `IA-WIREFRAMES.md` Section 4 / Frame 01 + visualised in
// `docs/mocks/index.html`.
//
// Surfaced by RootView when `!vm.hasCompletedOnboarding` and the
// active LifecycleTab is `.discover` (the first-run currentTab
// default).  Replaces the chip strip + Sovereignty default content
// for that single render.  When the user taps either CTA the flag
// flips and the normal Discover content (chip strip + auto-scanning
// SovereigntyView) takes over — no separate audit trigger needed
// because SovereigntyView auto-runs `scanner.scan()` on its first
// `.onAppear` (introduced 2026-05-08).

import SwiftUI

struct DiscoverWelcomeCard: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                hero
                bulletList
                actions
            }
            .frame(maxWidth: 560)
            .padding(.horizontal, 32)
            .padding(.top, 64)
            .padding(.bottom, 40)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Hero

    private var hero: some View {
        VStack(spacing: 14) {
            // Two-tone title — "Welcome to " in primary, "Splynek" in
            // gradient accent (via overlay+mask so this stays
            // macOS-13-compat; foregroundStyle on Text is macOS-14+).
            // Matches the mock's `.accent` span exactly.
            HStack(spacing: 0) {
                Text(LocalizedStringKey("Welcome to "))
                    .foregroundColor(.primary)
                gradientTitleWord
                Text(verbatim: ".")
                    .foregroundColor(.primary)
            }
            .font(.system(.largeTitle, design: .rounded, weight: .bold))
            .multilineTextAlignment(.center)

            Text(LocalizedStringKey(
                "Splynek fixes the broken download lifecycle — from picking the right app, to fetching it fast, to keeping your installed stack safe."
            ))
            .font(.title3)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
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
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                )
            )
            .fixedSize()
    }

    // MARK: - Bullet list

    private var bulletList: some View {
        // Single source of truth — `LifecycleTab` already carries the
        // `.title` + `.promise` strings that Section 4 of
        // IA-WIREFRAMES.md prescribes for these bullets, so the card
        // can't drift from the rest of the IA-v2 surface.
        VStack(alignment: .leading, spacing: 12) {
            ForEach(LifecycleTab.allCases) { tab in
                bulletRow(for: tab)
            }
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    @ViewBuilder
    private func bulletRow(for tab: LifecycleTab) -> some View {
        // Tinted glyph + bold tab name + gray promise.  Text-level
        // `foregroundStyle` is macOS-14+, so each Text segment uses
        // `foregroundColor` and Text concatenation is avoided in
        // favour of an HStack — the per-segment color survives that
        // way without losing baseline alignment.
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Image(systemName: tab.systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.accentColor)
                .frame(width: 22, alignment: .center)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(LocalizedStringKey(tab.title))
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(verbatim: "—")
                    .foregroundColor(.secondary)
                Text(LocalizedStringKey(tab.promise))
                    .foregroundColor(.secondary)
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - Actions

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                complete()
            } label: {
                Text(LocalizedStringKey("Tap Discover to start →"))
                    .frame(minWidth: 260)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .keyboardShortcut(.defaultAction)

            Button {
                complete()
            } label: {
                Text(LocalizedStringKey("Skip the welcome"))
                    .foregroundColor(.secondary)
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
    /// principle survives from the retired OnboardingSheet).  The
    /// SovereigntyView's existing `.onAppear` scan kicks off
    /// automatically as soon as the user lands on Discover after
    /// dismissal, so the optional v1.6.1 "Run audit" step is now
    /// implicit rather than an extra button.
    private func complete() {
        vm.hasCompletedOnboarding = true
    }
}
