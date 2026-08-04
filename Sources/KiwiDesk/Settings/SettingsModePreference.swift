import Foundation

/// Where the Simple/Power User pick lives (#678 turn 9).
///
/// Storage is app preferences (`UserDefaults`), NOT `gui.json`,
/// on exactly `AppearancePreference`'s reasoning: the mode is an
/// app-wide display choice, it is not part of a profile, and
/// writing it must never create a sidecar — that would flip
/// `KiwiCore.isGuiManaged` for a user who never adopted the GUI.
/// It also never enters the dirty-tracked config: the header
/// segment applies immediately and the footer's Save has nothing
/// to do with it.
///
/// Absent — and any unrecognised value — reads as `.simple`,
/// the approachable default; `.simple` removes the key so the
/// default leaves no trace in the domain.
enum SettingsModePreference {
    static let key = "settingsMode"

    static func read(
        from defaults: UserDefaults = .standard
    ) -> SettingsMode {
        guard
            let raw = defaults.string(forKey: key),
            let mode = SettingsMode(rawValue: raw)
        else {
            return .simple
        }
        return mode
    }

    static func write(
        _ mode: SettingsMode,
        to defaults: UserDefaults = .standard
    ) {
        if mode == .simple {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(mode.rawValue, forKey: key)
        }
    }
}
