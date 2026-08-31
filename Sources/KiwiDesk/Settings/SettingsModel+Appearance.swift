import Foundation
import KiwiDeskCore

/// Immediate appearance preference handling for SettingsModel (#678).
extension SettingsModel {
    /// Persists the pick and immediately updates the appearance.
    /// `.system` hands the decision back to macOS and leaves no
    /// key behind.
    func setAppearance(_ choice: AppearanceChoice) {
        AppearancePreference.write(choice, to: preferences)
        appearance = choice
        choice.apply()
    }
}
