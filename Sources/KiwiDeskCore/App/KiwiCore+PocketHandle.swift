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
        if let centre = pocketPlate.markCentres[display] {
            return Self.pocketHandleFrame(
                visible: visible,
                edge: shelf.pocketEdge,
                centre: centre,
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
        return pocketHandleFrame(
            visible: visible,
            edge: edge,
            centre: low + (high - low) * share,
            depth: depth
        )
    }

    /// A band `ShelfMarkPlacement.bandLength` long centred on
    /// `centre` (AX, along `edge`) of `visible`, `depth` deep, kept
    /// whole on the edge.
    static func pocketHandleFrame(
        visible: CGRect,
        edge: AppBarEdge,
        centre: CGFloat,
        depth: CGFloat
    ) -> CGRect {
        let band = ShelfMarkPlacement.bandLength
        func lead(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
            let start = centre - band / 2
            return min(max(start, low), max(high - band, low))
        }
        switch edge {
        case .bottom:
            return CGRect(
                x: lead(visible.minX, visible.maxX),
                y: visible.maxY - depth,
                width: band,
                height: depth
            )
        case .top:
            return CGRect(
                x: lead(visible.minX, visible.maxX),
                y: visible.minY,
                width: band,
                height: depth
            )
        case .left:
            return CGRect(
                x: visible.minX,
                y: lead(visible.minY, visible.maxY),
                width: depth,
                height: band
            )
        case .right:
            return CGRect(
                x: visible.maxX - depth,
                y: lead(visible.minY, visible.maxY),
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
        guard pocketStands, !pocketPlate.standingDown.contains(display)
        else { return nil }
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
    /// shows; a later play replaces the hold, on any display.
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
