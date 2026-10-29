import Foundation

/// Which Settings root shows (#2737): Simple's one page or
/// Advanced's Home grid and its pages. Advanced is the whole of
/// Settings; Simple only hides.
enum SettingsRoot: String, CaseIterable, Sendable {
    case simple
    case advanced
}

/// The root choice's storage (#2737): `UserDefaults`, never
/// `gui.json` — a display choice, not profile data, so it owes no
/// `ConfigMigration`. Absent or unrecognised reads `firstOpen`. The
/// retired `settingsMode` key is never read: its values meant the
/// old modes.
enum SettingsRootPreference {
    static let key = "settingsRoot"

    /// The root every install opens on until the user picks, an
    /// updated one too (#2737 ruling 15).
    static let firstOpen = SettingsRoot.simple

    static func read(
        from defaults: UserDefaults
    ) -> SettingsRoot {
        defaults.string(forKey: key)
            .flatMap(SettingsRoot.init(rawValue:)) ?? firstOpen
    }

    static func write(
        _ root: SettingsRoot,
        to defaults: UserDefaults
    ) {
        defaults.set(root.rawValue, forKey: key)
    }
}

/// What Simple hides that the user made (#2737 ruling 2): the
/// header names it so nothing disappears silently.
struct SimpleHiddenCounts: Equatable, Sendable {
    var appRules = 0
    var layers = 0
    var luaBindings = 0

    var isEmpty: Bool {
        appRules == 0 && layers == 0 && luaBindings == 0
    }
}
