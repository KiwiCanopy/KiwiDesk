import AppKit
import KiwiDeskCore

/// A preset navigation action: a label and the Lua body it
/// binds to.
struct NavCommand: Identifiable, Hashable {
    let label: String
    let lua: String
    /// Optional space icon (#68 §6.5) shown before the label
    /// — recognition sugar only; labels stay authoritative
    /// (the import classifier matches on label + Lua).
    var icon: String? = nil
    var id: String { lua }
}

/// A collapsible group of navigation commands (Focus — including
/// go-to-space — and Window Management: move, resize, float).
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
    // dir is the Lua argument; phrase is the positional wording
    // used in labels ("above"/"below" read better than "up"/"down").
    private static let directions = [
        ("left", "to the left"), ("down", "below"),
        ("up", "above"), ("right", "to the right"),
    ]

    /// The fixed step a Grow/Shrink preset nudges the layout by, in
    /// points. The catalog authors one magnitude, so import
    /// classification only upgrades a recovered `resize` that used
    /// this exact delta (like every preset, the Lua must match
    /// byte-for-byte); other magnitudes stay Custom.
    static let resizeStep = 50

    /// The four directional focus rows (#68 §3.6.1 Focus).
    static let focusDirections: [NavCommand] = directions.map {
        dir,
        phrase in
        NavCommand(
            label: "Focus window \(phrase)",
            lua: "KiwiDesk.focus(\"\(dir)\")"
        )
    }

    /// One "Go to Space …" row per defined space.
    static func goToSpace(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Go to Space \(space.raw)",
                lua: "KiwiDesk.focus_virtual_space"
                    + "(\(spaceArg(space)))",
                icon: icons[space]
            )
        }
    }

    /// The four directional swap rows (Move Windows).
    static let swapDirections: [NavCommand] = directions.map {
        dir,
        phrase in
        NavCommand(
            label: "Swap with window \(phrase)",
            lua: "KiwiDesk.swap(\"\(dir)\")"
        )
    }

    /// The per-space "Move to …" / "… & follow" row pairs.
    static func moveToSpace(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.flatMap { space -> [NavCommand] in
            let arg = spaceArg(space)
            return [
                NavCommand(
                    label: "Move to Space \(space.raw)",
                    lua:
                        "KiwiDesk.move_to_virtual_space(\(arg))",
                    icon: icons[space]
                ),
                NavCommand(
                    label:
                        "Move to Space \(space.raw) & follow",
                    lua: "KiwiDesk."
                        + "move_to_virtual_space_and_follow"
                        + "(\(arg))",
                    icon: icons[space]
                ),
            ]
        }
    }

    /// Navigation grouped for the import classifier (#4): the
    /// same commands the sections render, so a recovered row
    /// matches byte-for-byte.
    static func navigationGroups(
        spaces: [SpaceID]
    ) -> [NavGroup] {
        [
            NavGroup(
                title: "Focus",
                commands: focusDirections + goToSpace(spaces)
            ),
            NavGroup(
                title: "Window Management",
                commands: resizeAndFloat + swapDirections
                    + moveToSpace(spaces)
            ),
        ]
    }

    /// Window-size and float presets (Size & Float, §3.6.1).
    /// Enlarge/Shrink nudge the single bsp split / stack master
    /// ratio by `resizeStep` — there is no independent
    /// width/height today, so this is one pair on the `"x"`
    /// axis, not four (true 2-axis resize is deferred, #56; a
    /// configurable step is #58 — both land in this group).
    /// Resize is a no-op in monocle/grid/floating; the section
    /// caption states this and the docs echo it.
    static let resizeAndFloat: [NavCommand] = [
        NavCommand(
            label: "Shrink",
            lua: "KiwiDesk.resize(\"x\", -\(resizeStep))"
        ),
        NavCommand(
            label: "Enlarge",
            lua: "KiwiDesk.resize(\"x\", \(resizeStep))"
        ),
        NavCommand(
            label: "Make floating",
            lua: "KiwiDesk.make_floating()"
        ),
    ]

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

    /// Renames a mode across `modes`: the mode itself plus
    /// every switch-mode row targeting it, rewritten through
    /// `switchModeCommand` so writer and import classifier
    /// keep matching byte-for-byte (#4). Pure — the tested
    /// core of the Shortcuts header's rename.
    static func renameMode(
        in modes: [KeyMode],
        from old: String,
        to new: String
    ) -> [KeyMode] {
        // `default` is the config's anchor mode ("always the
        // active one after the app starts") — no entry point
        // may rename it, today's UI gate or a future CLI's.
        guard old != KeyMode.defaultName else { return modes }
        let oldCmd = switchModeCommand(old)
        let newCmd = switchModeCommand(new)
        return modes.map { mode in
            var mode = mode
            if mode.name == old { mode.name = new }
            mode.bindings = mode.bindings.map { binding in
                var binding = binding
                if binding.lua == oldCmd.lua {
                    binding.lua = newCmd.lua
                    binding.label = newCmd.label
                }
                return binding
            }
            return mode
        }
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
