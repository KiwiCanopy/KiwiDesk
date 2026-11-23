import KiwiDeskCore

/// The layout undo pair's rows (#3515), listed with Size & float.
extension KeybindingCatalog {
    /// `undo_layout` and `redo_layout` (#3515): the active Space's
    /// last arrangement change, taken back or made again.
    static let undoLayout = NavCommand(
        label: "Undo layout change",
        lua: "KiwiDesk.undo_layout()",
        displayLabel: {
            L("keybinding.undo_layout", "Undo layout change")
        }
    )

    static let redoLayout = NavCommand(
        label: "Redo layout change",
        lua: "KiwiDesk.redo_layout()",
        displayLabel: {
            L("keybinding.redo_layout", "Redo layout change")
        }
    )
}
