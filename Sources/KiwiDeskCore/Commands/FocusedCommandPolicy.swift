import Foundation

/// Which dispatcher commands act on the **implicit focused
/// window** (#292) — `focus`, `resize`, `make_floating`, … — as
/// opposed to an explicit target (an App Bar click passes an id),
/// the active space (`focus_space`, per-space setters), or global
/// config. An implicit-focused command reads the focus anchor
/// (`focusedWindowID` — `resize` is the lone exception, keeping the
/// local `space.focused` slot; see `KiwiCore.resize`) and acts on
/// that window, so it must be blocked when the OS foreground is not
/// that managed window (an ignored panel or unmanaged app is
/// frontmost) — otherwise a shortcut silently mutates a window the
/// user cannot see.
///
/// Classification is centralized here so a single preflight at
/// `KiwiCore.execute` covers Lua, CLI, and IPC identically, and a
/// parity test (`FocusedCommandPolicyTests`) proves every
/// dispatchable command is accounted for — a new focused command
/// that forgets to enroll fails the build rather than silently
/// escaping the guard.
public enum FocusedCommandPolicy {
    /// The dispatcher spellings that operate on the implicit
    /// focused window. Some are namespaced (`track.swap`,
    /// `stack.promote`/`demote`) and reach dispatch through the
    /// layout-command prefix router, so they are listed by their
    /// full dotted name exactly as `execute` sees them.
    ///
    /// **Invariant:** a focused-window command must never be named
    /// `set_*` / `*.set_*`. The parity net
    /// (`FocusedCommandPolicyTests`) treats that spelling as a
    /// config setter (unrestricted), so a focused command named
    /// that way would slip the guard *without* failing the build.
    /// The repo convention keeps `set_` for config that never
    /// touches the focused window (see config-vocabulary), so this
    /// holds — but it is load-bearing here, not incidental.
    public static let focusedCommands: Set<String> = [
        "focus",
        "swap",
        "resize",
        "move_to_space",
        "move_to_space_and_follow",
        "make_floating",
        "make_tiled",
        "make_auto",
        "toggle_floating",
        "make_sticky",
        "make_unsticky",
        "toggle_sticky",
        "move_to_track",
        "track.swap",
        "stack.promote",
        "stack.demote",
    ]

    /// True when `command` acts on the implicit focused window and
    /// must clear the foreground-ownership preflight.
    public static func isFocused(_ command: String) -> Bool {
        focusedCommands.contains(command)
    }
}
