import Foundation

/// Reserved macOS shortcuts KiwiDesk shouldn't shadow, used by
/// `KeybindingConflicts` to flag rows that clash with the
/// system rather than another row.
public enum SystemShortcuts {
    /// Known system shortcuts keyed by the parsed combo, with a
    /// human description.
    public static let map: [KeyCombo: String] = build([
        ("command+space", "Spotlight"),
        ("command+tab", "App Switcher"),
        ("command+q", "Quit App"),
        ("command+w", "Close Window"),
        ("command+m", "Minimize"),
        ("command+h", "Hide App"),
        ("command+option+esc", "Force Quit"),
        ("control+left", "Mission Control: Space Left"),
        ("control+right", "Mission Control: Space Right"),
        ("control+up", "Mission Control"),
        ("control+down", "App Windows"),
        ("command+shift+3", "Screenshot"),
        ("command+shift+4", "Screenshot Selection"),
        ("command+shift+5", "Screenshot Tools"),
    ])

    private static func build(
        _ entries: [(String, String)]
    ) -> [KeyCombo: String] {
        var map: [KeyCombo: String] = [:]
        for (combo, description) in entries {
            if let parsed = KeyCombo.parse(combo) {
                map[parsed] = description
            }
        }
        return map
    }
}
