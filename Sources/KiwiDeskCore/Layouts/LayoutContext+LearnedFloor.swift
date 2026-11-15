import CoreGraphics

extension LayoutContext {
    /// One window's floor along one axis — widths for
    /// `horizontal`, heights otherwise: the larger of
    /// `min_window_size` and its corroborated learned minimum
    /// (#1355, #763). The pure twin of the clamps'
    /// `KiwiCore.effectiveMinSize`; Track's cap and Grid's tracks
    /// both read it.
    public func learnedFloor(
        of id: WindowID,
        horizontal: Bool
    ) -> CGFloat {
        let bound = sizeBounds[id]
        let learned = horizontal ? bound?.minWidth : bound?.minHeight
        return max(
            minWindowSize.along(horizontal: horizontal),
            learned ?? 0
        )
    }
}

extension LayoutContext {
    /// `learnedFloor`'s mirror (#1488, #3217): one window's
    /// corroborated learned maximum along one axis, nil where
    /// none — no configured ceiling stands in the way
    /// `min_window_size` does for the floor. Track's heal and the
    /// split layouts' ceiling pass both read it.
    public func learnedCeiling(
        of id: WindowID,
        horizontal: Bool
    ) -> CGFloat? {
        let bound = sizeBounds[id]
        return horizontal ? bound?.maxWidth : bound?.maxHeight
    }
}
