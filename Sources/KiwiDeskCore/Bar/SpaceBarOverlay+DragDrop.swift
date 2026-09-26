import AppKit

/// Drag-drop hit testing and visual feedback for SpaceBarOverlay (#372).
extension SpaceBarOverlay {

    /// Returns SpaceID whose item contains the CURSOR point, never
    /// the dragged window's frame — a maximized window can graze
    /// the bar while its grab point is far away. The whole item
    /// is one drop well.
    func spaceItem(atGlobal cocoaPoint: CGPoint) -> SpaceID? {
        guard isVisible else { return nil }
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
            // `space == nil` clears; a layer item's nil never
            // matches it (#1169).
            view.setDragHover(space != nil && view.space == space)
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
        // A render during the drag may have hovered the chip under
        // the pointer, and another app's drag sends us no exit.
        syncHoverToPointer()
    }

    /// Re-reads every hover this section draws from the resting
    /// pointer (#1665); `ShelfManager.relayout` calls it once the
    /// section is placed.
    func syncHoverToPointer() {
        for view in itemViews { view.syncHoverToPointer() }
        backCount.syncHoverToPointer()
        forwardCount.syncHoverToPointer()
    }
}
