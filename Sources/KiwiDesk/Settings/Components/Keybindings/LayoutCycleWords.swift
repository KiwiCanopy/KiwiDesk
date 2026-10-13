import KiwiDeskCore

/// What the layout cycle row is called and how its value reads —
/// one home for the row, the diff pill and the checklist (#453).
@MainActor
enum LayoutCycleWords {
    static var title: String {
        SettingsCatalog.shortcuts.modeCycle.text
    }

    static var help: String {
        L(
            "shortcuts.mode_cycle.help",
            "“%1$@” moves the focused Space to the next layout in this "
                + "list and starts again at the top. A layout not in "
                + "the list goes to the first. A cycle needs at least "
                + "two layouts, and each layout appears once.",
            nextLayout
        )
    }

    /// The list in one line, in cycle order: "BSP › Scrolling ›
    /// Floating". The mark is the locale's; the spaces around it
    /// are the code's, since a catalog value keeps no edge space.
    static func readout(_ modes: [LayoutMode]) -> String {
        modes.map(\.displayName).joined(
            separator: " \(L("shortcuts.mode_cycle.separator", "›")) "
        )
    }

    /// The readout as VoiceOver reads it: the locale's list, with
    /// no mark to speak (#812).
    static func spoken(_ modes: [LayoutMode]) -> String {
        LocalizedList.join(modes.map(\.displayName))
    }

    /// An item's place in the cycle, spoken after its name.
    static func position(_ index: Int, of count: Int) -> String {
        L(
            "shortcuts.mode_cycle.position",
            "Position: %1$d of %2$d",
            index + 1,
            count
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
        SettingsCatalog.shortcuts.modeCue.text
    }

    static var cueHelp: String {
        L(
            "shortcuts.mode_cue.help",
            "After “%1$@” or “%2$@”, KiwiDesk shows the cycle list "
                + "for a moment with the new layout in the middle. This "
                + "switch applies at once, to every profile.",
            nextLayout,
            previousLayout
        )
    }

    /// The two shortcut rows' own labels, interpolated rather than
    /// quoted (#818).
    private static var nextLayout: String {
        KeybindingCatalog.nextLayout.resolvedLabel
    }

    private static var previousLayout: String {
        KeybindingCatalog.previousLayout.resolvedLabel
    }
}
