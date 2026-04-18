import SwiftUI

/// Reusable paywall placeholder shown in place of a Pro-gated
/// feature when the current session isn't licensed. Not a modal,
/// not a banner — it takes over the feature's real estate so the
/// user sees exactly what Pro unlocks without being able to use it.
///
/// The design intent is "visible but not functional." Apple's MAS
/// review guidelines and Stripe-direct conventions both prefer
/// *disabled with a clear CTA* over *hidden entirely*, because:
///   - the feature discovery is marketing;
///   - removing a familiar UI after a free-tier downgrade confuses
///     users who've had Pro before;
///   - accessibility tools can still describe the feature.
struct ProLockedView: View {
    let featureTitle: String
    let summary: String
    let systemImage: String
    let onUnlock: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.tint)
                .padding(.top, 12)
            HStack(spacing: 8) {
                Text(featureTitle)
                    .font(.system(.title3, design: .rounded, weight: .semibold))
                StatusPill(text: "PRO", style: .warning)
            }
            Text(summary)
                .font(.callout).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                onUnlock()
            } label: {
                Label("Unlock Splynek Pro — $29", systemImage: "key.fill")
                    .frame(minWidth: 200)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 6)
            Text("One-time purchase. Lifetime updates on the 0.x line.")
                .font(.caption).foregroundStyle(.secondary)
                .padding(.bottom, 14)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 1)
        )
    }
}
