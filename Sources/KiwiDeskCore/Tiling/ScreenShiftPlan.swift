import CoreGraphics

/// One screen of macOS's Displays arrangement, as the boxed-in
/// verdict reads it (#2756). Both rects are global CG
/// coordinates, y growing down, the space AX frames share.
public struct ArrangedScreen: Sendable, Equatable {
    /// The display's UUID: a `CGDirectDisplayID` changes on every
    /// reconnect (measured on #2756's spike), the UUID does not.
    public let id: String
    public let name: String
    public var frame: CGRect
    /// The usable area the stash parks against.
    public var visible: CGRect
    public let isMain: Bool
    /// The display this is, for a GUI matching it to its card.
    public let display: DisplayID?

    public init(
        id: String,
        name: String,
        frame: CGRect,
        visible: CGRect? = nil,
        isMain: Bool = false,
        display: DisplayID? = nil
    ) {
        self.id = id
        self.name = name
        self.frame = frame
        self.visible = visible ?? frame
        self.isMain = isMain
        self.display = display
    }

    func moved(by delta: CGVector) -> ArrangedScreen {
        var copy = self
        copy.frame = frame.offsetBy(dx: delta.dx, dy: delta.dy)
        copy.visible = visible.offsetBy(dx: delta.dx, dy: delta.dy)
        return copy
    }
}

/// One screen's move in the arrangement.
public struct ScreenShift: Sendable, Equatable {
    /// The screen that moves.
    public let screen: String
    /// Points, y growing down: a positive `dy` lowers the screen.
    public let delta: CGVector
    /// The shared edges this move shifts, so the pointer crosses
    /// there at another place; each edge is listed once, under the
    /// first moved screen of its pair.
    public let crossings: [ScreenCrossing]
}

/// A shared edge whose crossing moves: the screen across it, and
/// how far the moved screen shifts against it along the edge.
public struct ScreenCrossing: Sendable, Equatable {
    public let screen: String
    /// Points along the shared edge, y growing down; the other
    /// axis is zero.
    public let delta: CGVector
}

/// A screen whose parked windows land on another screen,
/// because both of its bottom corners are covered (#2754).
public struct BoxedInScreen: Sendable, Equatable {
    /// What covers the two bottom corners.
    public enum Cause: Sendable, Equatable {
        case corners(left: String, right: String)
        /// One screen below reaches under both corners.
        case belowBoth(String)
    }

    public let screen: String
    /// The screen the parked windows cover most at the corner the
    /// stash picks (`TilingEngine.optimalHideCorner`).
    public let landsOn: String
    public let cause: Cause
}

/// The one offer an arrangement gets (#2756 ▸ Amendment "one
/// offer per arrangement"): every boxed-in screen, and the set of
/// moves that frees them all.
public struct ScreenOffer: Sendable, Equatable {
    public let boxed: [BoxedInScreen]
    /// Empty where no set of moves frees every screen.
    public let shifts: [ScreenShift]
}

/// Finds boxed-in screens and the moves the offer proposes: every
/// screen ends with a free bottom corner and every touching pair
/// still touching; the pick takes the fewest changed crossings
/// over the whole arrangement, then moves no main screen, then
/// the smallest total distance. Pure geometry over the stash's
/// own corner scoring.
public enum ScreenShiftPlan {
    /// The arrangement's offer; nil when no screen is boxed in.
    public static func offer(_ screens: [ArrangedScreen]) -> ScreenOffer? {
        let boxed = boxedIn(screens)
        guard !boxed.isEmpty else { return nil }
        return ScreenOffer(
            boxed: boxed,
            shifts: bestPlan(for: screens) ?? []
        )
    }

    public static func boxedIn(
        _ screens: [ArrangedScreen]
    ) -> [BoxedInScreen] {
        screens.compactMap { verdict(for: $0, in: screens) }
    }

    static func verdict(
        for screen: ArrangedScreen,
        in screens: [ArrangedScreen]
    ) -> BoxedInScreen? {
        guard
            let left = coverer(of: screen, at: .bottomLeft, in: screens),
            let right = coverer(
                of: screen,
                at: .bottomRight,
                in: screens
            )
        else { return nil }
        let others = screens.filter { $0.id != screen.id }.map(\.visible)
        let picked = TilingEngine.optimalHideCorner(
            for: screen.visible,
            among: others
        )
        return BoxedInScreen(
            screen: screen.id,
            landsOn: picked == .bottomLeft ? left : right,
            cause: left == right
                ? .belowBoth(left)
                : .corners(left: left, right: right)
        )
    }

    /// The screen a park at `corner` covers most; nil for a free
    /// corner.
    static func coverer(
        of screen: ArrangedScreen,
        at corner: TilingEngine.HideCorner,
        in screens: [ArrangedScreen]
    ) -> String? {
        // As `optimalHideCorner` does, a screen overlapping this
        // one is itself or its mirror, never a neighbour.
        let others = screens.filter {
            $0.id != screen.id
                && $0.visible.intersection(screen.visible).isEmpty
        }
        let scored = others.map {
            (
                $0.id,
                TilingEngine.parkOverlap(
                    of: screen.visible,
                    at: corner,
                    on: [$0.visible]
                )
            )
        }
        guard let best = scored.max(by: { $0.1 < $1.1 }), best.1 > 0
        else { return nil }
        return best.0
    }

    /// Whether a park at either bottom corner covers nothing.
    static func hasFreeCorner(
        _ screen: ArrangedScreen,
        in screens: [ArrangedScreen]
    ) -> Bool {
        coverer(of: screen, at: .bottomLeft, in: screens) == nil
            || coverer(of: screen, at: .bottomRight, in: screens) == nil
    }

    /// Whether two screens share a stretch of edge the pointer
    /// can cross; a corner-to-corner meeting is no crossing.
    static func touches(_ a: CGRect, _ b: CGRect) -> Bool {
        let sideBySide =
            (abs(a.maxX - b.minX) <= 1 || abs(b.maxX - a.minX) <= 1)
            && min(a.maxY, b.maxY) - max(a.minY, b.minY) > 0
        let stacked =
            (abs(a.maxY - b.minY) <= 1 || abs(b.maxY - a.minY) <= 1)
            && min(a.maxX, b.maxX) - max(a.minX, b.minX) > 0
        return sideBySide || stacked
    }
}
