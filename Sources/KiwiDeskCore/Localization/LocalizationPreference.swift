import Foundation

/// GUI language preference stored in `UserDefaults`, NOT
/// `gui.json` (#9): a language change is documented as
/// side-effect-free and must never create a sidecar — that
/// would flip `KiwiCore.isGuiManaged` and hand config
/// ownership to the structured loader for a hand-written-Lua
/// user who only wanted a different language.
public enum LocalizationPreference {
    /// The `UserDefaults` key. `nil`/absent means "System default".
    public static let key = "language"

    /// Reads the persisted pick, or `nil` for "System default".
    public static func read(
        from defaults: UserDefaults = .standard
    ) -> String? {
        defaults.string(forKey: key)
    }

    /// Persists language pick, removing key on nil for system default.
    public static func write(
        _ language: String?,
        to defaults: UserDefaults = .standard
    ) {
        if let language {
            defaults.set(language, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
