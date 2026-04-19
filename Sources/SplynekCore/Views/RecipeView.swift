import SwiftUI

/// Stub `RecipeView` for the free build. Same rationale as the
/// stub `ConciergeView`: the sidebar entry is gated on Pro, but
/// `RootView.detail`'s switch over `SidebarSection` needs a concrete
/// case for `.recipes`, so we render a placeholder.
///
/// The real Agentic Download Recipes view lives in the private
/// `SplynekPro` package and is linked into the Mac App Store build.
struct RecipeView: View {
    @ObservedObject var vm: SplynekViewModel

    var body: some View {
        ProLockedView(
            featureTitle: "Agentic Download Recipes",
            summary: "Type a plain-English goal — \"set up my Mac for iOS dev\", \"mirror the latest Ubuntu release\" — and the local LLM proposes a multi-item download plan you review and queue in one click. Pro feature; available in the Mac App Store build of Splynek.",
            systemImage: "list.star",
            onUnlock: {}
        )
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
