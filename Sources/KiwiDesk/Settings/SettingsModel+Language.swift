import Foundation
import KiwiDeskCore

/// Immediate language preference application for SettingsModel (#9).
extension SettingsModel {
    /// Persists language selection and updates LocalizationManager
    /// (nil = system default).
    func setLanguage(_ language: String?) {
        LocalizationPreference.write(language)
        LocalizationManager.shared.select(language)
    }
}
