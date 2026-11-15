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
    /// least of every other screen (#3335). Each corner is scored
    /// by the area a screen-sized window parked there by
    /// `stashFrame` overlaps on the other screens — beside, below
    /// or diagonal. Ties, a lone screen and a screen boxed in on
    /// both corners alike park bottom-right, so a desk that
    /// parked clear under the #410 flags keeps its corner. Pure
    /// geometry over AX visible frames; a rect equal to `screen`
    /// is the screen itself (or its mirror) and is not scored.
    nonisolated static func optimalHideCorner(
        for screen: CGRect,
        among others: [CGRect]
    ) -> HideCorner {
        let others = others.filter { $0 != screen }
        let left = parkOverlap(of: screen, at: .bottomLeft, on: others)
        let right = parkOverlap(
            of: screen,
            at: .bottomRight,
            on: others
        )
        return left < right ? .bottomLeft : .bottomRight
    }

    /// Area a screen-sized window parked at `corner` of `screen`
    /// covers on `others`. The screen's size stands in for the
    /// largest window a layout places there, so one corner serves
    /// every window on the screen.
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
        return others.reduce(0) { sum, other in
            let shared = parked.intersection(other)
            return shared.isNull ? sum : sum + shared.width * shared.height
        }
    }

    /// The engine's per-retile neighbor read: `ScreenNeighbors`'
    /// edge flags plus the scored park corner, so a layout's park
    /// (#881) and the stash answer one arrangement alike.
    nonisolated static func screenNeighbors(
        around screen: CGRect,
        among others: [CGRect]
    ) -> ScreenNeighbors {
        var found = ScreenNeighbors.detect(around: screen, among: others)
        found.parkCorner = optimalHideCorner(for: screen, among: others)
        return found
    }

    /// The corner PREFERENCE, one copy: the stash scores screen
    /// rects above, while `MonocleLayout`'s park (#881) arrives
    /// with the neighbors threaded through its context (#878),
    /// which carry that score. Neighbors built without screen
    /// rects (previews, fixtures) fall back to the #410 flags.
    nonisolated static func optimalHideCorner(
        neighbors: ScreenNeighbors
    ) -> HideCorner {
        if let scored = neighbors.parkCorner { return scored }
        if !neighbors.right { return .bottomRight }
        if !neighbors.left { return .bottomLeft }
        return .bottomRight
    }
}
