import Foundation

/// The seed's pressed `⌃⌥` panel, layout and KiwiVision rows
/// (#453, #762, #1875, #2103), each its own builder so the
/// generations name it.
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
            label: "Show layout picker"
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
