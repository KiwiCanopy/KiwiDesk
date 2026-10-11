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
