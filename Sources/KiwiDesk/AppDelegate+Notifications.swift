import AppKit
import KiwiDeskCore
@preconcurrency import UserNotifications

extension AppDelegate {
    /// Posts a system notification about revoked permission.
    /// `UNUserNotificationCenter` requires a real app bundle, so
    /// bare SwiftPM executables fall back to logging only.
    func notifyPermissionLost() {
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog(
                "KiwiDesk: Accessibility permission revoked; "
                    + "window management paused."
            )
            return
        }
        // Resolved on the main actor before the completion
        // handler, which runs on an arbitrary queue and can't
        // call the main-actor-isolated `L()`.
        let title = L(
            "notification.permission_lost.title",
            "KiwiDesk stopped managing windows"
        )
        let body = L(
            "notification.permission_lost.body",
            "Accessibility permission was revoked. "
                + "Re-enable it in System Settings > "
                + "Privacy & Security > Accessibility."
        )
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(
            options: [.alert]
        ) { granted, _ in
            guard granted else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            let request = UNNotificationRequest(
                identifier: "kiwidesk.permission-lost",
                content: content,
                trigger: nil
            )
            center.add(request)
        }
    }
}
