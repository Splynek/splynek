// Copyright © 2026 Splynek. MIT.
//
// GeoFencePolicy — Sprint 2 scaffold (2026-05-09).
//
// Pure decision logic for the iOS Companion's geo-fence:
// "leaving home → pause Splynek; arriving home → resume Splynek".
//
// This file is the **decision layer**.  No CoreLocation calls
// happen here — the iOS-side `GeoFenceCoordinator` (Sprint 2
// part 2) wraps CLLocationManager + CLCircularRegion +
// CLLocationManagerDelegate around this pure logic.
//
// **What's here**:
//   - `GeoFenceTransition` — leaving / arriving, pure enum
//   - `GeoFencePolicy.action(for:lastEvent:cooldownSeconds:)` —
//     decides whether a region transition should trigger an action
//     given dedupe / cooldown invariants
//
// **What's not here** (Sprint 2 part 2):
//   - `GeoFenceCoordinator` — CLLocationManager wrapper that
//     watches the user's "home" region and posts events to the
//     pure policy
//   - UI in `iOS/SplynekCompanion/SettingsView.swift` to set the
//     home region (one button: "Use my current location as home")
//   - The wiring that translates a `GeoFenceAction.pauseAll`
//     into a `PairedMacClient.pauseAll()` call
//
// **Privacy posture**:
//   - Geofence radius defaults to 200m (typical city block).
//   - We never send location off-device; only "you're home" /
//     "you're not home" booleans drive PairedMacClient calls.
//   - User can disable the feature in Settings; CLLocationManager
//     authorization is requested explicitly.

import Foundation

/// Direction of a geo-fence transition.
public enum GeoFenceTransition: String, Codable, Sendable {
    case entered      // crossed into the home region
    case exited       // crossed out of the home region
}

/// Decision the policy emits for a transition.
public enum GeoFenceAction: Equatable, Sendable {
    /// Pause all running downloads on the user's default Mac.
    case pauseAll
    /// Resume all paused downloads on the user's default Mac.
    case resumeAll
    /// Suppress — within cooldown window, ignore.  Used after a
    /// rapid in-then-out bounce that's the user pacing on their
    /// front step rather than genuinely leaving.
    case noOp
}

/// Per-event audit row for the policy.  Stored client-side so the
/// UI can show "geo-fence fired 3 times today".
public struct GeoFenceEvent: Codable, Hashable, Sendable {
    public let transition: GeoFenceTransition
    public let timestamp: Date

    public init(transition: GeoFenceTransition, timestamp: Date) {
        self.transition = transition
        self.timestamp = timestamp
    }
}

public enum GeoFencePolicy {

    /// Default cooldown — within this window, repeated transitions
    /// are no-ops.  Catches "user paces in front of the door".
    public static let defaultCooldownSeconds: TimeInterval = 60

    /// Decide what to do when a transition arrives.
    ///
    /// - Parameters:
    ///   - transition: the new transition CoreLocation just emitted
    ///   - lastEvent: the most-recent stored transition (or nil
    ///     if this is the first event since launch)
    ///   - now: clock for timestamp comparison; default = Date()
    ///   - cooldownSeconds: dedupe window; default
    ///     `defaultCooldownSeconds`
    /// - Returns: the action the runner should perform
    public static func action(
        for transition: GeoFenceTransition,
        lastEvent: GeoFenceEvent?,
        now: Date = Date(),
        cooldownSeconds: TimeInterval = defaultCooldownSeconds
    ) -> GeoFenceAction {
        if let last = lastEvent,
           now.timeIntervalSince(last.timestamp) < cooldownSeconds,
           last.transition == transition {
            // Same direction within cooldown → ignore
            // (CoreLocation sometimes double-fires).
            return .noOp
        }
        switch transition {
        case .exited:   return .pauseAll
        case .entered:  return .resumeAll
        }
    }
}
