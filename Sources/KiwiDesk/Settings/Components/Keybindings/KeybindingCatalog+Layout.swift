import KiwiDeskCore

/// The layout cycle's rows through the `mode_cycle` list (#453)
/// and KiwiHub's view picker (#762, #2265, #2309). Written out per row
/// so each key stays a literal `scripts/extract-keys` can see.
extension KeybindingCatalog {
    static let nextLayout = NavCommand(
        label: "Next layout",
        lua: "KiwiDesk.cycle_mode()",
        displayLabel: {
            L("keybinding.next_layout", "Switch to next layout")
        }
    )

    static let previousLayout = NavCommand(
        label: "Previous layout",
        lua: "KiwiDesk.cycle_mode(\"prev\")",
        displayLabel: {
            L("keybinding.previous_layout", "Switch to previous layout")
        }
    )

    /// The view picker, KiwiHub's View side (#2229, #2265, #2309).
    static let showLayoutPicker = NavCommand(
        label: "Show view picker",
        lua: KiwiHubSide.view.lua,
        displayLabel: {
            L("keybinding.show_view_picker", "Show view picker")
        }
    )

    /// The layout cycle's rows (#453).
    static let layoutCycleRows: [NavCommand] = [
        nextLayout,
        previousLayout,
    ]

    /// Every Layout group row, one copy for every reader.
    static var layoutRows: [NavCommand] { layoutCycleRows }
}
