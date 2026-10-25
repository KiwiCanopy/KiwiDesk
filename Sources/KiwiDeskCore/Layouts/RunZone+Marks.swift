import CoreGraphics

extension RunZone {
    /// The bounds the run's overflow marks sit flush with: the
    /// layout bounds, save an end facing a window inside the
    /// usable area, where the mark straddles the inner gap
    /// (#2542, owner 2026-10-25).
    public func markBounds(in context: LayoutContext) -> CGRect {
        let usable = context.usable
        let reach =
            (vertical
                ? context.gaps.inner.vertical
                : context.gaps.inner.horizontal) / 2
            + OverflowMark.depth / 2
        var bounds = context.bounds
        if vertical {
            if region.minY > usable.minY + 0.5 {
                bounds.size.height = bounds.maxY - (region.minY - reach)
                bounds.origin.y = region.minY - reach
            }
            if region.maxY < usable.maxY - 0.5 {
                bounds.size.height = region.maxY + reach - bounds.minY
            }
        } else {
            if region.minX > usable.minX + 0.5 {
                bounds.size.width = bounds.maxX - (region.minX - reach)
                bounds.origin.x = region.minX - reach
            }
            if region.maxX < usable.maxX - 0.5 {
                bounds.size.width = region.maxX + reach - bounds.minX
            }
        }
        return bounds
    }
}
