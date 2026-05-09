import Foundation
#if canImport(CloudKit)
import CloudKit
#endif
import os
import SplynekCompanionCore

/// Publishes Trust Watcher alerts to the user's *private* CloudKit
/// database so the iPhone Companion can surface them as push
/// notifications (via a CKQuerySubscription on the iOS side).
///
/// Sprint 1 PRO-PLUS-IPHONE (2026-05-09).
///
/// **Wiring**: TrustWatchService.runOnce() returns an `[TrustWatchAlert]`
/// of newly-emitted alerts.  The ViewModel forwards each to
/// `TrustWatchCloudKitNotifier.publish(alerts:)`.  Idempotent — the
/// CKRecord ID is `alertID`, so a re-publish of the same alert
/// upserts rather than duplicates on CloudKit's side.
///
/// **Pro-gating**: The notifier is only constructed for Pro Macs.
/// Free-tier never opens a CKContainer connection.
///
/// **Privacy posture**: same as the existing CloudKitRelayReceiver
/// — uses the user's own private database (`CKContainer.default()
/// .privateCloudDatabase`).  No remote service we run, no telemetry,
/// no backend.  Apple's at-rest + in-transit encryption applies.
///
/// **Failure mode**: when the Mac has no iCloud account or the
/// container isn't provisioned (maintainer step in App Store
/// Connect), `publish(alerts:)` logs a warning and returns
/// gracefully.  The local TrustWatcher UI still surfaces the
/// alert; only the iPhone push fails.
public actor TrustWatchCloudKitNotifier {

    private static let log = Logger(
        subsystem: "app.splynek",
        category: "TrustWatchCloudKit"
    )

    /// `FleetCoordinator.deviceUUID` of the writing Mac.  Goes into
    /// `sourceMacUUID` on the record so the iPhone can filter
    /// subscriptions per-paired-Mac (rare but supported case: the
    /// user owns multiple Pro Macs, all writing alerts).
    private let sourceMacUUID: String

    public init(sourceMacUUID: String) {
        self.sourceMacUUID = sourceMacUUID
    }

    /// Publish a batch of new alerts to the user's private DB.
    /// Returns the records that were *successfully* saved (so the
    /// caller can update UI counters or telemetry — neither of
    /// which we ship today).
    @discardableResult
    public func publish(alerts: [TrustWatchAlert]) async -> [TrustWatchAlertRecord] {
        guard !alerts.isEmpty else { return [] }
        #if canImport(CloudKit)
        let container = CKContainer.default()
        // accountStatus tells us whether the Mac has an iCloud
        // account and whether CloudKit is reachable.  Skip silently
        // when not ready — local UI alerts still work.
        let status: CKAccountStatus
        do {
            status = try await container.accountStatus()
        } catch {
            Self.log.notice("CloudKit account status unavailable: \(error.localizedDescription, privacy: .public)")
            return []
        }
        guard status == .available else {
            Self.log.notice("CloudKit account not available (\(status.rawValue, privacy: .public)); skipping alert publish.")
            return []
        }
        let db = container.privateCloudDatabase
        var saved: [TrustWatchAlertRecord] = []
        for alert in alerts {
            let record = TrustWatchAlertRecord(
                alertID: alert.id,
                sourceMacUUID: sourceMacUUID,
                targetAppName: alert.target.displayName,
                policyKind: alert.target.kind.label,
                severity: alert.severity.rawValue,
                pageURL: alert.target.url.absoluteString,
                observedAt: parseObservedAt(alert.observedAt) ?? Date(),
                acknowledged: alert.acknowledged
            )
            let ck = record.toCKRecord()
            do {
                _ = try await db.save(ck)
                saved.append(record)
                Self.log.info("Published Trust Watcher alert \(alert.id, privacy: .public)")
            } catch let e as CKError where e.code == .unknownItem {
                // Schema not yet promoted to production — fail loudly
                // in development, gently in prod.
                Self.log.notice("CloudKit schema missing SplynekTrustWatchAlert: \(e.localizedDescription, privacy: .public)")
            } catch {
                Self.log.notice("Failed to publish Trust Watcher alert \(alert.id, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        return saved
        #else
        // CloudKit unavailable on this build — caller already
        // logged the alert locally.
        return []
        #endif
    }

    /// ISO-8601 string → Date.  Used to translate the Trust
    /// Watcher's wire-stable string timestamp into a CKRecord-
    /// compatible Date.  Falls back to Date() on parse failure
    /// (keeps the record valid; the local store is the source of
    /// truth anyway).
    private func parseObservedAt(_ s: String) -> Date? {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: s)
    }
}
