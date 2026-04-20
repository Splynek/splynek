import SwiftUI
import UniformTypeIdentifiers

struct RootView: View {
    @ObservedObject var vm: SplynekViewModel
    @ObservedObject private var torrent: TorrentProgress
    @State private var section: SidebarSection = .downloads

    @MainActor
    init(vm: SplynekViewModel) {
        self.vm = vm
        _torrent = ObservedObject(wrappedValue: vm.torrentProgress)
    }

    var body: some View {
        NavigationSplitView {
            Sidebar(selection: $section, vm: vm, torrent: torrent)
                .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            detail
                .navigationSplitViewColumnWidth(min: 640, ideal: 880)
        }
        .navigationSplitViewStyle(.balanced)
        .task { await vm.refreshInterfaces() }
        .onDrop(of: [.url, .fileURL, .plainText], isTargeted: nil) { providers in
            vm.handleDrop(providers: providers)
        }
        .alert("Large download",
               isPresented: $vm.sizeConfirmationPending) {
            Button("Cancel", role: .cancel) { vm.declineLargeDownload() }
            Button("Download anyway") { vm.confirmLargeDownload() }
        } message: {
            Text("This download is \(formatBytes(vm.pendingSizeBytes)). Continue?")
        }
        .alert("Daily cap reached",
               isPresented: $vm.hostCapAlertPending) {
            Button("Cancel", role: .cancel) { vm.declineOverCapDownload() }
            Button("Download anyway", role: .destructive) { vm.confirmOverCapDownload() }
        } message: {
            Text("Today you've already used \(formatBytes(vm.hostCapAlertUsed)) from \(vm.hostCapAlertHost), past your \(formatBytes(vm.hostCapAlertLimit)) daily cap. Downloading anyway will clear today's cap for this host.")
        }
        // v0.49: menu-bar → sidebar-routing. Apple menu → Settings…
        // (⌘,) / About, Help menu → Legal… — each posts one of
        // these notifications; here we route to the matching
        // SidebarSection destination. Uses the splash route so
        // users see the panels exactly like they would from the
        // sidebar (no separate windows).
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowSettings)) { _ in
            section = .settings
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowLegal)) { _ in
            section = .legal
        }
        .onReceive(NotificationCenter.default.publisher(for: .splynekShowAbout)) { _ in
            section = .about
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch section {
        case .downloads: DownloadView(vm: vm)
        case .live:      LiveView(vm: vm)
        case .torrents:  TorrentView(vm: vm, progress: torrent)
        case .concierge: ConciergeView(vm: vm)
        case .recipes:   RecipeView(vm: vm)
        case .queue:     QueueView(vm: vm)
        case .fleet:     FleetView(vm: vm)
        case .benchmark: BenchmarkView(vm: vm)
        case .history:   HistoryView(vm: vm)
        case .settings:  SettingsView(vm: vm)
        case .legal:     LegalView(vm: vm)
        case .about:     AboutView(vm: vm)
        }
    }
}
