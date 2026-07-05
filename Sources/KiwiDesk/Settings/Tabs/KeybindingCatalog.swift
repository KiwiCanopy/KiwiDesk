import AppKit
import KiwiDeskCore

/// A preset navigation action: a label and the Lua body it
/// binds to.
struct NavCommand: Identifiable, Hashable {
    let label: String
    let lua: String
    var id: String { lua }
}

/// A collapsible group of navigation commands (Focus — including
/// go-to-space — and Window Movement).
struct NavGroup: Identifiable {
    let title: String
    let commands: [NavCommand]
    var id: String { title }
}

/// The catalog backing the keybindings tab: navigation presets,
/// installed applications, and known macOS shortcuts used for
/// conflict detection (05_GUI_Concept §2, Tab 5).
enum KeybindingCatalog {
    private static let directions = [
        ("Left", "left"), ("Down", "down"),
        ("Up", "up"), ("Right", "right"),
    ]

    /// Navigation grouped into dropdowns. Space-specific rows
    /// are generated from the user's defined spaces, so adding
    /// a space adds its move/focus commands here automatically.
    static func navigationGroups(
        spaces: [SpaceID]
    ) -> [NavGroup] {
        var focus = directions.map { name, dir in
            NavCommand(
                label: "Focus \(name)",
                lua: "KiwiDesk.focus(\"\(dir)\")"
            )
        }
        // Going to a space is a focus action, so it shares the
        // Focus group rather than its own accordion.
        for space in spaces {
            focus.append(
                NavCommand(
                    label: "Go to \(space.raw)",
                    lua: "KiwiDesk.focus_virtual_space"
                        + "(\(spaceArg(space)))"
                )
            )
        }
        var movement = directions.map { name, dir in
            NavCommand(
                label: "Swap \(name)",
                lua: "KiwiDesk.swap(\"\(dir)\")"
            )
        }
        for space in spaces {
            let arg = spaceArg(space)
            movement.append(
                NavCommand(
                    label: "Move window to \(space.raw)",
                    lua: "KiwiDesk.move_to_virtual_space(\(arg))"
                )
            )
            movement.append(
                NavCommand(
                    label: "Move window to \(space.raw) & follow",
                    lua:
                        "KiwiDesk.move_to_virtual_space_and_follow"
                        + "(\(arg))"
                )
            )
        }
        return [
            NavGroup(title: "Focus", commands: focus),
            NavGroup(title: "Window Movement", commands: movement),
        ]
    }

    /// A space id as a quoted, escaped Lua string argument.
    static func spaceArg(_ space: SpaceID) -> String {
        quote(space.raw)
    }

    /// A quoted, escaped Lua string literal.
    static func quote(_ raw: String) -> String {
        let escaped =
            raw
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Installed application names, scanned once per launch.
    static let installedApps: [String] = {
        let manager = FileManager.default
        let roots = [
            "/Applications",
            "/System/Applications",
            manager.homeDirectoryForCurrentUser
                .appendingPathComponent("Applications").path,
        ]
        var names: Set<String> = []
        for root in roots {
            let contents =
                (try? manager.contentsOfDirectory(
                    atPath: root
                )) ?? []
            for entry in contents where entry.hasSuffix(".app") {
                names.insert(String(entry.dropLast(4)))
            }
        }
        return names.sorted()
    }()

    /// macOS system shortcuts KiwiDesk shouldn't shadow, keyed
    /// by the parsed combo, with a human description.
    static let systemShortcuts: [KeyCombo: String] = build([
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
