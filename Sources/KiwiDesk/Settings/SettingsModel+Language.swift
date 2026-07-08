import Foundation
import KiwiDeskCore

/// The GUI language picker's write path (issue #9): unlike
/// every other setting in `config`, a language change is not
/// dirty-tracked behind the footer's Save — it applies live and
/// persists immediately, mirroring how the picker itself reads
/// as "already saved" the moment it changes.
extension SettingsModel {
    /// `nil` selects "System default".
    func setLanguage(_ language: String?) {
        config.language = language
        cleanConfig.language = language
        LocalizationManager.shared.select(language)
        do {
            try core.saveLanguage(language)
        } catch {
            core.onLog("language save failed: \(error)")
        }
    }
}
