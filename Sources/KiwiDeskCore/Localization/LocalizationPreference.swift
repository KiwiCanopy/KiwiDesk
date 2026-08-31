import Foundation

/// GUI language preference stored in UserDefaults (#9).
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
