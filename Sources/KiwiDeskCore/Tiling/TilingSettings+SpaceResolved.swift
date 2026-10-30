import Foundation

/// One Space's settings with every per-Space map resolved onto
/// the global it overrides (#2782) — a hand list of the maps, held
/// to the others by `SpaceMapParityTests`.
extension TilingSettings {
    /// The layouts whose params carry `newWindowPlacement`, which
    /// a Space's `placementOverride` outranks: the spawn map
    /// `KiwiCore.handle` hands State and `resolved(for:)` both read
    /// it. State's own default map is a bare fallback it replaces.
    static var spawnPlacementPaths:
        [(LayoutMode, WritableKeyPath<TilingSettings, SpawnPlacement>)]
    {
        [
            (.bsp, \.bsp.newWindowPlacement),
            (.stack, \.stack.newWindowPlacement),
            (.scrolling, \.scrolling.newWindowPlacement),
            (.grid, \.grid.newWindowPlacement),
            (.monocle, \.monocle.newWindowPlacement),
        ]
    }

    /// These settings as `space` uses them: each override folded
    /// in through the `resolved*(for:)` readers and the override
    /// maps emptied; `spaceIcons` keeps only the Space's own icon,
    /// which overrides nothing. Config only, like those readers —
    /// a size a resize moved is the session layer's.
    public func resolved(for space: SpaceID) -> TilingSettings {
        var out = self
        out.gapsGlobal = gaps(for: space)
        out.gapsOverride = [:]
        out.foldMinWindowSize(for: space)
        out.bsp = resolvedBsp(for: space)
        out.stack = resolvedStack(for: space)
        out.scrolling = resolvedScrolling(for: space)
        out.grid = resolvedGrid(for: space)
        out.monocle = resolvedMonocle(for: space)
        out.track = resolvedTrack(for: space)
        if let own = placementOverride[space] {
            for (_, path) in Self.spawnPlacementPaths {
                out[keyPath: path] = own
            }
        }
        out.placementOverride = [:]
        out.spaceIcons = spaceIcons[space].map { [space: $0] } ?? [:]
        return out
    }
}
