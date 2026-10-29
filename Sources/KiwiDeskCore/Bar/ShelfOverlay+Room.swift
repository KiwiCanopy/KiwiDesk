import AppKit

/// The panel's room (#2497): the panel takes the mouse wherever it
/// lies, so at rest it covers only what the shelf draws and the
/// mouse reaches the windows beside it, as the marks do. The strip
/// view keeps strip coordinates, offset inside the smaller panel.
extension ShelfOverlay {
    /// What the shelf draws at rest, in strip coordinates and the
    /// strip's whole depth: `plate`, or under Boxed the span of the
    /// sections' plate asks, which hold their boxes, counts and
    /// fades; the sections' slots where nothing asks. Every room
    /// keeps the strip's depth and far side, which the hover peek
    /// reads off the panel's frame (`BarPeek`).
    nonisolated static func restingRoom(
        plate: CGRect?,
        sections: [Section],
        strip: CGRect,
        horizontal: Bool
    ) -> CGRect {
        if let plate { return plate }
        let along = { (rect: CGRect) -> ClosedRange<CGFloat> in
            horizontal ? rect.minX...rect.maxX : rect.minY...rect.maxY
        }
        let asks = plateAsks(
            sections: sections,
            strip: strip,
            horizontal: horizontal
        )
        let slots = sections.map { along(slotFrame($0, in: strip)) }
        let length = horizontal ? strip.width : strip.height
        let span = hull(asks) ?? hull(slots) ?? 0...length
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

    /// The room a slide travels through: the resting room run out
    /// past the strip's screen side to the usable area's edge — the
    /// outer margin — where the panel clips the content, so the
    /// shelf comes out from under the menu bar or the screen edge.
    nonisolated static func slideRoom(
        _ rest: CGRect,
        edge: AppBarEdge,
        gap: CGFloat
    ) -> CGRect {
        let gap = max(gap, 0)
        switch edge {
        case .top:
            return CGRect(
                x: rest.minX,
                y: rest.minY - gap,
                width: rest.width,
                height: rest.height + gap
            )
        case .bottom:
            return CGRect(
                x: rest.minX,
                y: rest.minY,
                width: rest.width,
                height: rest.height + gap
            )
        case .left:
            return CGRect(
                x: rest.minX - gap,
                y: rest.minY,
                width: rest.width + gap,
                height: rest.height
            )
        case .right:
            return CGRect(
                x: rest.minX,
                y: rest.minY,
                width: rest.width + gap,
                height: rest.height
            )
        }
    }

    /// A show whose resting room moved while the shelf stays on
    /// screen: the room takes both ends of the plate glide until it
    /// lands; one whose room is unchanged settles at once.
    func holdRoomForGlide() {
        guard let placed = placedRoom, placed != restRoom else {
            settleRoom()
            return
        }
        let token = UUID()
        roomGlide = token
        // A union, so a slide in flight keeps its margin too.
        widenRoom(to: restRoom)
        if let rest = pocket.rest, let strip = drawn?.strip {
            pocket.placeRoom(
                pocket.placedRoom.map { $0.union(rest) } ?? rest,
                strip: strip
            )
        }
        afterGlide { [weak self] in
            guard let self, self.roomGlide == token else { return }
            self.roomGlide = nil
            self.settleRoom()
        }
    }

    /// The room the reveal or retract about to play moves through,
    /// read off the motion it resolves to: a slide's run out over
    /// the margin, a grow's the plate and the hovered mark, an
    /// unfold's those grown by its springs' swing along the edge, a
    /// fade's none. A grow's and a plate unfold's clip is placed in
    /// the panel's coordinates, so its room then holds still until
    /// it lands (`growing`).
    func openRevealRoom(entering: Bool) {
        guard let drawn else { return }
        growing = false
        switch BarMotion.resolvedReveal(revealPath, entering: entering) {
        case .slide:
            widenRoom(
                to: Self.slideRoom(restRoom, edge: drawn.edge, gap: revealGap)
            )
        case .morph(let morph):
            widenRoom(to: restRoom.union(morph.mark))
            growing = true
        case .unfold(let stretch):
            let length =
                stretch.horizontal
                ? stretch.plate.width : stretch.plate.height
            widenRoom(
                to: ShelfUnfold.room(
                    restRoom.union(stretch.mark),
                    travel: length / 2,
                    bounce: ShelfUnfold.alongBounce,
                    horizontal: stretch.horizontal
                )
            )
            growing = true
        case .spread(let spread):
            let held = restRoom.union(
                CGRect(origin: spread.mark, size: .zero)
            )
            let travel =
                spread.horizontal
                ? max(spread.mark.x - held.minX, held.maxX - spread.mark.x)
                : max(spread.mark.y - held.minY, held.maxY - spread.mark.y)
            widenRoom(
                to: ShelfUnfold.room(
                    held,
                    travel: travel,
                    bounce: ShelfUnfold.spreadBounce,
                    horizontal: spread.horizontal
                )
            )
        case .fade:
            break
        }
    }

    /// The resting room, unless a glide, a reveal or a leave is
    /// still in flight: a glide's and a reveal's landing settle
    /// again, and a leave ends ordered out, the next show settling.
    func settleRoom() {
        guard roomGlide == nil, revealing == nil, leaving == nil, !growing,
            let strip = drawn?.strip
        else { return }
        placeRoom(restRoom, strip: strip)
        pocket.placeRoom(nil, strip: strip)
    }

    /// The room placed now, grown to cover `rect` as well — save
    /// while a grow plays, whose clip a moved room would displace.
    private func widenRoom(to rect: CGRect) {
        guard !growing, let strip = drawn?.strip else { return }
        placeRoom(placedRoom.map { $0.union(rect) } ?? rect, strip: strip)
    }

    /// Sizes the panel to `wanted` (strip coordinates) and offsets
    /// the content so the strip stays where it is on screen.
    private func placeRoom(_ wanted: CGRect, strip: CGRect) {
        guard let panel else { return }
        // A window frame is whole points; widened to them, the
        // content stays put on screen.
        let frame = wanted.offsetBy(dx: strip.minX, dy: strip.minY).integral
        let room = frame.offsetBy(dx: -strip.minX, dy: -strip.minY)
        placedRoom = wanted
        content.frame = CGRect(
            origin: CGPoint(x: -room.minX, y: -room.minY),
            size: strip.size
        )
        let target = GeometryUtils.flip(
            frame,
            primaryHeight: GeometryUtils.primaryHeight
        )
        if panel.frame != target { panel.setFrame(target, display: true) }
    }
}
