import Foundation

/// The dispatcher verbs that move windows, Spaces and Desktops
/// (#1033) — the `KiwiDesk.*` half a keybinding usually names.
///
/// **The three Desktop verbs are exemplars and are written**;
/// they are the `.desktop` argument's only home, and the reason
/// that kind exists rather than a bare integer: a Desktop number
/// is Mission Control's, counted globally across every screen,
/// while a Space id is KiwiDesk's own string (#884/#888).
/// `create_space` is written too, as the surface's one optional
/// argument.
extension APIReference {
    static let coreWindowRecords: [String: APIRecord] = [
        "focus": APIRecord(
            "Moves keyboard focus to the neighboring window.",
            .choice("direction", Direction.self)
        ),
        "swap": APIRecord(
            "Swaps the focused window with the neighboring "
                + "window.",
            .choice("direction", Direction.self)
        ),
        "focus_space": APIRecord(
            "Switches to a Space, hiding the current Space's "
                + "windows.",
            .space("space")
        ),
        "move_to_space": APIRecord(
            "Moves the focused window to a Space without "
                + "following it.",
            .space("space")
        ),
        "move_to_space_and_follow": APIRecord(
            "Moves the focused window to a Space and switches "
                + "to it.",
            .space("space")
        ),
        "focus_desktop": APIRecord(
            "Switches to a macOS Desktop, exactly as a swipe "
                + "would.",
            .desktop("desktop")
        ),
        "move_to_desktop": APIRecord(
            "Moves the focused window to a macOS Desktop without "
                + "following it.",
            .desktop("desktop")
        ),
        "move_to_desktop_and_follow": APIRecord(
            "Moves the focused window to a macOS Desktop and "
                + "switches to it with the window focused.",
            .desktop("desktop")
        ),
        "move_space_to_display": APIRecord(
            "Moves a Space to another monitor and shows it there.",
            .space("space"),
            .text("display")
        ),
        "pin_space_to_display": APIRecord(
            "Pins a Space to a monitor by fingerprint or name.",
            .space("space"),
            .text("display")
        ),
        "create_space": APIRecord(
            "Brings a Space into existence, optionally in a "
                + "given layout mode.",
            .space("space"),
            .choice("mode", LayoutMode.self, optional: true)
        ),
        "delete_space": APIRecord(
            "Removes a Space after rehoming its windows.",
            .space("space")
        ),
        "make_floating": APIRecord(
            "Marks the focused window as floating above the "
                + "tiles."
        ),
        "make_tiled": APIRecord(
            "Returns the focused window to its space's tiling "
                + "layout."
        ),
        "make_auto": APIRecord(
            "Clears the focused window's manual float override."
        ),
        "toggle_floating": APIRecord(
            "Flips the focused window between floating and tiled."
        ),
        "make_sticky": APIRecord(
            "Marks the focused window globally sticky across all "
                + "screens."
        ),
        "make_display_sticky": APIRecord(
            "Marks the focused window sticky to its current "
                + "monitor."
        ),
        "make_unsticky": APIRecord(
            "Clears the focused window's sticky state."
        ),
        "toggle_sticky": APIRecord(
            "Flips the focused window between globally sticky and "
                + "off."
        ),
        "toggle_display_sticky": APIRecord(
            "Flips the focused window between display-sticky and "
                + "off."
        ),
        "resize": APIRecord(
            "Resizes the focused window along the x or y axis.",
            .text("axis"),
            .number("delta")
        ),
        "move_to_track": APIRecord(
            "Moves the focused window into the adjacent track.",
            .text("direction")
        ),
        "pull_or_spawn": APIRecord(
            "Focuses an app's window, or launches a new instance.",
            .text("bundle_id")
        ),
        "spawn_new": APIRecord(
            "Launches a new instance of an app by bundle "
                + "identifier.",
            .text("bundle_id")
        ),
        "set_mode": APIRecord(
            "Sets a Space's layout mode.",
            .space("space"),
            .choice("mode", LayoutMode.self)
        ),
        "set_fallback_space": APIRecord(
            "Sets where windows land when a profile drops their "
                + "space.",
            .space("space")
        ),
        "set_space_icon": APIRecord(
            "Sets the recognition icon for a Space in the GUI.",
            .space("space"),
            .text("icon")
        ),
    ]
}
