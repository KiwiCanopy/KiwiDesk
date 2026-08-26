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
///
/// Everything else here is `.todo()` until #1033 phase 2 fills
/// it; `APIRecordFilledTests` counts what is left.
extension APIReference {
    static let coreWindowRecords: [String: APIRecord] = [
        "focus": .todo(),
        "swap": .todo(),
        "focus_space": .todo(),
        "move_to_space": .todo(),
        "move_to_space_and_follow": .todo(),
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
        "move_space_to_display": .todo(),
        "pin_space_to_display": .todo(),
        "create_space": APIRecord(
            "Brings a Space into existence, optionally in a "
                + "given layout mode.",
            .space("space"),
            .choice("mode", LayoutMode.self, optional: true)
        ),
        "delete_space": .todo(),
        "make_floating": .todo(),
        "make_tiled": .todo(),
        "make_auto": .todo(),
        "toggle_floating": .todo(),
        "make_sticky": .todo(),
        "make_display_sticky": .todo(),
        "make_unsticky": .todo(),
        "toggle_sticky": .todo(),
        "toggle_display_sticky": .todo(),
        "resize": .todo(),
        "move_to_track": .todo(),
        "pull_or_spawn": .todo(),
        "spawn_new": .todo(),
        "set_mode": .todo(),
        "set_fallback_space": .todo(),
        "set_space_icon": .todo(),
    ]
}
