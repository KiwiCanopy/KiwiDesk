import AppKit

extension KiwiCore {
    /// `announceRefusal`'s live default: a VoiceOver announcement.
    /// `NSApp` is nil in a process with no `NSApplication`.
    static func postAnnouncement(_ text: String) {
        guard let app = NSApp else { return }
        NSAccessibility.post(
            element: app,
            notification: .announcementRequested,
            userInfo: [
                .announcement: text,
                .priority: NSAccessibilityPriorityLevel.high.rawValue,
            ]
        )
    }
}
