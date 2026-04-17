import SwiftUI

/// Thin wrapper kept so the SPM `@main` call chain doesn't have to know
/// about the split layout. All real UI lives under `Views/`.
struct ContentView: View {
    let vm: SplynekViewModel

    @MainActor
    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        RootView(vm: vm)
    }
}
