// Copyright © 2026 Splynek. MIT.
//
// PairedMacsView — the home tab.  Lists every paired Mac, with a
// status pill (online via Bonjour right now / unreachable / never seen
// since pairing).  Tapping a Mac opens its jobs view; the toolbar +
// button opens the pairing flow.
//
// State management deliberately kept simple — `@State` arrays + a
// refresh-on-foreground.  The list will rarely have more than 1-3
// items in practice; ObservableObject overhead would be wasted.

#if canImport(SwiftUI)
import SwiftUI

struct PairedMacsView: View {
    @State private var paired: [PairedMac] = []
    @State private var liveDiscoveries: [SplynekBonjourBrowser.Discovered] = []
    @State private var showingPairingSheet = false
    @State private var browser = SplynekBonjourBrowser()

    private var store: PairedMacStore? { PairedMacStore() }

    var body: some View {
        List {
            if paired.isEmpty {
                emptySection
            } else {
                Section("Paired") {
                    ForEach(paired) { mac in
                        NavigationLink(destination: JobsView(mac: mac)) {
                            PairedMacRow(mac: mac, online: liveDiscoveries.contains { $0.uuid == mac.uuid })
                        }
                    }
                    .onDelete(perform: removeMac)
                }
            }
            if !liveDiscoveries.filter({ d in !paired.contains { $0.uuid == d.uuid } }).isEmpty {
                Section("Discovered on this network") {
                    ForEach(liveDiscoveries.filter { d in !paired.contains { $0.uuid == d.uuid } }) { d in
                        Button {
                            showingPairingSheet = true
                            // PairingSheet will pre-fill with the
                            // discovered device.  We surface this via
                            // a lightweight environment value rather
                            // than wiring up a coordinator — there's
                            // only one entry point.
                            UserDefaults.standard.set(d.uuid, forKey: "splynek.companion.preselectUUID")
                        } label: {
                            DiscoveredMacRow(d: d)
                        }
                    }
                }
            }
        }
        .navigationTitle("Splynek Companion")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingPairingSheet = true } label: {
                    Image(systemName: "plus.circle")
                }
            }
        }
        .sheet(isPresented: $showingPairingSheet) {
            PairingSheet(onPaired: { mac in
                store?.upsert(mac)
                refresh()
            })
        }
        .onAppear { startBrowsing() }
        .onDisappear { browser.stop() }
        .refreshable { refresh() }
    }

    @ViewBuilder
    private var emptySection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "macbook.and.iphone")
                    .font(.system(size: 56))
                    .foregroundStyle(.secondary)
                Text("No Macs paired yet")
                    .font(.headline)
                Text("Open Splynek on your Mac, then tap + to pair.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private func startBrowsing() {
        refresh()
        browser.start { discovered in
            self.liveDiscoveries = discovered
        }
    }

    private func refresh() {
        paired = store?.all() ?? []
    }

    private func removeMac(at offsets: IndexSet) {
        for i in offsets {
            store?.remove(uuid: paired[i].uuid)
        }
        refresh()
    }
}

private struct PairedMacRow: View {
    let mac: PairedMac
    let online: Bool

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(online ? .green : .gray.opacity(0.3))
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 2) {
                Text(mac.displayName)
                    .font(.body)
                Text(online
                     ? "On this Wi-Fi"
                     : "Last seen \(RelativeDateTimeFormatter().localizedString(for: mac.lastSeen, relativeTo: .now))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct DiscoveredMacRow: View {
    let d: SplynekBonjourBrowser.Discovered

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text(d.displayName)
                Text("Tap to pair · v\(d.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
#endif
