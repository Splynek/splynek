// Copyright © 2026 Splynek. MIT.
//
// PhoneWatchReceiver — Watch-side WatchConnectivity receiver.
//
// Counterpart to `PhoneWatchSync` on the iPhone Companion.  On every
// `applicationContext` delivery, decode the `[PairedMac]` snapshot
// and reconcile it into the Watch's local `PairedMacStore`
// (App Group plist + Watch keychain).  Posts
// `.pairedMacsDidChange` on the main NotificationCenter so the
// SwiftUI view re-fetches.
//
// Sprint 9 / v2.0.1 polish (2026-05-11).

#if os(watchOS) && canImport(WatchConnectivity)

import Foundation
import WatchConnectivity

public extension Notification.Name {
    /// Posted on the main queue whenever an iPhone → Watch sync
    /// updates the local PairedMacStore.
    static let pairedMacsDidChange = Notification.Name("splynek.watch.pairedMacsDidChange")
}

@MainActor
public final class PhoneWatchReceiver: NSObject, WCSessionDelegate {
    public static let shared = PhoneWatchReceiver()
    private override init() { super.init() }

    /// Call once on app launch.  Idempotent.
    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Reconcile incoming context into PairedMacStore.  Upsert each
    /// incoming Mac; remove anything we have locally that isn't in
    /// the incoming snapshot (handles unpair on the iPhone).
    private func apply(context: [String: Any]) {
        guard let data = context[WatchSyncKeys.pairedMacsV1] as? Data,
              let incoming = try? JSONDecoder().decode([PairedMac].self, from: data),
              let store = PairedMacStore() else { return }

        let incomingUUIDs = Set(incoming.map { $0.uuid })
        let existing = store.all()
        for record in incoming { _ = store.upsert(record) }
        for stale in existing where !incomingUUIDs.contains(stale.uuid) {
            store.remove(uuid: stale.uuid)
        }

        NotificationCenter.default.post(name: .pairedMacsDidChange, object: nil)
    }

    // MARK: WCSessionDelegate

    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        guard state == .activated else { return }
        // Apply any context already received during activation
        // (the system caches the most recent one).
        let snapshot = session.receivedApplicationContext
        if !snapshot.isEmpty {
            Task { @MainActor in self.apply(context: snapshot) }
        }
    }

    public nonisolated func session(
        _ session: WCSession,
        didReceiveApplicationContext applicationContext: [String : Any]
    ) {
        Task { @MainActor in self.apply(context: applicationContext) }
    }
}

#endif
