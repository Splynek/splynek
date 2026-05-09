// Copyright © 2026 Splynek. MIT.
//
// GeoFenceCoordinator — Sprint 2 part-2 (2026-05-09).
//
// Wraps `CLLocationManager` + a single `CLCircularRegion` (the
// user's "home") around the pure `GeoFencePolicy` decision logic
// in iOS/Shared/GeoFencePolicy.swift.
//
// **Behaviour**:
//   • At app launch, if the user has enabled geo-fence + set a
//     home coordinate, register the region with CoreLocation.
//   • CLLocationManagerDelegate.didEnter / didExit fire when the
//     phone crosses the 200 m boundary (default).
//   • Each transition is fed to GeoFencePolicy.action(...) along
//     with the most-recent stored event (cooldown logic).
//   • When the policy says .pauseAll / .resumeAll, dispatch via
//     PairedMacClient on the user's default paired Mac.
//
// **Authorization**:
//   • Geo-fencing requires `whenInUse` to register + `always` to
//     fire while the app is backgrounded.  Companion's flow:
//     ask `whenInUse` first; on success register the region; if
//     the user wants always-on (background firing) they enable a
//     toggle that triggers `requestAlwaysAuthorization`.
//   • If neither is granted, `enable()` quietly no-ops + Settings
//     UI shows an instruction to grant in System Settings.
//
// **Privacy posture**:
//   • Coordinates never leave the device.  Splynek doesn't see
//     them.  Only the boolean "you crossed the boundary" drives
//     the LAN call to PairedMacClient.
//   • The default radius (200 m) intentionally avoids
//     fingerprinting precision; user can tune up to 1000 m in
//     Settings.

#if canImport(SwiftUI) && canImport(CoreLocation)
import Foundation
import CoreLocation
import os

@available(iOS 16.0, *)
public final class GeoFenceCoordinator: NSObject, CLLocationManagerDelegate {

    public static let shared = GeoFenceCoordinator()

    private static let log = Logger(
        subsystem: "app.splynek",
        category: "GeoFence"
    )

    /// Stable identifier for the home region.  CLLocationManager
    /// dedupes per-id, so re-registering with the same id moves
    /// the region rather than adding a second one.
    public static let homeRegionID = "splynek-geofence-home"

    private let manager = CLLocationManager()
    private var lastEvent: GeoFenceEvent?
    private var pairedMacResolver: () -> PairedMac? = {
        guard let store = PairedMacStore() else { return nil }
        return store.all().sorted(by: { $0.lastSeen > $1.lastSeen }).first
    }

    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    }

    // MARK: Public API

    /// Begin monitoring the user's configured home region.  Reads
    /// from `PairedMacStore.geoFenceEnabled` + `geoFenceHomeCoordinate`.
    /// Idempotent — calling `enable()` twice in a row is fine.
    /// No-op if user hasn't set a home coordinate yet.
    public func enable() {
        guard let store = PairedMacStore() else { return }
        guard store.geoFenceEnabled,
              let home = store.geoFenceHomeCoordinate
        else {
            disable()
            return
        }
        // Auth — reaching whenInUse is enough to register; the
        // first didEnter/didExit will fire only with always.
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
            return  // wait for the delegate callback to register
        case .denied, .restricted:
            Self.log.notice("Geo-fence: location access denied; user must grant in Settings.")
            return
        default:
            break
        }
        let center = CLLocationCoordinate2D(
            latitude: home.latitude, longitude: home.longitude
        )
        let region = CLCircularRegion(
            center: center,
            radius: store.geoFenceHomeRadius,
            identifier: Self.homeRegionID
        )
        region.notifyOnEntry = true
        region.notifyOnExit = true
        // Stop monitoring any previous region for the same id —
        // CLLocationManager handles upsert by id, but be explicit.
        for r in manager.monitoredRegions where r.identifier == Self.homeRegionID {
            manager.stopMonitoring(for: r)
        }
        manager.startMonitoring(for: region)
        Self.log.info("Geo-fence: registered home region \(home.latitude, format: .fixed(precision: 4)),\(home.longitude, format: .fixed(precision: 4)) r=\(store.geoFenceHomeRadius, format: .fixed(precision: 0))m")
    }

    /// Stop monitoring all Splynek-owned regions.  Used when the
    /// user toggles geo-fence off in Settings.
    public func disable() {
        for r in manager.monitoredRegions where r.identifier == Self.homeRegionID {
            manager.stopMonitoring(for: r)
        }
        Self.log.info("Geo-fence: disabled")
    }

    /// Request the upgrade from `whenInUse` to `always`.  Called
    /// from a Settings UI button after the user has enabled the
    /// feature.  iOS shows the system dialog only once.
    public func requestAlwaysAuthorization() {
        manager.requestAlwaysAuthorization()
    }

    // MARK: CLLocationManagerDelegate

    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Self.log.info("Geo-fence: authorization changed to \(status.rawValue, privacy: .public)")
        switch status {
        case .authorizedWhenInUse, .authorizedAlways:
            // Authorization came in after a deferred enable() —
            // try registering now.
            self.enable()
        default:
            self.disable()
        }
    }

    public func locationManager(_ manager: CLLocationManager,
                                didEnterRegion region: CLRegion) {
        guard region.identifier == Self.homeRegionID else { return }
        handle(transition: .entered)
    }

    public func locationManager(_ manager: CLLocationManager,
                                didExitRegion region: CLRegion) {
        guard region.identifier == Self.homeRegionID else { return }
        handle(transition: .exited)
    }

    public func locationManager(_ manager: CLLocationManager,
                                monitoringDidFailFor region: CLRegion?,
                                withError error: Error) {
        Self.log.notice("Geo-fence: monitoring failed for \(region?.identifier ?? "?", privacy: .public) — \(error.localizedDescription, privacy: .public)")
    }

    // MARK: Internals

    /// Decide what to do with a fresh transition + dispatch.
    private func handle(transition: GeoFenceTransition) {
        let action = GeoFencePolicy.action(
            for: transition, lastEvent: lastEvent
        )
        // Update the dedup state regardless of what the action is —
        // the noOp case still updates lastEvent so a *third*
        // bounce-back re-fires correctly.
        lastEvent = GeoFenceEvent(transition: transition, timestamp: Date())
        switch action {
        case .noOp:
            Self.log.info("Geo-fence: \(transition.rawValue, privacy: .public) within cooldown — no action")
            return
        case .pauseAll:
            dispatch(.pauseAll)
        case .resumeAll:
            dispatch(.resumeAll)
        }
    }

    private enum DispatchKind { case pauseAll, resumeAll }

    private func dispatch(_ kind: DispatchKind) {
        guard let mac = pairedMacResolver() else {
            Self.log.notice("Geo-fence: no paired Mac; skipping \(String(describing: kind), privacy: .public)")
            return
        }
        Task {
            let client = PairedMacClient(mac: mac)
            do {
                switch kind {
                case .pauseAll:  try await client.pauseAll()
                case .resumeAll: try await client.resumeAll()
                }
                Self.log.info("Geo-fence: \(String(describing: kind), privacy: .public) succeeded on \(mac.displayName, privacy: .public)")
            } catch {
                Self.log.notice("Geo-fence: \(String(describing: kind), privacy: .public) failed on \(mac.displayName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

#endif
