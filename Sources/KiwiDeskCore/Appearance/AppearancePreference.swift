import Foundation

/// Which appearance the Settings window follows (#678 item 8).
///
/// Storage is app preferences (`UserDefaults`), NOT `gui.json`,
/// on the same reasoning as the GUI language pick
/// (`LocalizationPreference`): this is an app-wide display
/// choice, it is not part of a profile, and writing it must never
/// create a sidecar — that would flip `KiwiCore.isGuiManaged` and
/// hand config ownership to the structured loader for a user who
/// never asked to adopt the GUI. `profiles.md` states the rule
/// this follows: a profile may not override a setting that lives
/// outside config ownership.
///
/// Core carries the CHOICE, not a rendered appearance: mapping a
/// case onto `NSAppearance` / `ColorScheme` is AppKit's business
/// and stays in the GUI, which is the #96 seam applied to a
/// value type rather than to a sentence.
public enum AppearanceChoice: String, CaseIterable, Sendable {
    /// Follow macOS. The default, and the only value that leaves
    /// no key in the domain.
    case system
    case light
    case dark
}

public enum AppearancePreference {
    /// The `UserDefaults` key. `nil`/absent means `.system`.
    public static let key = "appearance"

    /// Reads the persisted pick. An unrecognised value — a
    /// hand-edited domain, or a case removed in a later
    /// version — reads as `.system` rather than trapping: this
    /// runs at window construction, and refusing to open a
    /// Settings window over a bad preference string is a worse
    /// failure than ignoring it.
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

    /// Persists `choice`; `.system` removes the key entirely, so
    /// the default leaves no trace in the domain — the same
    /// absent-means-default contract the language pick keeps.
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
