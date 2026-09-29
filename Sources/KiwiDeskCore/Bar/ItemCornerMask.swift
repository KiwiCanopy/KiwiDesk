import QuartzCore

/// The corners an item's layers round: exactly the ends
/// `KiwiShelf.roundsItemEnds` rounds, so the paint and the end
/// clearance read one answer and a square end is never painted
/// round, hover included (#1763).
enum ItemCornerMask {
    static func mask(
        shelf: KiwiShelf,
        first: Bool,
        last: Bool,
        outlined: Bool,
        horizontal: Bool
    ) -> CACornerMask {
        let rounds = shelf.roundsItemEnds(
            first: first,
            last: last,
            outlined: outlined
        )
        let leading: CACornerMask =
            horizontal
            ? [.layerMinXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner]
        let trailing: CACornerMask =
            horizontal
            ? [.layerMaxXMinYCorner, .layerMaxXMaxYCorner]
            : [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        var corners: CACornerMask = []
        if rounds.leading { corners.formUnion(leading) }
        if rounds.trailing { corners.formUnion(trailing) }
        return corners
    }
}
