import UserNotifications
#if os(macOS)
import AppKit

enum Notifications {
    private static var isAppBundle: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    static func requestAuthorizationIfNeeded() {
        guard isAppBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    static func show(text: String) {
        guard isAppBundle, !text.isEmpty else { return }
        let content = UNMutableNotificationContent()
        content.title = "OCR Copied"
        content.body = String(text.prefix(200))
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}

#endif
