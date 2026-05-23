import SwiftUI

/// Free-tier `ConciergeView`. In the Mac App Store build this slot
/// is replaced (via target-level source exclusion) by the chat-first
/// Pro Concierge from the private `SplynekPro` package. In the free
/// DMG the same sidebar entry lands here — a proper "this is what
/// you get with Pro" upsell, not a hidden/empty screen.
///
/// Design note — this view used to be a tiny `ProLockedView` card
/// pinned to the top-leading corner of an otherwise empty detail
/// column. In wide windows the card was lost in blank space and the
/// tab read as broken. v0.50.2 rewrites the stub to match the same
/// full-bleed upsell pattern the Pro build uses when StoreKit hasn't
/// unlocked yet: centred gradient glyph, bold title, bullet pitch,
/// and a big MAS CTA button. Ensures the tab is never empty.
struct ConciergeView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .accentColor],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .padding(.top, 20)

                VStack(spacing: 6) {
                    Text("The Splynek Concierge")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Your personal download concierge.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow("Talk to Splynek in plain language")
                    bulletRow("Chat-routed downloads, queue, cancellations, pauses")
                    bulletRow("Natural-language search of your download history")
                    bulletRow("100% local LLM (LM Studio or Ollama) — no cloud, no account")
                }
                .frame(maxWidth: 440)
                .padding(.top, 4)

                if let url = URL(string: "https://apps.apple.com/app/splynek") {
                    Link(destination: url) {
                        Label("Unlock Splynek Pro — $29", systemImage: "cart.fill")
                            .frame(minWidth: 220)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .padding(.top, 8)
                }

                Text("One-time purchase. Lifetime 0.x updates.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 24)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("Concierge")
    }

    @ViewBuilder
    private func bulletRow(_ text: String) -> some View {
        // v1.6.2: route through LocalizedStringKey so catalog can localize.
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(LocalizedStringKey(text))
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - IA v2 Phase 5 — Concierge as a sheet

/// Sheet wrapper around `ConciergeView`.  Phase 5 of the IA reorg
/// (2026-05-23) — Concierge is a verb, not a destination, so it no
/// longer lives in the Discover chip strip.  Instead it's invoked by
/// the "Ask Splynek" pill on Discover + My Apps (and any future menu
/// bar / Cmd+K caller) via a notification + `.sheet` presenter on
/// RootView.
///
/// Adds a thin sheet chrome: title bar on top, embedded ConciergeView
/// body, fixed sheet width so the modal doesn't stretch on wide
/// displays.  Dismiss flips the parent's `@State showingConcierge`
/// via the standard SwiftUI `.dismiss` env action.
struct ConciergeSheetContainer: View {
    @ObservedObject var vm: SplynekViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Label {
                    Text("Ask Splynek")
                        .font(.system(.headline, design: .rounded, weight: .semibold))
                } icon: {
                    Image(systemName: "sparkles")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.purple, .accentColor],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                }
                Spacer()
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
            .overlay(
                Divider().opacity(0.6),
                alignment: .bottom
            )

            ConciergeView(vm: vm)
        }
        .frame(minWidth: 520, idealWidth: 620, maxWidth: 720,
               minHeight: 460, idealHeight: 620, maxHeight: .infinity)
    }
}
