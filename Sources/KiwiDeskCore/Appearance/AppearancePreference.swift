import Foundation

/// Settings appearance preference options and UserDefaults persistence
/// (#96, #678 item 8).
public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum AppearancePreference {
    /// UserDefaults preference key.
    public static let key = "appearance"

    /// Reads persisted appearance choice or falls back to system.
    public static func read(
        from defaults: UserDefaults = .standard
    ) -> AppearanceChoice {
        guard
            let raw = defaults.string(forKey: key),
            let choice = AppearanceChoice(rawValue: raw)
        else {
            return .system
        }
        return choice
    }

    /// Persists appearance choice to UserDefaults (.system removes key).
    public static func write(
        _ choice: AppearanceChoice,
        to defaults: UserDefaults = .standard
    ) {
        if choice == .system {
            defaults.removeObject(forKey: key)
        } else {
            defaults.set(choice.rawValue, forKey: key)
        }
    }
}
