// Copyright © 2026 Splynek. MIT.
//
// LiveActivityCoordinator — drives ActivityKit lifecycle from the
// iOS companion's polling loop.
//
// Lifecycle contract:
//
//   1. Every 2s, JobsView polls /splynek/v1/api/jobs and gets
//      [JobSummary].
//   2. JobsView passes the new snapshot to LiveActivityCoordinator.sync(...).
//   3. The coordinator diffs against the previous snapshot:
//        - New running jobs        → start an Activity
//        - Continuing running jobs → update the existing Activity
//        - Jobs no longer running  → end the Activity (with the
//                                    final-state ContentState so the
//                                    "finished" view stays on the
//                                    lock screen for a few seconds)
//
// Exposed as a pure transition layer — `Snapshot` + `decide(...)`
// are pure functions, easily unit-tested without ActivityKit.  The
// ActivityKit calls themselves live in the iOS-only execute(...)
// function, gated by `#if canImport(ActivityKit)` so this file
// compiles on macOS for the test runner.

import Foundation
#if canImport(ActivityKit)
import ActivityKit
#endif

public enum LiveActivityCoordinator {
    /// Pure description of an iOS device's currently-displayed
    /// Activities.  Maps `(macUUID, jobID)` → an opaque token (in
    /// production this is `Activity<DownloadActivityAttributes>.id`,
    /// but we keep the type opaque so this layer is testable on
    /// macOS without ActivityKit).
    public struct Snapshot: Equatable {
        public var activeKeys: Set<ActivityKey>

        public init(activeKeys: Set<ActivityKey> = []) {
            self.activeKeys = activeKeys
        }
    }

    /// Composite key — one Live Activity per (Mac, job) tuple, so
    /// two Macs running the same URL each get their own Activity.
    public struct ActivityKey: Hashable, Sendable {
        public let macUUID: String
        public let jobID: String

        public init(macUUID: String, jobID: String) {
            self.macUUID = macUUID
            self.jobID = jobID
        }
    }

    /// Output of `decide(...)`: the actions to apply to ActivityKit
    /// to bring the live snapshot into agreement with the polled
    /// jobs list.  Pure data; the iOS-side `execute(...)` performs
    /// the ActivityKit calls.
    public struct Plan: Equatable {
        public var toStart: [JobIdent]
        public var toUpdate: [JobIdent]
        public var toEnd:   [ActivityKey]

        public init(toStart: [JobIdent] = [],
                    toUpdate: [JobIdent] = [],
                    toEnd: [ActivityKey] = []) {
            self.toStart = toStart
            self.toUpdate = toUpdate
            self.toEnd = toEnd
        }

        public var isEmpty: Bool {
            toStart.isEmpty && toUpdate.isEmpty && toEnd.isEmpty
        }
    }

    /// Job identity + the data needed to populate the Activity's
    /// content state.  Filled in from JobSummary on the iOS side
    /// before reaching here.
    public struct JobIdent: Hashable, Sendable {
        public let key: ActivityKey
        public let phase: String
        public let displayName: String
        public let sourceURL: String
        public let downloaded: Int64
        public let total: Int64?
        public let throughputBps: Double
        public let etaSeconds: Int?

        public init(key: ActivityKey, phase: String, displayName: String,
                    sourceURL: String, downloaded: Int64, total: Int64?,
                    throughputBps: Double, etaSeconds: Int?) {
            self.key = key
            self.phase = phase
            self.displayName = displayName
            self.sourceURL = sourceURL
            self.downloaded = downloaded
            self.total = total
            self.throughputBps = throughputBps
            self.etaSeconds = etaSeconds
        }

        /// Phase strings the Mac sends ("running", "queued", etc.)
        /// → boolean "should we have a Live Activity for this?"
        ///
        /// Yes for running + paused (the user wants to know what's
        /// happening); no for queued (no progress to show yet),
        /// finished (let it animate off in 3s, not maintain a live
        /// instance), failed (error state — surfaced as a notification
        /// instead).
        public var deservesActivity: Bool {
            phase == "running" || phase == "paused"
        }
    }

    /// Diff `previous` against `current` to compute the Plan.  Pure
    /// function — no ActivityKit required, easily unit-tested on
    /// macOS.
    public static func decide(
        previous: Snapshot,
        current: [JobIdent]
    ) -> Plan {
        let activeNow: Set<ActivityKey> = Set(current
            .filter { $0.deservesActivity }
            .map { $0.key })

        let toStart = current
            .filter { $0.deservesActivity && !previous.activeKeys.contains($0.key) }
        let toUpdate = current
            .filter { $0.deservesActivity && previous.activeKeys.contains($0.key) }
        let toEnd = previous.activeKeys.subtracting(activeNow)

        return Plan(
            toStart: toStart,
            toUpdate: toUpdate,
            toEnd: Array(toEnd)
        )
    }

    /// Project the plan onto the next Snapshot (for unit-test
    /// chains — apply N decides + project after each, validate
    /// the steady state).
    public static func project(after plan: Plan, from previous: Snapshot) -> Snapshot {
        var keys = previous.activeKeys
        for ident in plan.toStart { keys.insert(ident.key) }
        for key in plan.toEnd     { keys.remove(key) }
        return Snapshot(activeKeys: keys)
    }
}
