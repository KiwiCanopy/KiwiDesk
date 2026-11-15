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

    /// Picks the bottom corner whose parked windows cover the
    /// least of the other screens (#3335), beside, below or
    /// diagonal. First by the column every parked window hangs
    /// (`stashPeekX` wide), then by a screen-sized window, so a
    /// corner every window lands on loses to one only wide
    /// windows reach. Ties, a lone screen and a screen boxed in
    /// alike park bottom-right, so a desk that parked clear under
    /// the #410 flags keeps its corner. Pure geometry over AX
    /// visible frames; a rect equal to `screen` is the screen
    /// itself and is not scored.
    nonisolated static func optimalHideCorner(
        for screen: CGRect,
        among others: [CGRect]
    ) -> HideCorner {
        let others = others.filter { $0 != screen }
        func score(_ corner: HideCorner) -> (CGFloat, CGFloat) {
            (
                parkOverlap(
                    of: screen,
                    at: corner,
                    width: stashPeekX,
                    on: others
                ),
                parkOverlap(
                    of: screen,
                    at: corner,
                    width: screen.width,
                    on: others
                )
            )
        }
        return score(.bottomLeft) < score(.bottomRight)
            ? .bottomLeft : .bottomRight
    }

    /// Area a window `width` wide and as tall as `screen`, parked
    /// at `corner` by `stashFrame`, covers on `others`.
    nonisolated static func parkOverlap(
        of screen: CGRect,
        at corner: HideCorner,
        width: CGFloat,
        on others: [CGRect]
    ) -> CGFloat {
        let parked = stashFrame(
            CGRect(x: 0, y: 0, width: width, height: screen.height),
            in: screen,
            corner: corner
        )
        return others.reduce(0) { sum, other in
            let shared = parked.intersection(other)
            return shared.isNull ? sum : sum + shared.width * shared.height
        }
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
