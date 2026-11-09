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
        move(&minWindowSizeOverride, from, to)
        move(&placementOverride, from, to)
        move(&tiling.startOverride, from, to)
        move(&spaceIcons, from, to)
        move(&bsp.override, from, to)
        move(&stack.override, from, to)
        move(&scrolling.override, from, to)
        move(&grid.override, from, to)
        move(&monocle.override, from, to)
        move(&track.override, from, to)
        move(&maximize.shareOverride, from, to)
        move(&maximize.anchorOverride, from, to)
    }

    /// Drops `space`'s entry from every per-space map — the
    /// settings half of deleting a space (and, with the empty
    /// id, of pruning hand-edited empty keys).
    public mutating func removeSpace(_ space: SpaceID) {
        gapsOverride[space] = nil
        minWindowSizeOverride[space] = nil
        placementOverride[space] = nil
        tiling.startOverride[space] = nil
        spaceIcons[space] = nil
        bsp.override[space] = nil
        stack.override[space] = nil
        scrolling.override[space] = nil
        grid.override[space] = nil
        monocle.override[space] = nil
        track.override[space] = nil
        maximize.shareOverride[space] = nil
        maximize.anchorOverride[space] = nil
    }

    /// Takes `space`'s entry in every per-space map from `other`,
    /// an absent one included — the settings half of putting back
    /// a deleted Space (#792).
    public mutating func restoreSpace(
        _ space: SpaceID,
        from other: TilingSettings
    ) {
        gapsOverride[space] = other.gapsOverride[space]
        minWindowSizeOverride[space] =
            other.minWindowSizeOverride[space]
        placementOverride[space] = other.placementOverride[space]
        tiling.startOverride[space] = other.tiling.startOverride[space]
        spaceIcons[space] = other.spaceIcons[space]
        bsp.override[space] = other.bsp.override[space]
        stack.override[space] = other.stack.override[space]
        scrolling.override[space] = other.scrolling.override[space]
        grid.override[space] = other.grid.override[space]
        monocle.override[space] = other.monocle.override[space]
        track.override[space] = other.track.override[space]
        maximize.shareOverride[space] =
            other.maximize.shareOverride[space]
        maximize.anchorOverride[space] =
            other.maximize.anchorOverride[space]
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
