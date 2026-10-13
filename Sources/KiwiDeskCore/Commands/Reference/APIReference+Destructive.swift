import Foundation

/// Which commands are hard to undo (#1685). `kiwidesk mcp` reads
/// this to route them to its `run_destructive` tool, which MCP
/// clients may confirm with the user; `list_commands --json`
/// carries it as `destructive`.
extension APIReference {
    /// Qualified names of the commands that lose something a
    /// user cannot get back by running another command: a file,
    /// a window's content, or unsaved live changes.
    /// `APIDestructiveCensusTests` holds every name to a real
    /// command and every verb whose name reads destructive to
    /// this list or its ruled exemptions. Ruled out: a Desktop
    /// switch onto a bound Desktop loads its profile as a swipe
    /// does, which is the binding working; `set_default_profile`
    /// replaces only a choice another call restores.
    public static let destructive: Set<String> = [
        "delete_space",
        "close_window",
        "delete_profile",
        // Overwrites a saved profile of the same name.
        "save_profile",
        // Each replaces the live arrangement, dropping changes
        // nothing saved; a binding applies its profile at once
        // when the current Desktop is the one bound.
        "load_profile",
        "reload_config",
        "bind_profile_to_desktop",
        "reset_layout_sizing",
        ServiceManager.prepareRestartCommand,
    ]

    /// True for a command in `destructive`, by name or alias.
    public static func isDestructive(_ name: String) -> Bool {
        entry(named: name).map(isDestructive) ?? false
    }

    /// True for an entry in `destructive`.
    public static func isDestructive(_ entry: APIEntry) -> Bool {
        destructive.contains(entry.qualifiedName)
    }
}
