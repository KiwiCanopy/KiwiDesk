import Foundation

/// Policy classifying commands targeting implicit focused window
/// (`FocusedCommandPolicyTests`, #292).
public enum FocusedCommandPolicy {
    /// Dispatcher command names operating on the implicit focused
    /// window. INVARIANT: a focused command must never be named
    /// `set_*` / `*.set_*` — the parity net treats that spelling
    /// as a config setter (unrestricted), so a focused command
    /// named that way would slip the guard WITHOUT failing the
    /// build. Load-bearing, not incidental.
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
        "make_auto",
        "toggle_floating",
        "make_sticky",
        "make_display_sticky",
        "make_unsticky",
        "toggle_sticky",
        "toggle_display_sticky",
        "move_to_track",
        "track.swap",
        "stack.promote",
        "stack.demote",
    ]

    /// Checks if command targets implicit focused window (`KiwiCore.execute`).
    public static func isFocused(_ command: String) -> Bool {
        focusedCommands.contains(command)
    }
}
