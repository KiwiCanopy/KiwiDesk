import AppKit
import KiwiDeskCore

/// Catalog backing shortcuts settings tab: navigation presets and application
/// launchers.
enum KeybindingCatalog {
    private static let directions = [
        ("left", "to the left"), ("down", "below"),
        ("up", "above"), ("right", "to the right"),
    ]

    /// Translates direction argument for display (`docs/translating.md`).
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

    /// Four directional focus rows (#68 §3.6.1).
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

    /// "Go to Space …" commands for configured spaces.
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

    /// Four directional swap rows.
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

    private static let sequenceSteps = [
        ("prev", "previous"), ("next", "next"),
    ]

    /// Translates sequence step argument for display (#95).
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

    /// Move window to previous/next track rows (#185, #128).
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

    /// Swap with previous/next track rows (#182, #188).
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

    /// Interleaved "Move to Space" and "Move to Space & follow" command pairs
    /// (#678 Phase 3, #4).
    static func moveToSpace(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        zip(
            moveToSpaceRows(spaces, icons: icons),
            moveToSpaceFollowRows(spaces, icons: icons)
        )
        .flatMap { [$0, $1] }
    }

    /// "Move to Space …" commands for configured spaces.
    static func moveToSpaceRows(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Move to Space \(space.raw)",
                lua:
                    "KiwiDesk.move_to_space(\(spaceArg(space)))",
                icon: icons[space],
                displayLabel: {
                    L(
                        "keybinding.move_to_space",
                        "Move to Space %1$@",
                        space.raw
                    )
                }
            )
        }
    }

    /// "Move to Space … & follow" commands for configured spaces.
    static func moveToSpaceFollowRows(
        _ spaces: [SpaceID],
        icons: [SpaceID: String] = [:]
    ) -> [NavCommand] {
        spaces.map { space in
            NavCommand(
                label: "Move to Space \(space.raw) & follow",
                lua: "KiwiDesk."
                    + "move_to_space_and_follow"
                    + "(\(spaceArg(space)))",
                icon: icons[space],
                displayLabel: {
                    L(
                        "keybinding.move_to_space_follow",
                        "Move to Space %1$@ & follow",
                        space.raw
                    )
                }
            )
        }
    }

    /// Grouped navigation commands for keybinding import classifier (#4, #58).
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

    /// Formats space ID as quoted Lua string argument (#13).
    static func spaceArg(_ space: SpaceID) -> String {
        quote(space.raw)
    }

    /// Quotes raw string via `SpaceLuaArg.quote`.
    static func quote(_ raw: String) -> String {
        SpaceLuaArg.quote(raw)
    }

    /// Command opening shortcuts cheat sheet overlay (#330, #602).
    static let showShortcuts = NavCommand(
        label: "Show shortcuts panel",
        lua: ShortcutsOpenBinding.lua,
        displayLabel: {
            L("keybinding.show_shortcuts", "Show shortcuts panel")
        }
    )

    /// Command opening settings window (`OpenSettingsClassifyTests`, #678 item
    /// 18).
    static let openSettings = NavCommand(
        label: "Open Settings",
        lua: "KiwiDesk.open_settings()",
        displayLabel: {
            L("keybinding.open_settings", "Open Settings")
        }
    )
}
