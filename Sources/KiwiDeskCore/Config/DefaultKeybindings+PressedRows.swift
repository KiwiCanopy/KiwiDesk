import Foundation

/// The seed's pressed `⌃⌥` panel, layout, KiwiVision, sizing and
/// maximize rows (#453, #762, #1875, #2103, #2303, #2448), each its
/// own builder so the generations name it.
extension DefaultKeybindings {
    /// Next layout on `⌃⌥C` (#453).
    public static func nextLayoutRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+c",
            lua: "KiwiDesk.cycle_mode()",
            kind: .navigation,
            label: "Next layout"
        )
    }

    /// The layout picker on `⌃⌥L` (#762), L for layout.
    public static func layoutPickerRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+l",
            lua: KiwiHubSide.view.lua,
            kind: .navigation,
            label: "Show view picker"
        )
    }

    /// The window switcher on `⌃⌥J` (#1875), J for jump.
    public static func jumpToWindowRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+j",
            lua: KiwiHubSide.windows.lua,
            kind: .navigation,
            label: "Jump to window"
        )
    }

    /// KiwiVision on `⌃⌥V` (#2103), V for vision. Free in
    /// `SystemShortcuts.map` and macOS's symbolic hotkeys
    /// (read 2026-10-14).
    public static func kiwiVisionRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+v",
            lua: "kiwivision.toggle()",
            kind: .navigation,
            label: "Toggle KiwiVision"
        )
    }

    /// Reset sizes in this Space on `⌃⌥R` (#2303), R for reset:
    /// `reset_layout_sizing` on the active Space. Free in
    /// `SystemShortcuts.map`, macOS's symbolic hotkeys and every
    /// running app's menus (read 2026-10-18).
    public static func resetSizesRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+r",
            lua: "KiwiDesk.reset_layout_sizing()",
            kind: .navigation,
            label: "Reset sizes in this Space"
        )
    }

    /// Maximize on `⌃⌥M` (#2448), M for maximize: the focused
    /// tiled window fills its screen. Free in the seed,
    /// `SystemShortcuts.map` and macOS's symbolic hotkeys
    /// (read 2026-10-21).
    public static func maximizeRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+m",
            lua: "KiwiDesk.toggle_maximized()",
            kind: .navigation,
            label: "Maximize"
        )
    }

    /// Pocket on `⌃⌥P` (#2446), P for pocket: the chord pin held
    /// until 3.3.0, which keeps no default (owner, 2026-10-20).
    public static func pocketRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+p",
            lua: "KiwiDesk.pocket()",
            kind: .navigation,
            label: "Pocket or take out"
        )
    }

    /// Toggle Pocket on `⌃⌥⇧P` (#2675), beside Pocket's
    /// `⌃⌥P`. Free in the seed and `SystemShortcuts.map` (read
    /// 2026-10-27).
    public static func pocketWindowRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+shift+p",
            lua: "KiwiDesk.toggle_pocket_window()",
            kind: .navigation,
            label: "Toggle Pocket"
        )
    }

    /// The bars' shortcuts (#761): the Space Bar on `⌃⌥G`, the App
    /// Bar on `⌃⌥H` — the home row beside KiwiHub's J K L, the keys
    /// that show something (owner, 2026-10-19). Free in the seed and
    /// in `SystemShortcuts.map` (checked 2026-10-19).
    public static func barRevealRows() -> [KeyBinding] {
        [
            KeyBinding(
                combo: "control+option+g",
                lua: "space_bar.toggle_reveal()",
                kind: .navigation,
                label: "Show or hide the Space Bar"
            ),
            KeyBinding(
                combo: "control+option+h",
                lua: "app_bar.toggle_reveal()",
                kind: .navigation,
                label: "Show or hide the App Bar"
            ),
        ]
    }

    /// Previous layout on `⌃⌥⇧C`, `⇧` reversing its twin as on
    /// `Tab` (#453, widening #1655 to a letter).
    public static func previousLayoutRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+shift+c",
            lua: "KiwiDesk.cycle_mode(\"prev\")",
            kind: .navigation,
            label: "Previous layout"
        )
    }
}
