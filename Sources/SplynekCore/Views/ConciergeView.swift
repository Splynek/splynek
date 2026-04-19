import SwiftUI

/// Stub `ConciergeView` for the free build. This screen is unreachable
/// from the sidebar because the navigation entry is gated on
/// `vm.license.isPro`, which is always `false` in the free tier —
/// but `RootView.detail`'s exhaustive switch on `SidebarSection`
/// still needs a concrete case for `.concierge`, so this placeholder
/// keeps the compilation happy.
///
/// The real Concierge lives in the private `SplynekPro` package and
/// is linked into the Mac App Store build.
struct ConciergeView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ProLockedView(
            featureTitle: "AI Concierge",
            summary: "Chat-first control for Splynek. Type what you want — \"download the latest Firefox\", \"find that iOS SDK I grabbed in Jan\", \"cancel everything\" — and the local LLM routes it to the right action. Pro feature; available in the Mac App Store build of Splynek.",
            systemImage: "sparkles",
            onUnlock: {}
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
