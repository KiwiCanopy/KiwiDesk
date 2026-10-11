import KiwiDeskCore

/// Layout cycle shortcut rows (#453): the focused Space steps
/// through the `mode_cycle` list. Written out per row so each
/// key stays a literal `scripts/extract-keys` can see.
extension KeybindingCatalog {
    static let nextLayout = NavCommand(
        label: "Next layout",
        lua: "KiwiDesk.cycle_mode()",
        displayLabel: {
            L("keybinding.next_layout", "Next layout")
        }
    )

    static let previousLayout = NavCommand(
        label: "Previous layout",
        lua: "KiwiDesk.cycle_mode(\"prev\")",
        displayLabel: {
            L("keybinding.previous_layout", "Previous layout")
        }
    )

    /// The Layout group's rows, one copy for every reader.
    static let layoutCycleRows: [NavCommand] = [
        nextLayout,
        previousLayout,
    ]
}
