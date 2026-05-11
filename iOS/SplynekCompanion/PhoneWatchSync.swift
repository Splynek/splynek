// Copyright © 2026 Splynek. MIT.
//
// PhoneWatchSync — iPhone → Watch state pipe over WatchConnectivity.
//
// Without this glue the Watch app's `PairedMacStore` always returns
// an empty list — App Group containers are NOT shared between paired
// iOS and watchOS devices.  This file is the missing pipe: on
// activation, and on every PairedMacStore mutation, push the current
// paired-Mac list to the Watch via WCSession.updateApplicationContext.
//
// Sprint 9 / v2.0.1 polish (2026-05-11).
//
// **Why `updateApplicationContext`** (not `transferUserInfo` /
// `sendMessage`)?
//   - Coalescing: we only need the LATEST list, not every historical
//     mutation.  If the user pairs–unpairs–repairs while the Watch
//     is off-wrist, the Watch should see the final state.
//   - Background-delivered: arrives even if the Watch app isn't
//     running, queued and applied the next time it does.
//   - Idempotent: re-sending the same context is cheap.
//
// **Token handling**: tokens ARE in the payload.  WatchConnectivity
// transport is end-to-end encrypted via Apple's secure-pairing
// channel and a paired Watch is part of the user's trust domain.
// The Watch writes the token to its OWN keychain on receipt; same
// lifecycle as the iPhone keychain.

#if os(iOS) && canImport(WatchConnectivity)

import Foundation
import WatchConnectivity

@MainActor
public final class PhoneWatchSync: NSObject, WCSessionDelegate {
    public static let shared = PhoneWatchSync()
    private override init() { super.init() }

    /// Call once on app launch.  Idempotent.
    public func activate() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        session.delegate = self
        session.activate()
    }

    /// Push the current `PairedMacStore` snapshot to the Watch.
    /// Call after every mutation (pair / unpair / rename) and once
    /// on app foregrounding for good measure.  Best-effort.
    public func push() {
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        guard session.activationState == .activated else { return }
        guard session.isPaired, session.isWatchAppInstalled else { return }
        guard let store = PairedMacStore() else { return }

        let macs = store.all()
        guard let data = try? JSONEncoder().encode(macs) else { return }

        // Apple's API surfaces a throwing call here.  Errors are rare
        // and indistinguishable from "Watch off-wrist" — best-effort
        // is the right posture.
        try? session.updateApplicationContext([
            WatchSyncKeys.pairedMacsV1: data
        ])
    }

    // MARK: WCSessionDelegate

    public nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith state: WCSessionActivationState,
        error: Error?
    ) {
        guard state == .activated else { return }
        Task { @MainActor in self.push() }
    }

    public nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    public nonisolated func sessionDidDeactivate(_ session: WCSession) {
        // Apple requires re-activation after the user switches Watches.
        WCSession.default.activate()
    }
}

#endif
