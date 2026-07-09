import Foundation
import KiwiDeskCore

/// The GUI language picker's write path (issue #9): unlike
/// every other setting in `config`, a language change is not
/// dirty-tracked behind the footer's Save — it applies live and
/// persists immediately, mirroring how the picker itself reads
/// as "already saved" the moment it changes. Storage is app
/// preferences (`UserDefaults`), not `gui.json` — a language
/// pick is documented as side-effect-free and must never create
/// a sidecar, which would flip `KiwiCore.isGuiManaged` for a
/// hand-written-Lua user who only wanted a different language.
extension SettingsModel {
    /// `nil` selects "System default".
    func setLanguage(_ language: String?) {
        LocalizationPreference.write(language)
        LocalizationManager.shared.select(language)
    }
}
