import Foundation

/// User preferences storage for Simple/Power User settings mode (#678).
enum SettingsModePreference {
    static let key = "settingsMode"

    static func read(
        from defaults: UserDefaults
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
        to defaults: UserDefaults
    ) {
        if mode == .simple {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(mode.rawValue, forKey: key)
        }
    }
}
