import SwiftUI

/// Speaks a sentence once for VoiceOver after
/// `SettingsFooter.announceDelay`: a post landing with a control's
/// own announcement is dropped (#812). The caller keeps the work
/// item and cancels it the moment the sentence stops being true.
enum DelayedAnnouncement {
    @MainActor
    static func schedule(_ sentence: String) -> DispatchWorkItem {
        let work = DispatchWorkItem {
            AccessibilityNotification.Announcement(sentence).post()
        }
        DispatchQueue.main.asyncAfter(
            deadline: .now() + SettingsFooter.announceDelay,
            execute: work
        )
        return work
    }
}
