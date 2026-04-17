import Foundation
import UserNotifications

/// Thin wrapper around `UNUserNotificationCenter` for posting completion
/// toasts. The first call lazily requests permission; subsequent calls
/// silently no-op if the user denied it.
enum Notifier {

    private static var authorized: Bool = false
    private static var askedOnce = false

    static func ensureAuthorized() async {
        let center = UNUserNotificationCenter.current()
        if askedOnce {
            let settings = await center.notificationSettings()
            authorized = (settings.authorizationStatus == .authorized ||
                          settings.authorizationStatus == .provisional)
            return
        }
        askedOnce = true
        do {
            authorized = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            authorized = false
        }
    }

    static func post(title: String, body: String, subtitle: String? = nil) {
        Task {
            await ensureAuthorized()
            guard authorized else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            if let subtitle { content.subtitle = subtitle }
            content.body = body
            content.sound = .default
            let req = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content, trigger: nil
            )
            try? await UNUserNotificationCenter.current().add(req)
        }
    }
}
