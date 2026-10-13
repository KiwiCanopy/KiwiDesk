import KiwiDeskCore

/// The Layout group's shortcut rows: the cycle through the
/// `mode_cycle` list (#453) and the layout picker (#762). Written
/// out per row so each key stays a literal `scripts/extract-keys`
/// can see.
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

    /// The layout picker, the Jump panel's Layouts side (#2229).
    static let showLayoutPicker = NavCommand(
        label: "Show layout picker",
        lua: "KiwiDesk.show_layout_picker()",
        displayLabel: {
            L("keybinding.show_layout_picker", "Show layout picker")
        }
    )

    /// The layout cycle's rows (#453).
    static let layoutCycleRows: [NavCommand] = [
        nextLayout,
        previousLayout,
    ]

    /// Every Layout group row, one copy for every reader.
    static var layoutRows: [NavCommand] {
        layoutCycleRows + [showLayoutPicker]
    }
}
