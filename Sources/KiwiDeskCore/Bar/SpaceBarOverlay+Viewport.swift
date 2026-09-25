import AppKit

/// Viewport placement and hit-frame tracking for SpaceBarOverlay.
extension SpaceBarOverlay {
    /// Positions the clipping viewport and returns the rect so
    /// the glass plate can adopt it as its `contentView` frame.
    @discardableResult
    func placeItemContainer(
        inset: CGFloat,
        viewport: CGFloat,
        strip: CGRect,
        horizontal: Bool
    ) -> CGRect {
        let frame =
            horizontal
            ? CGRect(
                x: inset,
                y: 0,
                width: viewport,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: inset,
                width: strip.width,
                height: viewport
            )
        itemContainer.frame = frame
        return frame
    }

    /// Records the drag-drop hit frames in strip-local
    /// coordinates, offset by the viewport origin and clamped to
    /// the CLEAR part of the viewport (#385, #1517): a point over a
    /// fading end — the autoscroll's zone — or a scrolled-off item
    /// resolves to no Space, so the two never contend.
    func recordHitFrames(
        items: [Item],
        frames: [CGRect],
        strip: CGRect,
        fades: ShelfOverflow.Fades,
        horizontal: Bool
    ) {
        hitStrip = strip
        // Item frames are viewport-relative, so they offset by the
        // viewport's own origin; only the INTERSECTION stops at
        // the fades.
        let viewport = itemContainer.frame
        let clear = fades.clear(of: viewport, horizontal: horizontal)
        hitFrames = zip(items, frames).compactMap { item, frame in
            // The layer item is no drop target (#1169).
            guard let space = item.space else { return nil }
            let stripLocal = frame.offsetBy(
                dx: viewport.minX,
                dy: viewport.minY
            )
            let visible = stripLocal.intersection(clear)
            guard !visible.isNull, visible.width >= 1,
                visible.height >= 1
            else { return nil }
            return (space, visible)
        }
    }
}
