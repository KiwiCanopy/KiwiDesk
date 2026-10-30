import CoreGraphics

extension TilingSettings {
    /// The minimum window size `mode` tiles to, the ONE read of the
    /// floor (#2237, `MinWindowSizeReadCensusTests`). A float — any
    /// window `EffectiveFloat.applies` to — and the quit grid read
    /// `.floating`'s, so one window always has one floor.
    ///
    /// `space` is the Space the floor is asked for, nil where none
    /// exists (the quit grid, a GUI preview of the layout's own
    /// value). Its own value (`minWindowSizeOverride`, #2422)
    /// outranks whichever layout value it would replace, a float's
    /// included; Monocle applies none either way.
    public func minWindowSize(
        for mode: LayoutMode,
        in space: SpaceID?
    ) -> MinSize {
        guard let layout = MinWindowSizes.Layout(mode) else {
            return .square(0)
        }
        if let space, let own = minWindowSizeOverride[space] {
            return own
        }
        return minWindowSizes[layout]
    }

    /// `space`'s floor folded onto every layout through the one
    /// read above, the per-Space map then empty —
    /// `resolved(for:)`'s half (#2782).
    mutating func foldMinWindowSize(for space: SpaceID) {
        for layout in MinWindowSizes.Layout.allCases {
            minWindowSizes[layout] = minWindowSize(
                for: layout.mode,
                in: space
            )
        }
        minWindowSizeOverride = [:]
    }
}
