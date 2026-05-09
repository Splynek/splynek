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
#if canImport(CoreLocation)
import CoreLocation
#endif

struct SettingsView: View {
    @State private var paired: [PairedMac] = []
    @State private var bonjour: Set<String> = []
    @State private var browser = SplynekBonjourBrowser()
    @State private var relayEnabled: Bool = true
    @State private var probeResults: [String: ProbeResult] = [:]

    // Sprint 2 part-2 (2026-05-09): geo-fence state mirrors
    // PairedMacStore so toggling persists.  homeStatus is purely
    // for the "Home set / not set" label.
    @State private var geoFenceEnabled: Bool = false
    @State private var geoFenceHomeStatus: String = "Not set"
    @State private var geoFenceRadius: Double = 200

    private var store: PairedMacStore? { PairedMacStore() }

    // fileprivate (not private) so the file-private `MacRow` struct
    // below can declare a `probe: SettingsView.ProbeResult?` field.
    fileprivate struct ProbeResult {
        let success: Bool
        let detail: String
        let when: Date
    }

    var body: some View {
        Form {
            macsSection
            relaySection
            geoFenceSection
            aboutSection
        }
        .navigationTitle("Settings")
        .onAppear {
            refresh()
            relayEnabled = store?.cloudKitRelayEnabled ?? true
            geoFenceEnabled = store?.geoFenceEnabled ?? false
            geoFenceRadius = store?.geoFenceHomeRadius ?? 200
            geoFenceHomeStatus = store?.geoFenceHomeCoordinate == nil
                ? "Not set"
                : "Set"
            browser.start { discovered in
                bonjour = Set(discovered.map(\.uuid))
            }
        }
        .onDisappear { browser.stop() }
        .onChange(of: relayEnabled) { _, newValue in
            store?.cloudKitRelayEnabled = newValue
        }
        .onChange(of: geoFenceEnabled) { _, newValue in
            store?.geoFenceEnabled = newValue
            if #available(iOS 16.0, *) {
                if newValue {
                    GeoFenceCoordinator.shared.enable()
                } else {
                    GeoFenceCoordinator.shared.disable()
                }
            }
        }
        .onChange(of: geoFenceRadius) { _, newValue in
            store?.geoFenceHomeRadius = newValue
            if #available(iOS 16.0, *), geoFenceEnabled {
                // Re-register so the radius update takes effect.
                GeoFenceCoordinator.shared.enable()
            }
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

    // Sprint 2 part-2 (2026-05-09): Geo-fence section.  Toggle +
    // home-location capture + radius slider.  Behaviour wires
    // through PairedMacStore + GeoFenceCoordinator on
    // .onChange handlers in the body.
    @ViewBuilder
    private var geoFenceSection: some View {
        Section {
            Toggle("Pause downloads when I leave home", isOn: $geoFenceEnabled)
            HStack {
                Text("Home location")
                Spacer()
                Text(geoFenceHomeStatus)
                    .foregroundStyle(.secondary)
            }
            #if canImport(CoreLocation)
            Button {
                captureCurrentLocationAsHome()
            } label: {
                Label(geoFenceHomeStatus == "Set" ? "Update home to current location"
                                                  : "Use current location as home",
                      systemImage: "location.circle")
            }
            .disabled(!geoFenceEnabled)
            #endif
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Boundary radius")
                    Spacer()
                    Text("\(Int(geoFenceRadius)) m")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                Slider(value: $geoFenceRadius, in: 100...1000, step: 50)
                    .disabled(!geoFenceEnabled)
            }
        } header: {
            Text("Geo-fence")
        } footer: {
            Text(geoFenceEnabled
                 ? "Pauses every running download on your default Mac when you leave home; resumes when you arrive. Coordinates never leave the device — Splynek only sees \"you crossed the boundary\". Requires Location permission (set to Always to fire while the app is in the background)."
                 : "Off. Toggle on to set up automatic pause/resume around your home location.")
                .font(.caption)
        }
    }

    #if canImport(CoreLocation)
    private func captureCurrentLocationAsHome() {
        // Request a one-shot fix.  We don't keep CLLocationManager
        // alive in this view — the persistent monitor is in
        // GeoFenceCoordinator.  This is a single point-in-time
        // request whose result we write to PairedMacStore.
        let mgr = OneShotLocationFixer { coord in
            guard let coord = coord else { return }
            store?.geoFenceHomeCoordinate = (coord.latitude, coord.longitude)
            geoFenceHomeStatus = "Set"
            if #available(iOS 16.0, *), geoFenceEnabled {
                GeoFenceCoordinator.shared.enable()
            }
        }
        mgr.start()
        OneShotLocationFixer.retain(mgr)
    }
    #endif

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

// MARK: - Sprint 2 part-2: one-shot location fixer
//
// Used by the Settings UI's "Use current location as home" button.
// Owns a CLLocationManager just long enough to receive one fix,
// then self-destructs.  Kept small + isolated from the persistent
// GeoFenceCoordinator so the two responsibilities don't tangle.

#if canImport(CoreLocation)
import CoreLocation

@available(iOS 16.0, *)
final class OneShotLocationFixer: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let onFix: (CLLocationCoordinate2D?) -> Void
    private var fired = false

    /// Strong-reference holder to keep the fixer alive across the
    /// async location callback.  CLLocationManager doesn't retain
    /// its delegate, and SwiftUI's transient `.task` would deinit
    /// the fixer before the fix arrives.  Manual lifecycle.
    private static var inFlight: [OneShotLocationFixer] = []
    static func retain(_ fixer: OneShotLocationFixer) {
        inFlight.append(fixer)
    }

    init(onFix: @escaping (CLLocationCoordinate2D?) -> Void) {
        self.onFix = onFix
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    func start() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            finish(with: nil)
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            finish(with: nil)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            finish(with: nil)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager,
                         didUpdateLocations locations: [CLLocation]) {
        finish(with: locations.last?.coordinate)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        finish(with: nil)
    }

    private func finish(with coord: CLLocationCoordinate2D?) {
        guard !fired else { return }
        fired = true
        onFix(coord)
        // Drop self from the in-flight retainer so the fixer
        // deallocs after this callback returns.
        Self.inFlight.removeAll { $0 === self }
    }
}
#endif
#endif
