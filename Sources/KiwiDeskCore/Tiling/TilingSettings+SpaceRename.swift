import Foundation

/// Space rename/remove migration across per-space maps
/// (`SpaceMapParityTests`, #13, #17, #68).
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
        move(&track.override, from, to)
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
        track.override[space] = nil
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
