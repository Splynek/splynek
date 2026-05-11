// Copyright © 2026 Splynek. MIT.
//
// SplynekCompanionApp — `@main` entry point for the iOS companion.
//
// This is the foundation skeleton (Strategy Bet S4 phase 1).  It
// proves the core thesis: Splynek Macs on the LAN appear here, you
// pair one with a token, and you can submit URLs + see job status.
//
// What this version does NOT include yet (planned for phase 2):
//   - Live Activity (ActivityKit) for download progress on the lock
//     screen + Dynamic Island + macOS 26 menu-bar mirror.
//   - QR-code scanner for pairing (manual paste only for now).
//   - CloudKit relay for over-cellular submission.
//
// What it DOES include:
//   - Bonjour discovery via `_splynek-fleet._tcp`.
//   - Token-paste pairing flow.
//   - Manual URL submission to a paired Mac.
//   - Active-jobs polling + display.
//   - Share Extension hooks (the extension is a separate target).

#if canImport(SwiftUI)
import SwiftUI
import UIKit

@main
struct SplynekCompanionApp: App {
    @UIApplicationDelegateAdaptor(SplynekCompanionAppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Sprint 1 PRO-PLUS-IPHONE (2026-05-09):
                    // register a CloudKit subscription for Trust
                    // Watcher alerts published by the user's Pro
                    // Mac + request notification permission.
                    // Idempotent across launches.
                    if #available(iOS 16.0, *) {
                        await TrustWatchPushSubscriber.setUpSubscription()
                    }
                    // Sprint 2 part-2 (2026-05-09): re-arm the
                    // geo-fence region after a reboot / re-install.
                    // No-op if the user hasn't opted in or hasn't
                    // set a home coordinate.
                    if #available(iOS 16.0, *) {
                        GeoFenceCoordinator.shared.enable()
                    }
                    // Sprint 9 / v2.0.1 polish (2026-05-11): activate
                    // the WatchConnectivity sender so the Watch app
                    // receives the current paired-Mac snapshot.  No-op
                    // on devices without a paired Watch.
                    PhoneWatchSync.shared.activate()
                    PhoneWatchSync.shared.push()
                }
        }
    }
}

/// AppDelegate handles the silent push CloudKit's CKQuerySubscription
/// fires when a Trust Watcher alert arrives.  Sprint 1 PRO-PLUS-IPHONE.
final class SplynekCompanionAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Register for remote notifications so APNs can deliver
        // CloudKit silent pushes.  Silent push needs no permission
        // prompt; the alert-permission prompt happens later in
        // TrustWatchPushSubscriber.setUpSubscription.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        if #available(iOS 16.0, *) {
            Task {
                let handled = await TrustWatchPushSubscriber
                    .handleRemoteNotification(userInfo)
                completionHandler(handled ? .newData : .noData)
            }
        } else {
            completionHandler(.noData)
        }
    }
}
#endif
