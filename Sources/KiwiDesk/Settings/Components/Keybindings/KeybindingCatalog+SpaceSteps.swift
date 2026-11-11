import KiwiDeskCore

/// The Space step rows (#1655): the previous and next Space in the
/// screen's order, and back and forward through the Space history.
/// Written out per row so each key is a literal `extract-keys`
/// sees; the labels are `DefaultKeybindings`' byte for byte
/// (`DefaultSeedCatalogParityTests`).
extension KeybindingCatalog {
    /// Go to the previous / next Space.
    static let spaceStepRows: [NavCommand] = [
        NavCommand(
            label: "Go to previous Space",
            lua: "KiwiDesk.focus_space_previous()",
            displayLabel: {
                L("keybinding.space_previous", "Go to previous Space")
            }
        ),
        NavCommand(
            label: "Go to next Space",
            lua: "KiwiDesk.focus_space_next()",
            displayLabel: {
                L("keybinding.space_next", "Go to next Space")
            }
        ),
    ]

    /// Go to the screen the focus was on before (#2512). No default
    /// chord; the screen verbs beside it are Lua and CLI only.
    static let screenLastRow = NavCommand(
        label: "Go to last screen",
        lua: "KiwiDesk.focus_display_last()",
        displayLabel: {
            L("keybinding.focus_display_last", "Go to last screen")
        }
    )

    /// Send the focused window to the screen the focus was on
    /// before, staying or following (#3117). No default chord; the
    /// direction forms stay Lua and CLI only until #2764 settles
    /// which way a screen lies.
    static let screenMoveRows: [NavCommand] = [
        NavCommand(
            label: "Move to last screen",
            lua: "KiwiDesk.move_to_display_last()",
            displayLabel: {
                L(
                    "keybinding.move_to_display_last",
                    "Move to last screen"
                )
            }
        ),
        NavCommand(
            label: "Move to last screen & follow",
            lua: "KiwiDesk.move_to_display_last_and_follow()",
            displayLabel: {
                L(
                    "keybinding.move_to_display_last_follow",
                    "Move to last screen & follow"
                )
            }
        ),
    ]

    /// Go to the Space you were on before, ⌘⇥-style (#3206); the
    /// trackpad's three-finger tap runs it by default.
    static let spaceLastRow = NavCommand(
        label: "Go to last Space",
        lua: "KiwiDesk.focus_space_last()",
        displayLabel: {
            L("keybinding.focus_space_last", "Go to last Space")
        }
    )

    /// Go back / forward in the Space history.
    static let spaceHistoryRows: [NavCommand] = [
        NavCommand(
            label: "Go back in Space history",
            lua: "KiwiDesk.focus_space_back()",
            displayLabel: {
                L(
                    "keybinding.space_back",
                    "Go back in Space history"
                )
            }
        ),
        NavCommand(
            label: "Go forward in Space history",
            lua: "KiwiDesk.focus_space_forward()",
            displayLabel: {
                L(
                    "keybinding.space_forward",
                    "Go forward in Space history"
                )
            }
        ),
    ]
}
