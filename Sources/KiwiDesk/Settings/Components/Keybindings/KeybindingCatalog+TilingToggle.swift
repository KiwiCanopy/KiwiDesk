import KiwiDeskCore

extension KeybindingCatalog {
    /// `toggle_tiling()` (#3008): the Space's tiling off and on.
    static let toggleTiling = NavCommand(
        label: "Tiling Off for This Space",
        lua: "KiwiDesk.toggle_tiling()",
        displayLabel: {
            L("keybinding.toggle_tiling", "Tiling Off for This Space")
        },
        help: {
            L(
                "keybinding.toggle_tiling.help",
                "Stops arranging this Space's windows and leaves them "
                    + "where they are. Press again to tile them back "
                    + "into their places."
            )
        }
    )
}
