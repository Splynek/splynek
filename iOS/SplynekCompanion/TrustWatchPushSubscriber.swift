// Copyright © 2026 Splynek. MIT.
//
// TrustWatchPushSubscriber — iOS-side CloudKit subscription for
// Trust Watcher alerts published by the user's Pro Mac.
//
// Sprint 1 PRO-PLUS-IPHONE (2026-05-09).  Pairs with
// `Sources/SplynekCore/TrustWatcher/TrustWatchCloudKitNotifier.swift`.
//
// **Flow:**
//   1. App launch → `setUpSubscription()` ensures a single
//      CKQuerySubscription exists for the SplynekTrustWatchAlert
//      record type with `.firesOnRecordCreation`.
//   2. CloudKit delivers an APNs silent push (no app-server) when
//      a new record is written.
//   3. The push lands as a CKNotification; we fetch the matching
//      record, build a UNNotification with title/body from
//      `TrustWatchAlertNotification.notification(for:)`, and post
//      it locally.  Tapping the notification opens the Insights
//      tab.
//
// **Privacy / cost posture**: same as the existing CloudKit relay —
// scoped to the user's private database, encrypted by Apple,
// zero infrastructure on our side.  CloudKit's free per-user tier
// covers all subscriptions easily.
//
// **Provisioning prerequisite** (out of band): see
// `IOS-COMPANION.md` § "Phase 3 provisioning runbook" for the
// CKContainer + Schema setup.  This adds the SplynekTrustWatchAlert
// record type to the existing schema; no new container needed.
//
// **iOS deployment target**: 16.0 (matches the rest of Sprint 1).

#if canImport(SwiftUI) && canImport(CloudKit) && canImport(UserNotifications)
import Foundation
import CloudKit
import UserNotifications
import os

@available(iOS 16.0, *)
public final class TrustWatchPushSubscriber: NSObject {

    private static let log = Logger(
        subsystem: "app.splynek",
        category: "TrustWatchPush"
    )

    /// Stable subscription ID.  CloudKit dedupes on this across
    /// app re-installs / device migrations.
    public static let subscriptionID = "splynek-trust-watch-alerts-v1"

    /// Notification category — used to attach a "View page" action
    /// the user can tap directly from the banner.
    public static let categoryIdentifier = "splynek-trust-watch-alert"

    /// One-shot setup: ensures the subscription exists + asks for
    /// notification authorisation (idempotent).  Call once per
    /// app launch from `SplynekCompanionApp.onAppear` or similar.
    public static func setUpSubscription() async {
        // 1. Ask the user for notification permission (idempotent —
        //    iOS shows the prompt only the first time).  Failing
        //    here is fine; the rest of the flow still records the
        //    subscription, the user just won't see banners until
        //    they grant permission later.
        let center = UNUserNotificationCenter.current()
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            log.notice("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
        }
        // Register the notification category with a "View page"
        // action.  The action's URL is on the notification's
        // userInfo — see the AppDelegate / SceneDelegate handler.
        let viewAction = UNNotificationAction(
            identifier: "view-page",
            title: "View page",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: categoryIdentifier,
            actions: [viewAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])

        // 2. Ensure the CKQuerySubscription exists.  We don't care
        //    about idempotency edge cases — CloudKit's `save` of a
        //    subscription with the same ID is an upsert.
        let container = CKContainer.default()
        let db = container.privateCloudDatabase

        // Predicate: every new record (TRUEPREDICATE) — we don't
        // filter by sourceMacUUID server-side because we want the
        // user's iPhone to surface alerts from any of their Pro
        // Macs.  Filtering happens client-side if needed.
        let predicate = NSPredicate(value: true)
        let subscription = CKQuerySubscription(
            recordType: TrustWatchAlertRecord.recordType,
            predicate: predicate,
            subscriptionID: subscriptionID,
            options: [.firesOnRecordCreation]
        )

        // Build the silent-push payload.  We deliver locally via
        // didReceiveRemoteNotification — Apple's APNs handoff is
        // the transport, but the actual UNNotification is composed
        // client-side from the fetched CKRecord (see deliver()).
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        info.shouldBadge = true
        subscription.notificationInfo = info

        do {
            _ = try await db.save(subscription)
            log.info("TrustWatch CKQuerySubscription saved.")
        } catch let e as CKError where e.code == .serverRejectedRequest
                                   || e.code == .invalidArguments {
            // Most likely the subscription already exists.  Treat
            // as success — CloudKit doesn't expose a clean "exists"
            // probe and the duplicate-save error is well-known.
            log.info("TrustWatch subscription already registered (\(e.code.rawValue, privacy: .public)).")
        } catch {
            log.notice("Failed to register TrustWatch subscription: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// Handle a remote notification payload (forwarded from
    /// `application(_:didReceiveRemoteNotification:fetchCompletionHandler:)`).
    /// Fetches the referenced record + presents a local
    /// UNNotification.  Returns `.newData` when an alert was
    /// processed, `.noData` otherwise — feeds the
    /// `UIBackgroundFetchResult` callback.
    @discardableResult
    public static func handleRemoteNotification(_ userInfo: [AnyHashable: Any]) async -> Bool {
        guard let ckNotification = CKNotification(fromRemoteNotificationDictionary: userInfo)
        else { return false }
        guard let queryNotification = ckNotification as? CKQueryNotification,
              queryNotification.subscriptionID == subscriptionID,
              let recordID = queryNotification.recordID
        else { return false }

        let container = CKContainer.default()
        let db = container.privateCloudDatabase
        let record: CKRecord
        do {
            record = try await db.record(for: recordID)
        } catch {
            log.notice("Failed to fetch alert record \(recordID.recordName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return false
        }
        guard let payload = TrustWatchAlertRecord.from(record) else {
            log.notice("Alert record \(recordID.recordName, privacy: .public) failed to decode.")
            return false
        }
        await deliver(payload: payload)
        return true
    }

    /// Compose + post a local UNNotification.  Pure side-effect.
    /// Idempotent: iOS dedupes by identifier, and we use the
    /// CloudKit record ID so a repeated fetch doesn't double-pop.
    public static func deliver(payload: TrustWatchAlertRecord) async {
        let (title, body) = TrustWatchAlertNotification.notification(for: payload)
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = categoryIdentifier
        content.userInfo = [
            "alertID": payload.alertID,
            "pageURL": payload.pageURL,
            "sourceMacUUID": payload.sourceMacUUID
        ]
        let request = UNNotificationRequest(
            identifier: payload.id,
            content: content,
            trigger: nil   // immediate
        )
        do {
            try await UNUserNotificationCenter.current().add(request)
            log.info("Delivered Trust Watch alert \(payload.alertID, privacy: .public)")
        } catch {
            log.notice("Failed to deliver alert: \(error.localizedDescription, privacy: .public)")
        }
    }
}

#endif
