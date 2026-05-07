// Copyright © 2026 Splynek. MIT.
//
// PairingHealth — pure status model for "is each paired Mac
// reachable right now?"
//
// Drives the Settings tab's per-Mac status row + the diagnostics
// "Test pairing" output.  Lives in iOS/Shared/ as pure logic so
// it's exercised by macOS unit tests without spinning up Bonjour
// or HTTP.
//
// Three status tiers:
//
//   • online    — Mac is in the live Bonjour discovery set right
//                 now.  The phone can reach it via LAN.
//   • recent    — Not in Bonjour, but the last successful API
//                 ping was within the last 24 hours.  Pairing is
//                 fine; the phone is just on a different network.
//                 CloudKit relay covers this case.
//   • stale     — No successful contact in 24+ hours.  Could mean
//                 the Mac is offline for an extended period, the
//                 token was rotated, or the user moved house.
//                 Settings UI nudges "Test pairing" to confirm.

import Foundation

public enum PairingHealth: String, Sendable, Equatable {
    case online    // visible on Bonjour
    case recent    // not visible, last seen within 24h
    case stale     // not visible, last seen > 24h ago

    public var displayLabel: String {
        switch self {
        case .online: return "On this Wi-Fi"
        case .recent: return "Reachable via iCloud"
        case .stale:  return "Not seen recently"
        }
    }
}

public enum PairingHealthEvaluator {

    /// Pure decision function — given a paired Mac's `lastSeen`
    /// timestamp, the live Bonjour-discovered UUID set, and "now",
    /// return the health tier.  Caller (a SwiftUI view) renders
    /// the appropriate badge.
    ///
    /// `recentThreshold` defaults to 24h.  Caller can override for
    /// testing (e.g. 60s) without flaky calendar arithmetic.
    public static func evaluate(
        macUUID: String,
        lastSeen: Date,
        bonjourUUIDs: Set<String>,
        now: Date = Date(),
        recentThreshold: TimeInterval = 86_400
    ) -> PairingHealth {
        if bonjourUUIDs.contains(macUUID) { return .online }
        let age = now.timeIntervalSince(lastSeen)
        if age <= recentThreshold { return .recent }
        return .stale
    }
}
