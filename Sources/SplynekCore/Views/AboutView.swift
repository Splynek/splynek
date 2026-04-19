import SwiftUI

struct AboutView: View {
    @ObservedObject var vm: SplynekViewModel
    @EnvironmentObject var background: BackgroundModeController

    init(vm: SplynekViewModel) { self.vm = vm }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                VStack(spacing: 10) {
                    brandHero
                    VStack(spacing: 2) {
                        Text("Splynek")
                            .font(.system(size: 26, weight: .bold, design: .rounded))
                        Text("Multi-interface download aggregator")
                            .font(.callout).foregroundStyle(.secondary)
                        Text("Version \(version)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 4)

                if let upd = vm.availableUpdate {
                    updateBanner(upd)
                        .padding(.horizontal, 40)
                        .frame(maxWidth: 780)
                }

                featuresGrid
                    .padding(.horizontal, 40)
                    .frame(maxWidth: 780)

                legalShortcutsCard
                    .padding(.horizontal, 40)
                    .frame(maxWidth: 780)

                Spacer(minLength: 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .navigationTitle("About")
    }

    /// Load the raw bundled `.icns` directly. Avoids
    /// `NSApp.applicationIconImage`, which on recent macOS wraps the
    /// rendered icon in a generic-app white frame when the LaunchServices
    /// cache is stale or when rendering at non-standard sizes — not what
    /// we want for the hero.
    @ViewBuilder private var brandHero: some View {
        if let url = Bundle.main.url(forResource: "Splynek", withExtension: "icns"),
           let nsImage = NSImage(contentsOf: url) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        } else if let nsImage = NSApp.applicationIconImage {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 88, height: 88)
                .shadow(color: .black.opacity(0.18), radius: 10, x: 0, y: 5)
        } else {
            Image(systemName: "arrow.down.circle.fill")
                .font(.system(size: 68, weight: .regular))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.accentColor, .accentColor.opacity(0.6)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        }
    }

    private var version: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "0.6.0"
    }

    @ViewBuilder
    private func updateBanner(_ info: UpdateInfo) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(Color.accentColor)
            VStack(alignment: .leading, spacing: 2) {
                Text("Version \(info.version) is available")
                    .font(.headline)
                Text(info.notes)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if URL(string: info.url) != nil {
                Button {
                    vm.downloadUpdate()
                } label: {
                    Label("Download with Splynek", systemImage: "arrow.down.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .help("Fetch \(info.version) using Splynek's own multi-interface download engine.")
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.accentColor.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor.opacity(0.35), lineWidth: 0.5)
        )
    }

    /// Lightweight legal shortcuts — a quick pointer to the Legal pane
    /// for the three load-bearing docs. Keeps About visually lean.
    private var legalShortcutsCard: some View {
        TitledCard(title: "Your rights + responsibilities", systemImage: "doc.text") {
            HStack(spacing: 10) {
                Text("End-User Licence, Privacy Policy, and Acceptable Use — bundled into this app, viewable offline. See the *Legal* sidebar entry.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
        }
    }

    private var featuresGrid: some View {
        LazyVGrid(columns: [
            GridItem(.adaptive(minimum: 220), spacing: 16)
        ], spacing: 16) {
            FeatureTile(icon: "network", tint: .green,
                        title: "Multi-interface aggregation",
                        detail: "Ethernet, Wi-Fi, iPhone tether, Thunderbolt NICs — bound with IP_BOUND_IF.")
            FeatureTile(icon: "antenna.radiowaves.left.and.right", tint: .blue,
                        title: "Native BitTorrent",
                        detail: "HTTP + UDP trackers, DHT, PEX, magnet, multi-file, seeding.")
            FeatureTile(icon: "lock.shield.fill", tint: .purple,
                        title: "Per-interface DoH",
                        detail: "DNS resolved on the same lane the payload takes.")
            FeatureTile(icon: "checkmark.seal.fill", tint: .orange,
                        title: "Merkle integrity",
                        detail: "Per-chunk SHA-256 verification; bad chunks re-fetched inline.")
            FeatureTile(icon: "square.stack.3d.up", tint: .pink,
                        title: "Metalink mirrors",
                        detail: "Fan out across (mirror × interface), keep-alive preserved per lane.")
            FeatureTile(icon: "arrow.clockwise.circle", tint: .gray,
                        title: "Resume",
                        detail: "Sidecar state survives crashes and reboots.")
        }
    }
}

private struct FeatureTile: View {
    let icon: String
    let tint: Color
    let title: String
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(tint.opacity(0.14))
                )
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        )
    }
}
