import CoreGraphics

extension TilingSettings {
    /// The minimum window size `mode` tiles to, the ONE read of the
    /// floor (#2237, `MinWindowSizeReadCensusTests`). A float — any
    /// window `EffectiveFloat.applies` to — and the quit grid read
    /// `.floating`'s, so one window always has one floor.
    ///
    /// `space` is the Space the floor is asked for, nil where none
    /// exists (the quit grid, a GUI preview of the layout's own
    /// value). It is required so a per-Space level (#2422) joins
    /// here without touching a consumer. Monocle applies none.
    public func minWindowSize(
        for mode: LayoutMode,
        in space: SpaceID?
    ) -> MinSize {
        guard let layout = MinWindowSizes.Layout(mode) else {
            return .square(0)
        }
        return minWindowSizes[layout]
    }
}
