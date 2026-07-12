import AppKit
import KiwiDeskCore

/// The catalog backing the keybindings tab: navigation presets
/// and installed applications. Known macOS shortcuts used for
/// conflict detection live in Core's `SystemShortcuts`
/// (05_GUI_Concept §2, Tab 5).
enum KeybindingCatalog {
    // dir is the Lua argument; phrase is the positional English
    // wording used in the canonical `label` ("above"/"below"
    // read better than "up"/"down").
    private static let directions = [
        ("left", "to the left"), ("down", "below"),
        ("up", "above"), ("right", "to the right"),
    ]

    /// The translated phrase for a direction's Lua argument.
    /// A literal `L(...)` per case (not a dynamic key lookup)
    /// so `scripts/extract-keys` can enumerate it — the
    /// extractor only recognizes string-literal key/English
    /// arguments (`docs/translating.md` § Extraction
    /// limitations).
    @MainActor private static func directionPhrase(
        _ dir: String
    ) -> String {
        switch dir {
        case "left":
            return L("keybinding.dir.left", "to the left")
        case "down":
            return L("keybinding.dir.below", "below")
        case "up":
            return L("keybinding.dir.above", "above")
        case "right":
            return L("keybinding.dir.right", "to the right")
        default:
            return dir
        }
    }

    /// The four directional focus rows (#68 §3.6.1 Focus).
    static let focusDirections: [NavCommand] = directions.map {
        dir,
        phrase in
        NavCommand(
            label: "Focus window \(phrase)",
            lua: "KiwiDesk.focus(\"\(dir)\")",
            displayLabel: {
                L(
                    "keybinding.focus_dir",
                    "Focus window %1$@",
                    directionPhrase(dir)
                )
            }
        )
    }

    /// One "Go to Space …" row per defined space. The space
    /// name is user data (never translated), passed as a
    /// positional arg into the translated sentence.
    static func goToSpace(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Go to Space \(space.raw)",
                lua: "KiwiDesk.focus_space"
                    + "(\(spaceArg(space)))",
                icon: icons[space],
                displayLabel: {
                    L(
                        "keybinding.go_to_space",
                        "Go to Space %1$@",
                        space.raw
                    )
                }
            )
        }
    }

    /// The four directional swap rows (Move Windows).
    static let swapDirections: [NavCommand] = directions.map {
        dir,
        phrase in
        NavCommand(
            label: "Swap with window \(phrase)",
            lua: "KiwiDesk.swap(\"\(dir)\")",
            displayLabel: {
                L(
                    "keybinding.swap_dir",
                    "Swap with window %1$@",
                    directionPhrase(dir)
                )
            }
        )
    }

    /// The track verbs speak prev/next, not compass directions
    /// (#185 review): they act on the 1D track sequence, so
    /// two rows replace four (no per-axis inert pair, and a
    /// binding survives an axis flip). prev = the track toward
    /// the sequence start — left for columns, top for rows;
    /// next toward the end — right/bottom.
    private static let sequenceSteps = [
        ("prev", "previous"), ("next", "next"),
    ]

    /// The translated phrase for a sequence step's Lua
    /// argument (the `directionPhrase` twin).
    @MainActor private static func sequencePhrase(
        _ step: String
    ) -> String {
        switch step {
        case "prev":
            return L("keybinding.seq.prev", "previous")
        case "next":
            return L("keybinding.seq.next", "next")
        default:
            return step
        }
    }

    /// The two move-to-track rows (#128, prev/next). Labels
    /// name the actor — the window moves, not the focus.
    static let moveToTrackRows: [NavCommand] =
        sequenceSteps.map { step, phrase in
            NavCommand(
                label: "Move window to \(phrase) track",
                lua: "KiwiDesk.move_to_track(\"\(step)\")",
                displayLabel: {
                    L(
                        "keybinding.move_window_to_track",
                        "Move window to %1$@ track",
                        sequencePhrase(step)
                    )
                }
            )
        }

    /// The two whole-track swap rows (#182, prev/next).
    /// Advanced-track-gated like `moveToTrackRows`.
    static let trackSwapRows: [NavCommand] =
        sequenceSteps.map { step, phrase in
            NavCommand(
                label: "Swap with \(phrase) track",
                lua: "track.swap(\"\(step)\")",
                displayLabel: {
                    L(
                        "keybinding.swap_with_track",
                        "Swap with %1$@ track",
                        sequencePhrase(step)
                    )
                }
            )
        }

    /// The per-space "Move to …" / "… & follow" row pairs. The
    /// space name is user data, passed as a positional arg.
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
                        "KiwiDesk.move_to_space(\(arg))",
                    icon: icons[space],
                    displayLabel: {
                        L(
                            "keybinding.move_to_space",
                            "Move to Space %1$@",
                            space.raw
                        )
                    }
                ),
                NavCommand(
                    label:
                        "Move to Space \(space.raw) & follow",
                    lua: "KiwiDesk."
                        + "move_to_space_and_follow"
                        + "(\(arg))",
                    icon: icons[space],
                    displayLabel: {
                        L(
                            "keybinding.move_to_space_follow",
                            "Move to Space %1$@ & follow",
                            space.raw
                        )
                    }
                ),
            ]
        }
    }

    /// Navigation grouped for the import classifier (#4): the
    /// commands the sections render, so a recovered row matches
    /// byte-for-byte. Grow/Shrink is deliberately absent — its
    /// magnitude is configurable (#58), so import matches it by
    /// *shape* via `resizeShape(from:)`, not from this map.
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
                commands: swapDirections
                    + moveToTrackRows
                    + trackSwapRows
                    + moveToSpace(spaces)
            ),
        ]
    }

    // Size & Float presets (resizeAndFloat, makeFloating,
    // resizeShape) live in `KeybindingCatalog+Resize.swift`.

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
            lua: "KiwiDesk.switch_mode(\(quote(name)))",
            displayLabel: {
                L(
                    "keybinding.switch_to_mode",
                    "Switch to %1$@",
                    name
                )
            }
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
