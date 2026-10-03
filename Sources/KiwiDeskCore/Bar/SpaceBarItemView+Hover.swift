import AppKit

/// The item's pointer readings: the hover fill and hovered target
/// (#1528), re-read where the pointer rests (#1665), and whether
/// the pointer is on the chip at all — the strip hold's reading
/// (#1528 item 21).
extension SpaceBarItemView {
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(
            NSTrackingArea(
                rect: bounds,
                options: [
                    .mouseEnteredAndExited, .mouseMoved, .activeAlways,
                ],
                owner: self
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        refreshHover(event)
    }

    override func mouseMoved(with event: NSEvent) {
        refreshHover(event)
    }

    override func mouseExited(with event: NSEvent) {
        setPointerInside(false)
        guard isHovered || hoveredTarget != nil else { return }
        isHovered = false
        hoveredTarget = nil
        restyle()
    }

    /// Hovered only while the pointer is on THIS view — a count
    /// drawn over the faded end takes the pointer there (#1517);
    /// the hover fill promises a click, and a layer item has none.
    func refreshHover(_ event: NSEvent) {
        applyHover(
            BarHoverHit.owns(self, event),
            target: targetsForHover.first {
                BarHoverHit.owns($0, event)
            }
        )
    }

    /// Re-reads the hover from where the pointer rests (#1665) —
    /// the shelf's placement moves a chip without an exit event.
    func syncHoverToPointer() {
        applyHover(
            BarHoverHit.ownsPointer(self),
            target: targetsForHover.first(where: BarHoverHit.ownsPointer)
        )
    }

    func applyHover(
        _ ownsPointer: Bool,
        target: SpaceBarGlyphTarget?
    ) {
        setPointerInside(ownsPointer)
        let hovered = !isActive && space != nil && ownsPointer
        guard hovered != isHovered || target !== hoveredTarget else {
            return
        }
        isHovered = hovered
        hoveredTarget = target
        reportTitleHover(target)
        restyle()
    }

    /// Records where the pointer rests, reporting a Space chip's
    /// entry and exit once each (#1528 item 21).
    func setPointerInside(_ inside: Bool) {
        let inside = inside && space != nil
        guard inside != pointerInside else { return }
        pointerInside = inside
        if !inside { reportTitleHover(nil) }
        if let space { onPointerInside(space, drawn, inside) }
    }
}
