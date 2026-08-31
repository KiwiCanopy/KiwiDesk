import AppKit

/// Drag-drop hit testing and visual feedback for SpaceBarOverlay (#372).
extension SpaceBarOverlay {

    /// Returns SpaceID whose item contains global screen point, or nil.
    func spaceItem(atGlobal cocoaPoint: CGPoint) -> SpaceID? {
        guard isPanelVisible else { return nil }
        let ax = GeometryUtils.axPoint(cocoaPoint)
        guard hitStrip.contains(ax) else { return nil }
        let local = CGPoint(
            x: ax.x - hitStrip.minX,
            y: ax.y - hitStrip.minY
        )
        return hitFrames.first { $0.frame.contains(local) }?.space
    }

    /// Tints `space`'s item with the synthetic drag-hover and
    /// clears every other item — nil clears all.
    func setDragHover(_ space: SpaceID?) {
        for view in itemViews {
            view.setDragHover(view.space == space)
        }
    }

    /// Starts the pending-spring sweep on `space`'s item — empty
    /// for `delay`, then filling over `duration`.
    func beginSpringSweep(
        on space: SpaceID,
        duration: TimeInterval,
        delay: TimeInterval
    ) {
        for view in itemViews where view.space == space {
            view.beginSpringSweep(
                duration: duration,
                delay: delay
            )
        }
    }

    /// Clears any hover tint and pending sweep across all items —
    /// the drag left the bar or ended.
    func clearDragFeedback() {
        for view in itemViews {
            view.setDragHover(false)
            view.cancelSpringSweep()
        }
    }
}
