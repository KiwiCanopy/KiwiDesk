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

/// The catalog backing the keybindings tab: navigation presets
/// and installed applications. Known macOS shortcuts used for
/// conflict detection live in Core's `SystemShortcuts`
/// (05_GUI_Concept §2, Tab 5).
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

    /// A quoted, escaped Lua string literal. Delegates to the
    /// canonical `SpaceLuaArg.quote` so the form a space rename
    /// rewrites always matches what the catalog authored (#13).
    static func quote(_ raw: String) -> String {
        SpaceLuaArg.quote(raw)
    }

    // MARK: - Change-mode & application commands (single source)

    /// The Change-Modes row that switches to `name`. The one
    /// authority for this Lua so the writer (`ChangeModesSection`)
    /// and the import classifier match byte-for-byte — a drift
    /// here would silently demote imports to Custom (#4).
    static func switchModeCommand(_ name: String) -> NavCommand {
        NavCommand(
            label: "Switch to \(name)",
            lua: "KiwiDesk.switch_mode(\(quote(name)))"
        )
    }

    /// The Open-Applications action that pulls or launches `name`.
    /// Paired with `appName(from:)`, its exact inverse.
    static func appCommand(_ name: String) -> String {
        "KiwiDesk.pull_or_spawn(\"\(name)\")"
    }

    /// The app name inside `appCommand`'s output, or nil when
    /// `lua` isn't exactly that call — the inverse used by import
    /// classification. An embedded quote means escaped content the
    /// app menu never authors, so such Lua stays unmatched.
    static func appName(from lua: String) -> String? {
        let prefix = "KiwiDesk.pull_or_spawn(\""
        let suffix = "\")"
        guard lua.hasPrefix(prefix), lua.hasSuffix(suffix),
            lua.count > prefix.count + suffix.count
        else { return nil }
        let inner = lua.dropFirst(prefix.count)
            .dropLast(suffix.count)
        guard !inner.contains("\"") else { return nil }
        return String(inner)
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
}
