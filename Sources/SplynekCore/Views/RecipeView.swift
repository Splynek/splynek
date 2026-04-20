import SwiftUI

/// Free-tier `RecipeView`. Mirrors the design of the free-tier
/// `ConciergeView` stub so the two Pro-discovery tabs feel coherent.
/// Replaced by the real Agentic Recipes view in the Mac App Store
/// build via target-level source exclusion.
///
/// Prior version (v0.50 and earlier) was a tiny `ProLockedView` card
/// in the top-leading corner of a wide detail column — visually read
/// as a broken/empty tab. v0.50.2 rewrites to a full-bleed pitch with
/// a centered glyph, four value bullets, and the MAS CTA.
struct RecipeView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                Image(systemName: "list.star")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.purple, .accentColor],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                    .padding(.top, 20)

                VStack(spacing: 6) {
                    Text("Agentic Download Recipes")
                        .font(.system(.title, design: .rounded, weight: .bold))
                    Text("Tell it what you want to set up. Get a download plan.")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 10) {
                    bulletRow("Type a goal like \"set up my Mac for iOS dev\"")
                    bulletRow("The local LLM proposes each download with URL + rationale")
                    bulletRow("Review, uncheck, and queue the whole batch in one click")
                    bulletRow("24 themed starter goals across 6 categories")
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
        .navigationTitle("Recipes")
    }

    @ViewBuilder
    private func bulletRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
            Text(text)
                .font(.callout)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
        }
    }
}
