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

    enum Tab: Hashable { case macs, submit }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack { PairedMacsView() }
                .tabItem { Label("Macs", systemImage: "macbook.and.iphone") }
                .tag(Tab.macs)

            NavigationStack { SubmitURLView() }
                .tabItem { Label("Submit", systemImage: "arrow.up.doc.on.clipboard") }
                .tag(Tab.submit)
        }
    }
}

#Preview { ContentView() }
#endif
