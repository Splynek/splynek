// Copyright © 2026 Splynek. MIT.
//
// LiveActivityDriver — the iOS-only thin wrapper that takes a
// LiveActivityCoordinator.Plan and applies it to ActivityKit.
//
// Lives in iOS/SplynekCompanion/ (NOT iOS/Shared/) because it
// needs ActivityKit + Foundation's iOS-side ActivityAuthorizationInfo,
// which we don't want polluting the SplynekCompanionCore SwiftPM
// library.  The pure decide/project logic stays in Shared/ where
// macOS tests exercise it.

#if os(iOS)
import ActivityKit
import Foundation

@MainActor
final class LiveActivityDriver {
    /// Maps each (macUUID, jobID) tuple to its corresponding
    /// `Activity<DownloadActivityAttributes>` so subsequent updates
    /// + ends find the right instance.
    private var activities: [LiveActivityCoordinator.ActivityKey:
                              Activity<DownloadActivityAttributes>] = [:]
    private var snapshot = LiveActivityCoordinator.Snapshot()
    private let macName: String
    private let macUUID: String

    init(mac: PairedMac) {
        self.macName = mac.displayName
        self.macUUID = mac.uuid
    }

    /// Sync against the currently-running job set.  Computes the
    /// Plan via the pure coordinator, then applies it.
    func sync(currentJobs: [JobSummary]) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            // User has Live Activities disabled in Settings.  No-op
            // gracefully — they still see the app's in-app job list.
            return
        }
        let idents = currentJobs.map { job in
            LiveActivityCoordinator.JobIdent(
                key: .init(macUUID: macUUID, jobID: job.id),
                phase: job.phase ?? "running",
                displayName: job.displayName,
                sourceURL: job.url,
                downloaded: job.downloaded ?? 0,
                total: job.total,
                throughputBps: job.throughputBps ?? 0,
                etaSeconds: nil
            )
        }
        let plan = LiveActivityCoordinator.decide(
            previous: snapshot, current: idents)
        if plan.isEmpty { return }

        for ident in plan.toStart { await start(ident) }
        for ident in plan.toUpdate { await update(ident) }
        for key in plan.toEnd { await end(key) }

        snapshot = LiveActivityCoordinator.project(after: plan, from: snapshot)
    }

    /// End every Activity this driver started — used when the user
    /// navigates away from the JobsView so we don't leak Activities
    /// into the lock screen indefinitely after the user has stopped
    /// looking.  The macOS-26 menu-bar mirror reflects this — the
    /// chip disappears within ~1s of the iOS side ending the activity.
    func endAll() async {
        for (_, activity) in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        activities.removeAll()
        snapshot = LiveActivityCoordinator.Snapshot()
    }

    // MARK: ActivityKit calls

    private func start(_ ident: LiveActivityCoordinator.JobIdent) async {
        let attrs = DownloadActivityAttributes(
            sourceURL: ident.sourceURL,
            filename: ident.displayName,
            macName: macName,
            jobID: ident.key.jobID
        )
        let state = DownloadActivityAttributes.ContentState(
            phase: phase(from: ident.phase),
            downloaded: ident.downloaded,
            total: ident.total,
            throughputBps: ident.throughputBps,
            etaSeconds: ident.etaSeconds
        )
        do {
            // iOS 16.2+: `.content(state, staleDate:)` form.  Stale
            // date 30s out so iOS dims the chip if our polls stop
            // (e.g. app went away on the LAN — the user shouldn't
            // see a stale 25%-progress chip forever).
            let activity = try Activity.request(
                attributes: attrs,
                content: .init(state: state, staleDate: Date().addingTimeInterval(30))
            )
            activities[ident.key] = activity
        } catch {
            // Common failure modes: Activities disabled in Settings,
            // user hit the rate limit (Apple caps simultaneous
            // Activities), or Info.plist is missing
            // NSSupportsLiveActivities.  Swallow — the in-app UI
            // continues to work.
        }
    }

    private func update(_ ident: LiveActivityCoordinator.JobIdent) async {
        guard let activity = activities[ident.key] else { return }
        let state = DownloadActivityAttributes.ContentState(
            phase: phase(from: ident.phase),
            downloaded: ident.downloaded,
            total: ident.total,
            throughputBps: ident.throughputBps,
            etaSeconds: ident.etaSeconds
        )
        await activity.update(.init(state: state,
                                    staleDate: Date().addingTimeInterval(30)))
    }

    private func end(_ key: LiveActivityCoordinator.ActivityKey) async {
        guard let activity = activities.removeValue(forKey: key) else { return }
        // Final-state for the dismissal animation.  Show "finished"
        // briefly before iOS's standard 4-hour Activity cleanup runs.
        let final = DownloadActivityAttributes.ContentState(
            phase: .finished,
            downloaded: 0, total: nil,
            throughputBps: 0, etaSeconds: nil
        )
        await activity.end(.init(state: final, staleDate: nil),
                           dismissalPolicy: .after(.now + 4))
    }

    private func phase(from raw: String) -> DownloadActivityAttributes.Phase {
        switch raw {
        case "queued":   return .queued
        case "running":  return .running
        case "paused":   return .paused
        case "finished": return .finished
        case "failed":   return .failed
        default:         return .running
        }
    }
}
#endif
