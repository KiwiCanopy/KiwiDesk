import Foundation

/// The seed's pressed `⌃⌥` panel and layout rows (#453, #762, #1875),
/// each its own builder so the generations name it.
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
            lua: "KiwiDesk.show_layout_picker()",
            kind: .navigation,
            label: "Show layout picker"
        )
    }

    /// Jump to window on `⌃⌥J` (#1875), J for jump.
    public static func jumpToWindowRow() -> KeyBinding {
        KeyBinding(
            combo: "control+option+j",
            lua: "KiwiDesk.show_jump_to_window()",
            kind: .navigation,
            label: "Jump to window"
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
