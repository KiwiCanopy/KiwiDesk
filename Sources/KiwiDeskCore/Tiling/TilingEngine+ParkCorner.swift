import CoreGraphics

// MARK: - Choosing the park corner

extension TilingEngine {
    /// The bottom corner a stashed window parks in. Chosen per
    /// monitor (`optimalHideCorner`) so the window's body — which
    /// hangs ~its full width off the parked side — spills into
    /// dead space, not onto a neighbor display (#410).
    enum HideCorner: Sendable {
        case bottomLeft
        case bottomRight
    }

    /// Picks the bottom corner whose parked window covers the
    /// least of the other screens (#3335): the area a screen-sized
    /// window parked there by `stashFrame` overlaps on them,
    /// beside, below or diagonal. Ties, a lone screen and a screen
    /// boxed in alike park bottom-right, so a desk that parked
    /// clear stays clear. Trade: area weighs a large screen a wide
    /// window reaches above a narrow one every window lands on.
    /// Pure geometry over AX visible frames; a rect overlapping
    /// `screen` is the screen itself (or its mirror), not scored.
    nonisolated static func optimalHideCorner(
        for screen: CGRect,
        among others: [CGRect]
    ) -> HideCorner {
        let others = others.filter { area($0.intersection(screen)) == 0 }
        let left = parkOverlap(of: screen, at: .bottomLeft, on: others)
        let right = parkOverlap(
            of: screen,
            at: .bottomRight,
            on: others
        )
        return left < right ? .bottomLeft : .bottomRight
    }

    /// Area a screen-sized window parked at `corner` of `screen`
    /// covers on `others`.
    nonisolated static func parkOverlap(
        of screen: CGRect,
        at corner: HideCorner,
        on others: [CGRect]
    ) -> CGFloat {
        let parked = stashFrame(
            CGRect(origin: .zero, size: screen.size),
            in: screen,
            corner: corner
        )
        return others.reduce(0) { $0 + area(parked.intersection($1)) }
    }

    private nonisolated static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }

    /// The corner a layout's park takes (#881): the one
    /// `ScreenNeighbors.detect` scored over the screen rects, so
    /// it and the stash answer one arrangement alike.
    nonisolated static func optimalHideCorner(
        neighbors: ScreenNeighbors
    ) -> HideCorner {
        neighbors.parkCorner
    }
}
