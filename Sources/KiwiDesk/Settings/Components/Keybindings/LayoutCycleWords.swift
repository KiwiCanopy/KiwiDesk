import KiwiDeskCore

/// What the layout cycle row is called and how its value reads —
/// one home for the row, the diff pill and the checklist (#453).
@MainActor
enum LayoutCycleWords {
    static var title: String {
        L("shortcuts.mode_cycle", "Layouts to cycle")
    }

    static var help: String {
        L(
            "shortcuts.mode_cycle.help",
            "%1$@ moves the focused Space to the next layout in this "
                + "list and starts again at the top. A layout not in "
                + "the list goes to the first. A cycle needs at least "
                + "two layouts, and each layout appears once.",
            nextLayout
        )
    }

    /// The list in one line, in cycle order: "BSP › Scrolling ›
    /// Floating". The separator is the locale's, so a
    /// right-to-left or CJK catalog can choose its own.
    static func readout(_ modes: [LayoutMode]) -> String {
        modes.map(\.displayName).joined(
            separator: L("shortcuts.mode_cycle.separator", " › ")
        )
    }

    static var add: String {
        L("shortcuts.mode_cycle.add", "Add a layout")
    }

    static var remove: String {
        L("shortcuts.mode_cycle.remove", "Remove")
    }

    static var moveUp: String {
        L("shortcuts.mode_cycle.move_up", "Move Up")
    }

    static var moveDown: String {
        L("shortcuts.mode_cycle.move_down", "Move Down")
    }

    static var dragHelp: String {
        L("shortcuts.mode_cycle.drag", "Drag to reorder")
    }

    static var cueTitle: String {
        L("shortcuts.mode_cue", "Show the layout after cycling")
    }

    static var cueHelp: String {
        L(
            "shortcuts.mode_cue.help",
            "After %1$@ or %2$@, KiwiDesk shows the cycle list for a "
                + "moment with the new layout in the middle. This "
                + "switch applies at once, to every profile.",
            nextLayout,
            previousLayout
        )
    }

    /// The two shortcut rows' own labels, interpolated rather than
    /// quoted (#818).
    private static var nextLayout: String {
        L("keybinding.next_layout", "Next layout")
    }

    private static var previousLayout: String {
        L("keybinding.previous_layout", "Previous layout")
    }
}
