import Foundation
import KiwiDeskCore

extension SettingsModel {
    /// Suspends or resumes hotkeys while recording shortcut input
    /// (#213). A recording itself registers nothing: shortcuts
    /// take effect on Save, like every other setting.
    func setRecorderArmed(_ armed: Bool) {
        if armed {
            core.suspendHotkeysForRecording()
        } else {
            core.resumeHotkeysForRecording()
        }
    }
}
