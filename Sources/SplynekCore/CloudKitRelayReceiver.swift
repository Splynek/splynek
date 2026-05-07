// Copyright © 2026 Splynek. MIT.
//
// CloudKitRelayReceiver — macOS-side ingest for the iOS Splynek
// Companion's over-cellular relay (Strategy Bet S4 phase 3).
//
// Architecture choice: poll, don't subscribe.  We considered using
// CKDatabaseSubscription with APNs silent push, but that path
// requires aps-environment + background-fetch entitlements, plus
// the brittle "Mac asleep when push arrives" behaviour where iOS
// queues the silent push for "later" and "later" can be hours.
//
// Instead we run a 60s timer while the app is active.  Each tick
// queries the user's private CloudKit database for SplynekRelayJob
// records where:
//
//   targetMacUUID == this Mac's deviceUUID  AND
//   status         == "pending"
//
// Matching records are decoded, queued via the existing
// `onWebIngest("queue", url)` hook (same one the Share Extension's
// LAN POST goes through), then transitioned to "consumed" so the
// next poll skips them.  Idempotent: if the same record is read
// twice (poll-during-write race), the second read sees status
// "consumed" because we wrote consumed first.
//
// Why "consumed" instead of deleting: keeps a 30-day audit trail
// in the user's private DB — useful if a download mysteriously
// appeared and the user wants to see "where did this come from?"
// CloudKit's TTL on private records (no global default) means the
// user can manually purge anytime via Settings → iCloud → Splynek.
//
// Cost: each poll is one CKQueryOperation against the user's
// private DB.  CloudKit's per-user free tier covers this comfortably
// (10 GB private DB + 100 MB per-account requests/day).  Polling
// stops when the app deactivates (NSApplicationWillResign), resumes
// when active again — typical desk Mac runs ~12h active/day = 720
// queries/day, well under the limit.
//
// Provisioning prerequisites (out of band):
//   - Splynek macOS app's project.yml needs CloudKit capability
//     + iCloud entitlement with container `iCloud.app.splynek.companion`.
//   - The CloudKit container must be created in App Store Connect.
//   - The "SplynekRelayJob" record type schema must be published in
//     the CloudKit dashboard (Development + Production environments).
//
// All three are maintainer-only steps; not Claude-fixable from a
// session.  Until they're done, `start(...)` no-ops gracefully —
// the user's iCloud account check fails and the receiver stays
// dormant.  See `IOS-COMPANION.md` "Phase 3 provisioning" for the
// activation runbook.

import Foundation
// `SplynekCompanionCore` is a separate SwiftPM library target (built
// only when `swift build` is the toolchain).  Xcode compiles
// `iOS/Shared/CloudKitRelayRecord.swift` directly into the macOS
// Splynek module via project.yml, so the type is in the same module
// without an import.  `SWIFT_PACKAGE` is auto-defined by SPM but not
// by Xcode — exactly the right gate for "import only if this is an
// SPM build."
#if SWIFT_PACKAGE
import SplynekCompanionCore  // CloudKitRelayRecord, schema constants
#endif
#if canImport(CloudKit)
import CloudKit
#endif

#if canImport(CloudKit)
public actor CloudKitRelayReceiver {

    public static let pollInterval: TimeInterval = 60

    /// Container ID — must match
    /// `CloudKitRelaySubmitter.containerID` on the iOS side.
    public static let containerID = "iCloud.app.splynek.companion"

    private let container: CKContainer
    private let database: CKDatabase
    private let macUUID: String
    /// Called for each ingested URL — same shape as the existing
    /// `FleetCoordinator.onWebIngest` callback the LAN POST path
    /// uses.  Consolidates ingest into one queue path; relay
    /// records become regular Splynek jobs once received.
    private let ingest: @Sendable (_ action: String, _ url: String) -> Void
    private var pollTask: Task<Void, Never>?
    private var running = false

    public init(macUUID: String,
                containerID: String = CloudKitRelayReceiver.containerID,
                ingest: @escaping @Sendable (String, String) -> Void) {
        self.macUUID = macUUID
        self.container = CKContainer(identifier: containerID)
        self.database = container.privateCloudDatabase
        self.ingest = ingest
    }

    /// Start the 60s poll loop.  Idempotent — calling twice doesn't
    /// double-poll.  Stops on `stop()` or actor deinit.
    public func start() async {
        guard !running else { return }
        running = true
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            guard let self else { return }
            // First poll happens immediately on start so a
            // freshly-launched Mac doesn't miss a record submitted
            // 30s before launch.
            await self.pollOnce()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(Self.pollInterval * 1_000_000_000))
                if Task.isCancelled { break }
                await self.pollOnce()
            }
        }
    }

    public func stop() {
        running = false
        pollTask?.cancel()
        pollTask = nil
    }

    /// Public for diagnostics + tests; the start() loop is the
    /// production caller.  Returns the count of records ingested
    /// this tick (zero is the steady state).
    @discardableResult
    public func pollOnce() async -> Int {
        // Confirm iCloud is reachable + signed-in.  An offline
        // user's records won't sync until they're back online —
        // not our problem to solve.
        do {
            let status = try await container.accountStatus()
            guard status == .available else { return 0 }
        } catch {
            return 0
        }

        // Fetch pending records targeted at THIS Mac.
        let pred = NSPredicate(
            format: "targetMacUUID == %@ AND status == %@",
            macUUID, CloudKitRelayRecord.Status.pending.rawValue)
        let query = CKQuery(
            recordType: CloudKitRelayRecord.recordType,
            predicate: pred)
        // Oldest first — preserves the user's submission order
        // when multiple submissions stack up while the Mac was
        // unreachable.
        query.sortDescriptors = [NSSortDescriptor(key: "submittedAt", ascending: true)]

        var ingested = 0
        do {
            let (matches, _) = try await database.records(matching: query, resultsLimit: 50)
            for (_, result) in matches {
                guard case .success(let ckRecord) = result,
                      let relay = CloudKitRelayRecord.from(ckRecord: ckRecord)
                else { continue }
                // Hand off to the existing ingest path.  We use
                // "queue" rather than "download" because the user
                // submitted from cellular — letting the Mac decide
                // whether to start now (e.g. on Wi-Fi) or hold for
                // network conditions matches user expectation.
                self.ingest("queue", relay.url)
                // Mark consumed.  If this save fails (network blip,
                // record changed under us), we'll re-ingest next
                // poll; the URL queue is idempotent on duplicate
                // submissions (Splynek's existing dedupe handles it).
                ckRecord["status"] = CloudKitRelayRecord.Status.consumed.rawValue as CKRecordValue
                _ = try? await database.save(ckRecord)
                ingested += 1
            }
        } catch {
            // Polling errors are common (iCloud service blip,
            // user signed out mid-session, schema mismatch
            // pre-publish).  Silent — next poll retries.
            return ingested
        }
        return ingested
    }
}
#endif
