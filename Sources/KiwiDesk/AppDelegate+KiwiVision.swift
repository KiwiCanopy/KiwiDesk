import AppKit
import Combine
import KiwiDeskCore

extension AppDelegate {
    /// Every GUI reader of KiwiVision's state or its lenses: the
    /// page, its picture, the Home subtitle and KiwiHub's chips.
    /// A new reader joins here, never one trigger's closure.
    func visionReadersChanged() {
        dashboardIfCreated?.model.objectWillChange.send()
        jumpPanel?.reloadViewIfShown()
    }

    /// KiwiVision (#2103): VoiceOver hears every change, whichever
    /// door made it.
    func wireKiwiVision() {
        // A verb or a chord may change the values from outside.
        core.onAppWideChange = { [weak self] in
            self?.visionReadersChanged()
        }
        var wasOn = core.kiwiVisionIsOn
        core.vision.onChange = { [weak self] active in
            self?.visionReadersChanged()
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
