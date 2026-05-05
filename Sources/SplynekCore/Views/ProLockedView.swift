import SwiftUI

/// Placeholder shown in place of a Pro-gated feature in the free
/// build. In the MAS build, the real `ProLockedView` (shipped in
/// the private `SplynekPro` package) presents a StoreKit IAP
/// unlock flow here. In the free DMG, it just points users at the
/// Mac App Store listing.
///
/// Not visually minimal — the free build lands users on a clear
/// "this exists, it's $29 on MAS" message rather than silently
/// hiding the feature.
struct ProLockedView: View {
    // v1.6.2 wrapped featureTitle at use site; full audit 2026-05-05
    // moved both featureTitle + summary to LocalizedStringKey at the
    // type level — String parameters silently fail SwiftUI's
    // localization (Text(String) doesn't lookup) and aren't seen by
    // find-missing-translations.py either, so summary strings on this
    // view sat in source untranslated for months without tooling
    // catching them.  LocalizedStringKey enforces localization both
    // at runtime + audit-time.
    let featureTitle: LocalizedStringKey
    let summary: LocalizedStringKey
    let systemImage: String
    let onUnlock: () -> Void

    var body: some View {
        TitledCard(title: featureTitle, systemImage: systemImage) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(Color.accentColor)
                    Text("Splynek Pro feature")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    StatusPill(text: "MAS", style: .info)
                }
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    if let url = URL(string: "https://splynek.app/pro") {
                        Link(destination: url) {
                            Label("Get Splynek Pro on the Mac App Store",
                                  systemImage: "arrow.up.right.square")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    Spacer()
                }
            }
        }
    }
}
