import Foundation
import KiwiDeskCore

/// Immediate appearance preference handling for SettingsModel (#678).
extension SettingsModel {
    /// Persists the pick and immediately updates the appearance.
    func setAppearance(_ choice: AppearanceChoice) {
        AppearancePreference.write(choice, to: preferences)
        appearance = choice
        choice.apply()
    }
}
