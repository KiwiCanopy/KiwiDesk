import Foundation

/// Which commands are hard to undo (#1685). `kiwidesk mcp` reads
/// this to route them to its `run_destructive` tool, which MCP
/// clients confirm with the user; `list_commands --json` carries
/// it as `destructive`.
extension APIReference {
    /// Qualified names of the commands that lose something a
    /// user cannot get back by running another command: a file,
    /// a window's content, or unsaved live changes.
    /// `APIDestructiveCensusTests` holds every name to a real
    /// command and every verb whose name reads destructive to
    /// this list or its ruled exemptions.
    public static let destructive: Set<String> = [
        "delete_space",
        "close_window",
        "delete_profile",
        // Overwrites a saved profile of the same name.
        "save_profile",
        // Both replace the live arrangement, dropping changes
        // nothing saved.
        "load_profile",
        "reload_config",
        "reset_layout_sizing",
        ServiceManager.prepareRestartCommand,
    ]

    /// True for a command in `destructive`, by name or alias.
    public static func isDestructive(_ name: String) -> Bool {
        guard let entry = entry(named: name) else { return false }
        return destructive.contains(entry.qualifiedName)
    }
}
