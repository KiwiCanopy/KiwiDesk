import Foundation

/// Policy classifying commands targeting implicit focused window
/// (`FocusedCommandPolicyTests`, #292).
public enum FocusedCommandPolicy {
    /// Dispatcher command names operating on implicit focused window.
    public static let focusedCommands: Set<String> = [
        "focus",
        "swap",
        "resize",
        "move_to_space",
        "move_to_space_and_follow",
        "move_to_desktop",
        "move_to_desktop_and_follow",
        "make_floating",
        "make_tiled",
        "toggle_floating",
        "new_window",
        "close_window",
        "make_sticky",
        "make_display_sticky",
        "make_unsticky",
        "toggle_sticky",
        "toggle_display_sticky",
        "override_sticky_reach",
        "move_to_track",
        "track.swap",
        "stack.promote",
        "stack.demote",
    ]

    /// Focused verbs the #292 preflight lets through while
    /// KiwiDesk's own raise toward the anchor is in flight
    /// (#1812). A verb joins only if it changes no window's
    /// content, size or membership; `FocusRaiseFlightGuardTests`
    /// holds every other verb to the refusal.
    public static let raiseFlightExempt: Set<String> = ["focus"]

    /// Checks if command targets implicit focused window (`KiwiCore.execute`).
    public static func isFocused(_ command: String) -> Bool {
        focusedCommands.contains(command)
    }
}
