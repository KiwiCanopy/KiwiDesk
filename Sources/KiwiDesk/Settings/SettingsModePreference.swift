import Foundation

/// Simple/Power User mode storage (#678): `UserDefaults`, NOT
/// `gui.json` — an app-wide display choice, not profile data,
/// and writing it must never create a sidecar (that would flip
/// `KiwiCore.isGuiManaged` for a user who never adopted the
/// GUI). Absent or unrecognised reads `.simple`; picking
/// `.simple` removes the key.
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
