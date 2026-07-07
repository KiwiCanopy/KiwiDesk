import Foundation

extension TilingSettings {
    /// Migrates every per-space map keyed by `from` to `to` —
    /// the settings half of `GuiConfig.renameSpace` (#13). One
    /// definition so a new per-space map added here cannot be
    /// forgotten by the config-level rename: gap and placement
    /// overrides, space icons, and each layout's own override
    /// map (#17 — previously orphaned by a rename).
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
