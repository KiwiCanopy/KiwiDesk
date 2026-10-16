import AppKit
import Combine
import KiwiDeskCore

extension AppDelegate {
    /// KiwiVision (#2103): VoiceOver hears every change, whichever
    /// door made it.
    func wireKiwiVision() {
        // The page, its picture and the Home subtitle read the
        // live values, which a verb may change from outside.
        core.onAppWideChange = { [weak self] in
            self?.dashboardIfCreated?.model.objectWillChange.send()
        }
        core.vision.onChange = { [weak self] on in
            // The Home card's subtitle reads the running state.
            self?.dashboardIfCreated?.model.objectWillChange.send()
            NSAccessibility.post(
                element: NSApp as Any,
                notification: .announcementRequested,
                userInfo: [
                    .announcement: on
                        ? L("kiwivision.announce.on", "KiwiVision on")
                        : L("kiwivision.announce.off", "KiwiVision off"),
                    .priority:
                        NSAccessibilityPriorityLevel.high.rawValue,
                ]
            )
        }
    }
}
