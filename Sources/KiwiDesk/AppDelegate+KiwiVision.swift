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
            // KiwiHub's lens chips read the lens list.
            self?.jumpPanel?.reloadViewIfShown()
        }
        var wasOn = core.kiwiVisionIsOn
        core.vision.onChange = { [weak self] active in
            // The Home card's subtitle reads the running state.
            self?.dashboardIfCreated?.model.objectWillChange.send()
            self?.jumpPanel?.reloadViewIfShown()
            // A switch between lenses is no on or off to announce.
            let on = active.isOn
            guard on != wasOn else { return }
            wasOn = on
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
