import AppKit

/// The panel's room (#2497): the panel takes the mouse wherever it
/// lies, so at rest it covers only what the shelf draws and the
/// mouse reaches the windows beside it, as the marks do. The strip
/// view keeps strip coordinates, offset inside the smaller panel.
extension ShelfOverlay {
    /// What the shelf draws at rest, in strip coordinates and the
    /// strip's whole depth: the plate's span, or under Boxed the
    /// span of the sections' plate asks, which hold their boxes,
    /// counts and fades; the sections' slots where nothing asks.
    nonisolated static func restingRoom(
        sections: [Section],
        strip: CGRect,
        horizontal: Bool,
        shelf: KiwiShelf
    ) -> CGRect {
        let length = horizontal ? strip.width : strip.height
        let along = { (rect: CGRect) -> ClosedRange<CGFloat> in
            horizontal ? rect.minX...rect.maxX : rect.minY...rect.maxY
        }
        let asks = sections.compactMap { section -> ClosedRange<CGFloat>? in
            guard !section.plate.isEmpty else { return nil }
            return along(
                section.plate.offsetBy(
                    dx: section.slot.minX - strip.minX,
                    dy: section.slot.minY - strip.minY
                )
            )
        }
        let slots = sections.map { along(slotFrame($0, in: strip)) }
        let plate = ShelfArrangement.plateSpan(
            asks: asks,
            length: length,
            shelf: shelf
        )
        let span = plate ?? hull(asks) ?? hull(slots) ?? 0...length
        let low = min(max(span.lowerBound, 0), length)
        let high = min(max(span.upperBound, low), length)
        return horizontal
            ? CGRect(x: low, y: 0, width: high - low, height: strip.height)
            : CGRect(x: 0, y: low, width: strip.width, height: high - low)
    }

    private nonisolated static func hull(
        _ spans: [ClosedRange<CGFloat>]
    ) -> ClosedRange<CGFloat>? {
        guard let first = spans.first else { return nil }
        return spans.dropFirst().reduce(first) {
            min(
                $0.lowerBound,
                $1.lowerBound
            )...max($0.upperBound, $1.upperBound)
        }
    }

    /// Opens the room to the whole strip for a plate glide and
    /// settles it once the glide lands. A reveal's clip is placed
    /// in the panel's coordinates, so the room never moves while
    /// anything travels — the strip is the one room every motion
    /// fits.
    func holdRoomForGlide() {
        roomHolds += 1
        openRoom()
        afterRoomGlide { [weak self] in
            guard let self else { return }
            self.roomHolds -= 1
            self.settleRoom()
        }
    }

    /// The whole strip, for a motion in flight.
    func openRoom() {
        guard let strip = drawn?.strip else { return }
        placeRoom(CGRect(origin: .zero, size: strip.size), strip: strip)
    }

    /// The resting room, unless a glide, a reveal or a leave is
    /// still in flight — each lands by settling again.
    func settleRoom() {
        guard roomHolds == 0, revealing == nil, leaving == nil,
            let strip = drawn?.strip
        else { return }
        placeRoom(restRoom, strip: strip)
    }

    /// Sizes the panel to `room` (strip coordinates) and offsets
    /// the content so the strip stays where it is on screen.
    private func placeRoom(_ wanted: CGRect, strip: CGRect) {
        guard let panel else { return }
        // A window frame is whole points; widened to them, the
        // content stays put on screen.
        let frame = wanted.offsetBy(dx: strip.minX, dy: strip.minY).integral
        let room = frame.offsetBy(dx: -strip.minX, dy: -strip.minY)
        let target = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        content.frame = CGRect(
            origin: CGPoint(x: -room.minX, y: -room.minY),
            size: strip.size
        )
        if panel.frame != target { panel.setFrame(target, display: true) }
    }
}
