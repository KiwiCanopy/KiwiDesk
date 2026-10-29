import AppKit

/// The pocket's handle on an edge no bar shows (#2678, 2026-10-29
/// ruling): a fixed mark at Position on the screen's edge, out of
/// which the pocket rises on hover and during a window drag, to the
/// size it has on that edge's bar kept within 20...32 pt.
extension KiwiCore {
    /// The risen pocket's side: the bar's glyph cell, never smaller
    /// than the handle's kiwis nor more than 1.6x them.
    static func pocketRiseSide(thickness: CGFloat) -> CGFloat {
        let cell = SpaceBarItemView.cell(contentDepth: thickness)
        return min(max(cell, PocketHandleView.markSide), 32)
    }

    /// The handle's frame on `display` (AX), risen or at rest.
    func pocketHandleFrame(on display: DisplayID, risen: Bool) -> CGRect? {
        guard let screen = TilingEngine.screen(for: display) else {
            return nil
        }
        let shelf = tiler.settings.kiwishelf
        let depth =
            risen
            ? PocketHandleView.tabDepth + PocketPlateView.lift
                + Self.pocketRiseSide(thickness: shelf.thickness)
            : PocketHandleView.restDepth
        let visible = GeometryUtils.axVisibleFrame(of: screen)
        // In an Auto edge's row of marks, else at Position (#2678).
        if let band = pocketPlate.markBands[display] {
            return Self.pocketHandleFrame(
                visible: visible,
                edge: shelf.pocketEdge,
                band: band,
                depth: depth
            )
        }
        return Self.pocketHandleFrame(
            visible: visible,
            edge: shelf.pocketEdge,
            position: shelf.pocketPosition,
            depth: depth
        )
    }

    /// A band `ShelfMarkPlacement.bandLength` long at `position`
    /// percent along `edge` of `visible`, `depth` deep, kept whole
    /// on the edge.
    static func pocketHandleFrame(
        visible: CGRect,
        edge: AppBarEdge,
        position: CGFloat,
        depth: CGFloat
    ) -> CGRect {
        let share = max(0, min(position, 100)) / 100
        let horizontal = edge.isHorizontal
        let low = horizontal ? visible.minX : visible.minY
        let high = horizontal ? visible.maxX : visible.maxY
        let length = ShelfMarkPlacement.bandLength
        let start = min(
            max(low + (high - low) * share - length / 2, low),
            max(high - length, low)
        )
        return pocketHandleFrame(
            visible: visible,
            edge: edge,
            band: start...(start + length),
            depth: depth
        )
    }

    /// The handle `depth` deep on `edge` of `visible`, along `band`
    /// (AX, along the edge) — its band in an Auto edge's row of
    /// marks, taken as the row laid it.
    static func pocketHandleFrame(
        visible: CGRect,
        edge: AppBarEdge,
        band span: ClosedRange<CGFloat>,
        depth: CGFloat
    ) -> CGRect {
        let band = span.upperBound - span.lowerBound
        switch edge {
        case .bottom:
            return CGRect(
                x: span.lowerBound,
                y: visible.maxY - depth,
                width: band,
                height: depth
            )
        case .top:
            return CGRect(
                x: span.lowerBound,
                y: visible.minY,
                width: band,
                height: depth
            )
        case .left:
            return CGRect(
                x: visible.minX,
                y: span.lowerBound,
                width: depth,
                height: band
            )
        case .right:
            return CGRect(
                x: visible.maxX - depth,
                y: span.lowerBound,
                width: depth,
                height: band
            )
        }
    }

    /// Where a put-in or take-out lands on `display` (AX): the
    /// pocket drawn there — its bar section, or the pocket risen out
    /// of its handle — else nil, where none stands (#2678).
    func pocketLanding(on display: DisplayID) -> CGRect? {
        // The one door for where the pocket is (#2678 review 5).
        guard pocketStands(on: display) else { return nil }
        if let slot = pocketPlate.slots[display] { return slot }
        guard let room = pocketHandleFrame(on: display, risen: true) else {
            return nil
        }
        let rise = Self.pocketRiseSide(
            thickness: tiler.settings.kiwishelf.thickness
        )
        // AX coordinates run down, as the view's flipped bounds do.
        return PocketPlateView.risenFrame(
            in: room,
            edge: tiler.settings.kiwishelf.pocketEdge,
            side: rise
        )
    }

    /// Holds `display`'s pocket out of its handle for a play
    /// `seconds` long, so the window lands on a pocket the screen
    /// shows. The latest play wins on every display: a play on
    /// another screen ends this one's hold, its pocket sinking once
    /// that play's landing has passed.
    func holdPocketOut(on display: DisplayID, for seconds: TimeInterval) {
        let token = UUID()
        pocketPlate.playing = [display: token]
        // A play stands the pocket: its slot opens on the shelf.
        updateBars()
        deferred.schedule(.pocketHold, after: .seconds(seconds)) {
            [weak self] in
            guard let self, self.pocketPlate.playing[display] == token
            else { return }
            self.pocketPlate.playing[display] = nil
            self.updateBars()
        }
    }

    /// The pointer came onto `display`'s handle or left it.
    func pocketHovered(_ display: DisplayID, _ on: Bool) {
        let was = pocketPlate.hovered.contains(display)
        guard was != on else { return }
        if on {
            pocketPlate.hovered.insert(display)
        } else {
            pocketPlate.hovered.remove(display)
        }
        updatePocketPlate()
    }
}
