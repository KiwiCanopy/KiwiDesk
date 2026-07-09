import Foundation

/// The GUI language pick's storage (issue #9): app preferences
/// (`UserDefaults`), NOT `gui.json`. A language change is
/// documented as side-effect-free — it must never create a
/// `gui.json` sidecar (which would flip `KiwiCore.isGuiManaged`
/// and hand config ownership to the structured loader for a
/// user who never asked to adopt the GUI). `UserDefaults` has
/// no such coupling: nothing else keys off its existence.
public enum LocalizationPreference {
    /// The `UserDefaults` key. `nil`/absent means "System
    /// default".
    public static let key = "language"

    /// Reads the persisted pick, or `nil` for "System default".
    public static func read(
        from defaults: UserDefaults = .standard
    ) -> String? {
        defaults.string(forKey: key)
    }

    /// Persists `language`; `nil` removes the key entirely (so
    /// "System default" leaves no trace in the domain, mirroring
    /// the old absent-key-in-JSON contract).
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
