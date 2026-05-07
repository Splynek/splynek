// Copyright © 2026 Splynek. MIT.
//
// UpdatesView — Phase 3 of the 2026-05-07 product expansion.
// Placeholder shell so the sidebar nav compiles before the full
// implementation lands.  The actual logic (UpdateSource resolver,
// per-publisher detection, scheduler integration) is built in
// `AppUpdateInfo.swift` + this view.

#if canImport(SwiftUI)
import SwiftUI

@MainActor
struct UpdatesView: View {
    @ObservedObject var vm: SplynekViewModel

    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        EmptyView()  // Replaced in Phase 3
    }
}
#endif
