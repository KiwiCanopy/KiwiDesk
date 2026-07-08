import Foundation

/// The settings half of the space-reference maintenance
/// (#13/#68): ONE definition each for renaming and removing a
/// space across every per-space map — gap and placement
/// overrides, space icons, and each layout's own override map
/// (#17 — previously orphaned by a rename; deletion previously
/// orphaned all of them). `SpaceMapParityTests` discovers the
/// maps by reflection, so a new per-space map that misses
/// either list fails red instead of silently orphaning.
extension TilingSettings {
    /// Migrates every per-space map keyed by `from` to `to`.
    public mutating func renameSpace(
        from: SpaceID,
        to: SpaceID
    ) {
        move(&gapsOverride, from, to)
        move(&placementOverride, from, to)
        move(&spaceIcons, from, to)
        move(&bsp.override, from, to)
        move(&stack.override, from, to)
        move(&scrolling.override, from, to)
        move(&grid.override, from, to)
        move(&monocle.override, from, to)
    }

    /// Drops `space`'s entry from every per-space map — the
    /// settings half of deleting a space (and, with the empty
    /// id, of pruning hand-edited empty keys).
    public mutating func removeSpace(_ space: SpaceID) {
        gapsOverride[space] = nil
        placementOverride[space] = nil
        spaceIcons[space] = nil
        bsp.override[space] = nil
        stack.override[space] = nil
        scrolling.override[space] = nil
        grid.override[space] = nil
        monocle.override[space] = nil
    }

    private func move<T>(
        _ map: inout [SpaceID: T],
        _ from: SpaceID,
        _ to: SpaceID
    ) {
        if let value = map.removeValue(forKey: from) {
            map[to] = value
        }
    }
}
