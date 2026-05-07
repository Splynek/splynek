// Copyright © 2026 Splynek. MIT.
//
// RelayPolicy — pure decision logic for "should iOS submit via LAN
// or fall back to CloudKit?"
//
// The Share Extension's window is small (iOS gives extensions ~30s
// before forced termination), so we want a fast, deterministic
// answer.  The policy is:
//
//   1. Try LAN (PairedMacClient.queue).  Timeout = 5s.  If it
//      succeeds, we're done — fast path.
//
//   2. If LAN fails with .notReachable, .timeout, or any network
//      error (DNS, no route, connection-refused), AND the user has
//      enabled CloudKit relay in Settings, fall back to CloudKit.
//
//   3. If LAN fails with .unauthorised (the Mac rejected our
//      token), DO NOT fall back to CloudKit — re-pair is needed.
//      We surface the pairing error to the user instead.
//
//   4. If CloudKit fallback also fails, the Share Extension shows
//      the error and dismisses; the user can retry from the main
//      app (which has more headroom than the 30s extension window).
//
// This file is pure — no PairedMacClient / CloudKit imports — so
// the policy decisions are unit-tested without spinning up
// network.

import Foundation

public enum RelayPolicy {

    /// Caller passes this enum to describe the LAN attempt's
    /// outcome.  Mirrors `PairedMacClient.ClientError` cases plus
    /// a success variant.  Decoupled from the client type so this
    /// stays import-free.
    public enum LANOutcome: Equatable {
        case success
        case notReachable
        case timeout
        case unauthorised
        case other(httpStatus: Int)
    }

    public enum Decision: Equatable {
        /// LAN worked.  We're done; don't write to CloudKit.
        case done
        /// Fall back to CloudKit relay.  Caller invokes
        /// CloudKitRelaySubmitter.write(...).
        case fallbackToCloudKit
        /// Surface this user-facing error.  Don't try CloudKit
        /// (token rejection means re-pair is needed; CloudKit
        /// would just sit there pending forever).
        case surfaceError(message: String)
    }

    public static func decide(
        lanOutcome: LANOutcome,
        cloudKitRelayEnabled: Bool
    ) -> Decision {
        switch lanOutcome {
        case .success:
            return .done
        case .unauthorised:
            return .surfaceError(message:
                "Mac rejected the pairing token. Re-pair this Mac in Splynek Companion.")
        case .notReachable, .timeout, .other:
            if cloudKitRelayEnabled {
                return .fallbackToCloudKit
            } else {
                return .surfaceError(message:
                    "Couldn't reach the Mac and CloudKit relay is off. Turn it on in Settings or connect to the same Wi-Fi as your Mac.")
            }
        }
    }
}
