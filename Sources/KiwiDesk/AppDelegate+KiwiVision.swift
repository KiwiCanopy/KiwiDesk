import AppKit
import KiwiDeskCore

extension AppDelegate {
    /// KiwiVision (#2103): the quick menu's row toggles it and
    /// VoiceOver hears every change, whichever door made it.
    func wireKiwiVision() {
        statusItem?.kiwiVisionProvider = { [weak self] in
            self?.core.kiwiVisionIsOn ?? false
        }
        statusItem?.kiwiVisionComboProvider = { [weak self] in
            guard let self else { return nil }
            return ShortcutsOpenBinding.combo(
                core: self.core,
                lua: KeybindingCatalog.toggleKiwiVision.lua
            )
        }
        statusItem?.onToggleKiwiVision = { [weak self] in
            self?.core.toggleKiwiVision()
        }
        core.vision.onChange = { on in
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
