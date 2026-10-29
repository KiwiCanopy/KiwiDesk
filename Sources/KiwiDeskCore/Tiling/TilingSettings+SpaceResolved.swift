import Foundation

/// One Space's settings with every per-Space map resolved onto
/// the global it overrides (#2782) — a hand list of the maps, held
/// to the others by `SpaceMapParityTests`.
extension TilingSettings {
    /// These settings as `space` uses them: each override folded
    /// in through the `resolved*(for:)` readers, every per-Space
    /// map then empty. Config only, like those readers — a size a
    /// resize moved is the session layer's, not a setting.
    public func resolved(for space: SpaceID) -> TilingSettings {
        var out = self
        out.gapsGlobal = gaps(for: space)
        out.gapsOverride = [:]
        if let own = minWindowSizeOverride[space] {
            for layout in MinWindowSizes.Layout.allCases {
                out.minWindowSizes[layout] = own
            }
        }
        out.minWindowSizeOverride = [:]
        out.bsp = resolvedBsp(for: space)
        out.stack = resolvedStack(for: space)
        out.scrolling = resolvedScrolling(for: space)
        out.grid = resolvedGrid(for: space)
        out.monocle = resolvedMonocle(for: space)
        out.track = resolvedTrack(for: space)
        if let own = placementOverride[space] {
            out.bsp.newWindowPlacement = own
            out.stack.newWindowPlacement = own
            out.scrolling.newWindowPlacement = own
            out.grid.newWindowPlacement = own
            out.monocle.newWindowPlacement = own
        }
        out.placementOverride = [:]
        out.spaceIcons = spaceIcons[space].map { [space: $0] } ?? [:]
        return out
    }
}
