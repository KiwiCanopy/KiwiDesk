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
