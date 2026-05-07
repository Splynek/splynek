// Copyright © 2026 Splynek. MIT.
//
// SettingsView — third tab on the iOS Splynek Companion.
//
// Sections:
//   1. Paired Macs   — per-Mac health row + test-pairing probe
//   2. Relay         — cloudKitRelayEnabled toggle + explainer
//   3. About         — app version, link to docs, ack
//
// Bonjour discovery runs while this view is on screen so the
// "On this Wi-Fi" badges flip live.  The probe button performs a
// `/splynek/v1/status` round-trip and surfaces the result inline
// (latency in ms or the failure reason) — same path
// `PairingSheet.attempt()` uses on save, so a green probe here
// means the LAN submission flow will work.

#if canImport(SwiftUI)
import SwiftUI

struct SettingsView: View {
    @State private var paired: [PairedMac] = []
    @State private var bonjour: Set<String> = []
    @State private var browser = SplynekBonjourBrowser()
    @State private var relayEnabled: Bool = true
    @State private var probeResults: [String: ProbeResult] = [:]

    private var store: PairedMacStore? { PairedMacStore() }

    private struct ProbeResult {
        let success: Bool
        let detail: String
        let when: Date
    }

    var body: some View {
        Form {
            macsSection
            relaySection
            aboutSection
        }
        .navigationTitle("Settings")
        .onAppear {
            refresh()
            relayEnabled = store?.cloudKitRelayEnabled ?? true
            browser.start { discovered in
                bonjour = Set(discovered.map(\.uuid))
            }
        }
        .onDisappear { browser.stop() }
        .onChange(of: relayEnabled) { _, newValue in
            store?.cloudKitRelayEnabled = newValue
        }
    }

    // MARK: Sections

    @ViewBuilder
    private var macsSection: some View {
        Section {
            if paired.isEmpty {
                Text("No Macs paired yet. Add one from the Macs tab.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(paired) { mac in
                    MacRow(
                        mac: mac,
                        health: PairingHealthEvaluator.evaluate(
                            macUUID: mac.uuid,
                            lastSeen: mac.lastSeen,
                            bonjourUUIDs: bonjour),
                        probe: probeResults[mac.uuid],
                        onProbe: { Task { await probe(mac) } }
                    )
                }
            }
        } header: {
            Text("Paired Macs")
        } footer: {
            if !paired.isEmpty {
                Text("Tap Test pairing to send a /status request and confirm the token + LAN route are healthy.")
            }
        }
    }

    @ViewBuilder
    private var relaySection: some View {
        Section {
            Toggle("Send via iCloud when off Wi-Fi", isOn: $relayEnabled)
        } header: {
            Text("Relay")
        } footer: {
            Text(relayEnabled
                 ? "When the iPhone can't reach the Mac over Wi-Fi, the URL is sent through your private iCloud database. The Mac picks it up within 60 seconds the next time it polls. Nothing leaves your iCloud account."
                 : "URLs only send over local Wi-Fi. Submissions fail when the Mac is unreachable."
            )
            .font(.caption)
        }
    }

    @ViewBuilder
    private var aboutSection: some View {
        Section {
            HStack {
                Text("Version")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            HStack {
                Text("Build")
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—")
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Link("splynek.app",
                 destination: URL(string: "https://splynek.app")!)
        } header: {
            Text("About")
        }
    }

    // MARK: Actions

    private func refresh() {
        paired = store?.all() ?? []
    }

    @MainActor
    private func probe(_ mac: PairedMac) async {
        let started = Date()
        do {
            _ = try await PairedMacClient(mac: mac).ping()
            let ms = Int(Date().timeIntervalSince(started) * 1000)
            probeResults[mac.uuid] = ProbeResult(
                success: true,
                detail: "OK — \(ms) ms",
                when: Date()
            )
            // Update lastSeen on success.
            var updated = mac
            updated.lastSeen = Date()
            store?.upsert(updated)
            refresh()
        } catch PairedMacClient.ClientError.unauthorised {
            probeResults[mac.uuid] = ProbeResult(
                success: false,
                detail: "Token rejected — re-pair this Mac.",
                when: Date()
            )
        } catch {
            probeResults[mac.uuid] = ProbeResult(
                success: false,
                detail: "Unreachable — \(error.localizedDescription)",
                when: Date()
            )
        }
    }
}

// MARK: - MacRow

private struct MacRow: View {
    let mac: PairedMac
    let health: PairingHealth
    let probe: SettingsView.ProbeResult?
    let onProbe: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Circle()
                    .fill(healthColor)
                    .frame(width: 10, height: 10)
                VStack(alignment: .leading, spacing: 2) {
                    Text(mac.displayName)
                        .font(.body)
                    Text(health.displayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Test pairing", action: onProbe)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
            if let probe {
                HStack(spacing: 6) {
                    Image(systemName: probe.success
                          ? "checkmark.circle.fill"
                          : "exclamationmark.triangle.fill")
                        .foregroundStyle(probe.success ? .green : .orange)
                    Text(probe.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var healthColor: Color {
        switch health {
        case .online: return .green
        case .recent: return .blue
        case .stale:  return .gray.opacity(0.5)
        }
    }
}
#endif
