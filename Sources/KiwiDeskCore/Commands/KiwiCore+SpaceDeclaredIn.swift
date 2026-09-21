import Foundation

/// Which declarations bring a deleted Space back on the next
/// config load (#1509) — the fact `delete_space` carries in its
/// payload so a runtime removal is never mistaken for a durable
/// one.
extension KiwiCore {
    /// Every source that re-creates `space` at the next load, in
    /// the payload's spelling: `profile:<name>` for the active
    /// profile and `standard:<name>` for a resolving built-in
    /// Standard — both the last APPLY's set, read from adoption
    /// state and never a file or a recompose (#1245; a hand edit
    /// lands at the next apply); `init.lua` for a Space the last
    /// script run asked for; `gui.json` for a GUI-managed sidecar
    /// listing it. Empty when the Space was runtime-only.
    func declaredSources(of space: SpaceID) -> [String] {
        var sources: [String] = []
        if let active = profiles.active,
            active.declaredSpaces.contains(space)
        {
            sources.append("profile:\(active.name)")
        }
        if let standard = profiles.standard,
            standard.spaces.contains(space)
        {
            sources.append("standard:\(standard.name)")
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
