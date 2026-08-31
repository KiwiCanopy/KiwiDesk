import AppKit

/// Viewport placement and hit-frame tracking for SpaceBarOverlay.
extension SpaceBarOverlay {
    /// Positions clipping viewport and returns frame.
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
    /// the visible viewport (#385): a point over an arrow zone or
    /// a scrolled-off item resolves to no Space.
    func recordHitFrames(
        items: [Item],
        frames: [CGRect],
        strip: CGRect
    ) {
        hitStrip = strip
        let container = itemContainer.frame
        hitFrames = zip(items, frames).compactMap { item, frame in
            let stripLocal = frame.offsetBy(
                dx: container.minX,
                dy: container.minY
            )
            let visible = stripLocal.intersection(container)
            guard !visible.isNull, visible.width >= 1,
                visible.height >= 1
            else { return nil }
            return (item.space, visible)
        }
    }
}
