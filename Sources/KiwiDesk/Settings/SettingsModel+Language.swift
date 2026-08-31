import Foundation
import KiwiDeskCore

/// Immediate language preference application for SettingsModel
/// (#9): applies live, never dirty-tracked behind the footer
/// Save. Stored in `UserDefaults`, not `gui.json` — see
/// `LocalizationPreference` for why a sidecar must never be
/// created.
extension SettingsModel {
    /// Persists language selection and updates LocalizationManager
    /// (nil = system default).
    func setLanguage(_ language: String?) {
        LocalizationPreference.write(language)
        LocalizationManager.shared.select(language)
    }
}
