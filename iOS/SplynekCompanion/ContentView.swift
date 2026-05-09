// Copyright © 2026 Splynek. MIT.
//
// ContentView — root view for the iOS companion.  Two tabs:
//
//   • Macs    — paired-Mac list + add-mac flow + jobs view per Mac
//   • Submit  — paste-URL fallback (the Share Extension is the main
//               entry point; this is for users who type a URL directly)

#if canImport(SwiftUI)
import SwiftUI

struct ContentView: View {
    @State private var selection: Tab = .macs

    enum Tab: Hashable { case macs, submit, insights, settings }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { PairedMacsView() }
                .tabItem { Label("Macs", systemImage: "macbook.and.iphone") }
                .tag(Tab.macs)

            NavigationStack { SubmitURLView() }
                .tabItem { Label("Submit", systemImage: "arrow.up.doc.on.clipboard") }
                .tag(Tab.submit)

            // Sprint 1 PRO-PLUS-IPHONE (2026-05-09): Pro on iPhone.
            // Surfaces Sovereignty / Trust / Trust Watcher / History
            // pulled live over the relay summary endpoints.
            NavigationStack { MacInsightsView() }
                .tabItem { Label("Insights", systemImage: "chart.bar.doc.horizontal") }
                .tag(Tab.insights)

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
    }
}

#Preview { ContentView() }
#endif
