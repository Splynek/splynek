// Copyright © 2026 Splynek. MIT.
//
// WatchSyncConstants — application-context keys shared by the iPhone
// sender (`PhoneWatchSync`) + Watch receiver (`PhoneWatchReceiver`).
//
// Pure constants, no WatchConnectivity import — safe for every target
// that inlines `iOS/Shared` (Companion, Share Extension, Widgets,
// Watch, Watch Complications).

import Foundation

public enum WatchSyncKeys {
    /// Application-context key carrying a JSON-encoded `[PairedMac]`
    /// snapshot.  Versioned (`_v1`) so a future schema rev can land
    /// beside it without breaking old Watch builds.
    public static let pairedMacsV1 = "splynek.paired_macs_v1"
}
