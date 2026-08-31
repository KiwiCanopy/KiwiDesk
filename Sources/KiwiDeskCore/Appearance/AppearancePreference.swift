import Foundation

/// Settings appearance preference (#96, #678 item 8). Stored in
/// `UserDefaults`, NOT `gui.json`: writing it must never create a
/// sidecar — that would flip `KiwiCore.isGuiManaged` and hand
/// config ownership to the structured loader for a user who never
/// adopted the GUI (`profiles.md`).
public enum AppearanceChoice: String, CaseIterable, Sendable {
    case system
    case light
    case dark
}

public enum AppearancePreference {
    /// UserDefaults preference key.
    public static let key = "appearance"

    /// Reads persisted choice; an unrecognised value reads as
    /// `.system` rather than trapping — refusing to open Settings
    /// over a bad preference string is the worse failure.
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
