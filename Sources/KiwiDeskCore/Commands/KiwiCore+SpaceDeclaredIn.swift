import Foundation

/// Which declarations bring a deleted Space back on the next
/// config load (#1509) — the fact `delete_space` carries in its
/// payload so a runtime removal is never mistaken for a durable
/// one.
extension KiwiCore {
    /// Every source that re-creates `space` at the next load, in
    /// the payload's spelling: `profile:<name>` for the active
    /// profile, read from adoption state and never its file
    /// (#1245); `init.lua` for a Space the last script run asked
    /// for; `gui.json` for a GUI-managed sidecar listing it.
    /// Empty when the Space was runtime-only.
    func declaredSources(of space: SpaceID) -> [String] {
        var sources: [String] = []
        if let active = profiles.active,
            active.declaredSpaces.contains(space)
        {
            sources.append("profile:\(active.name)")
        }
        if initDeclaredSpaces.contains(space) {
            sources.append("init.lua")
        }
        if isGuiManaged,
            guiConfigStore.load()?.spaces.contains(space) == true
        {
            sources.append("gui.json")
        }
        return sources
    }
}
