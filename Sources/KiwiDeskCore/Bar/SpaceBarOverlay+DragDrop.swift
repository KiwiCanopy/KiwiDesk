import AppKit

/// Drag-drop routing for the Space Bar overlay (#372): the
/// point-based hit test and the per-item hover / spring-sweep
/// cues. The dwell timing and the spring decision live on the
/// driver (`KiwiCore`); the overlay only maps a cursor point to a
/// Space and forwards the visual cues to the matching item view.
extension SpaceBarOverlay {

    /// The Space whose item contains a global (Cocoa, bottom-
    /// left) screen point, or nil when the point is off the strip
    /// or over a gap. Point-based — the cursor location, never
    /// the dragged window's frame: a maximized window can graze
    /// the bar while its grab point is far away. Glyphs and the
    /// "+n" badge are not separate targets; the whole item is one
    /// drop well.
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

    /// Starts the pending-spring sweep on `space`'s item.
    func beginSpringSweep(
        on space: SpaceID,
        duration: TimeInterval
    ) {
        for view in itemViews where view.space == space {
            view.beginSpringSweep(duration: duration)
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
