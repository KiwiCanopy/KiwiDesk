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
        return Self.pocketHandleFrame(
            visible: GeometryUtils.axVisibleFrame(of: screen),
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
        let band = ShelfMarkPlacement.bandLength
        let share = max(0, min(position, 100)) / 100
        func lead(_ low: CGFloat, _ high: CGFloat) -> CGFloat {
            let start = low + (high - low) * share - band / 2
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
