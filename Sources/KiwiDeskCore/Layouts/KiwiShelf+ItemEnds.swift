import CoreGraphics

/// The extra along-axis padding an item's two ends owe their
/// rounded corners (#1763), in pt; zero at an end drawn square.
public struct ItemEnds: Equatable, Sendable {
    public var leading: CGFloat
    public var trailing: CGFloat

    public init(leading: CGFloat, trailing: CGFloat) {
        self.leading = leading
        self.trailing = trailing
    }

    public static let zero = ItemEnds(leading: 0, trailing: 0)

    public var total: CGFloat { leading + trailing }
}

extension KiwiShelf {
    /// How far along the axis from a rounded end a content square
    /// `crossOffset` in from the item's long edges must start for
    /// its corners to sit on the corner's arc (#1763):
    /// r − √(r² − (r − y)²), 0 once y ≥ r. The one copy of that
    /// formula; each item type hands it its own cross offset.
    public static func endClearance(
        radius: CGFloat,
        crossOffset: CGFloat
    ) -> CGFloat {
        let r = max(radius, 0)
        let y = max(crossOffset, 0)
        guard y < r else { return 0 }
        return r - (r * r - (r - y) * (r - y)).squareRoot()
    }

    /// Which ends of an item DRAW rounded (#1763): every item's
    /// both while Boxed; on a plate, the run's first item's
    /// leading end and its last's trailing one. The one predicate
    /// a bar's measuring and its layout both read.
    public func roundsItemEnds(
        first: Bool,
        last: Bool
    ) -> (leading: Bool, trailing: Bool) {
        drawsPlate ? (first, last) : (true, true)
    }

    /// `clearance` at each end `roundsItemEnds` rounds.
    public func itemEnds(
        clearance: CGFloat,
        first: Bool,
        last: Bool
    ) -> ItemEnds {
        let rounds = roundsItemEnds(first: first, last: last)
        return ItemEnds(
            leading: rounds.leading ? clearance : 0,
            trailing: rounds.trailing ? clearance : 0
        )
    }
}
