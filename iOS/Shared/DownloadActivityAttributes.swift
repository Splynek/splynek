// Copyright © 2026 Splynek. MIT.
//
// DownloadActivityAttributes — shared between the main companion app
// (which starts/updates/ends the Live Activity) and the
// SplynekCompanionWidgets extension (which renders the Activity's
// views on the lock screen + Dynamic Island).
//
// macOS 26 mirrors active iOS Live Activities into the Mac menu bar
// automatically when the iPhone is paired (per Apple's Continuity
// "Live Activity passthrough" feature).  This means a single ActivityKit
// implementation here unlocks BOTH:
//
//   • iPhone lock screen + Dynamic Island progress
//   • Mac menu bar progress chip
//
// — for free, no Mac-side widget code required.  This was the explicit
// thesis of Strategy Bet S4 in STRATEGY-2026.md.
//
// ActivityAttributes splits state into two layers:
//   - Fixed attributes (ActivityAttributes itself): set once at start,
//     never changes.  We use this for the source URL + filename + Mac
//     name — the things that identify the download.
//   - Dynamic state (ContentState nested type): updated repeatedly via
//     `Activity.update(...)`.  We use this for downloaded bytes /
//     total / throughput / phase / fractionComplete.

import Foundation
// ActivityKit imports + types are gated on `os(iOS)` rather than
// `canImport(ActivityKit)` because the module imports cleanly on
// macOS but its public protocols are `@available(macOS, unavailable)`,
// so any reference fails compilation.
#if os(iOS)
import ActivityKit

public struct DownloadActivityAttributes: ActivityAttributes, Sendable {
    /// Per-Activity dynamic content.  ActivityKit Codable + Hashable
    /// requirements come from `ActivityAttributes.ContentState`.
    public struct ContentState: Codable, Hashable, Sendable {
        public var phase: Phase
        public var downloaded: Int64
        public var total: Int64?           // nil = streaming / unknown total
        public var throughputBps: Double   // 0 = paused / queued
        public var etaSeconds: Int?

        public init(phase: Phase, downloaded: Int64, total: Int64?,
                    throughputBps: Double, etaSeconds: Int?) {
            self.phase = phase
            self.downloaded = downloaded
            self.total = total
            self.throughputBps = throughputBps
            self.etaSeconds = etaSeconds
        }

        public var fractionComplete: Double {
            guard let total, total > 0 else { return 0 }
            return min(1.0, Double(downloaded) / Double(total))
        }
    }

    public enum Phase: String, Codable, Hashable, Sendable {
        case queued
        case running
        case paused
        case finished
        case failed
    }

    /// The URL the user shared from the phone.  Useful for the
    /// expanded Dynamic Island view's "open source" affordance.
    public let sourceURL: String
    /// Display filename — falls back to URL-host if the Mac hasn't
    /// resolved a Content-Disposition yet.
    public let filename: String
    /// Mac that's actually downloading.  Shown in the lock-screen
    /// view ("on Paulo's MacBook") so multi-Mac households see which
    /// Mac took the job.
    public let macName: String
    /// Splynek job ID — used by the iOS app to dedupe between polls
    /// (one Activity per (mac, jobID) tuple).  Not displayed.
    public let jobID: String

    public init(sourceURL: String, filename: String, macName: String, jobID: String) {
        self.sourceURL = sourceURL
        self.filename = filename
        self.macName = macName
        self.jobID = jobID
    }
}
#endif
