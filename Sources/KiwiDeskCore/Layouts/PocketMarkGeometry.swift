import CoreGraphics

/// The pocket mark's geometry (#2776), actor-free: the mark's share
/// of the side it stands in, and the room its lit edge and lift
/// spill past it. The shelf's placement, the risen size and the
/// view read it.
enum PocketMarkGeometry {
    /// The mark's side as a share of the side it stands in.
    static let markShare = BriefPocketPlan.markSide / BriefPocketPlan.side
    /// The lit edge's two blurs, as shares of the mark's side: a
    /// tight dark line, and a wider light halo.
    static let lineBlur: CGFloat = 0.05
    static let haloBlur: CGFloat = 0.14
    /// The hovered mark's scale.
    static let lift: CGFloat = 1.06
    /// The kiwi handle's depth at rest, the bars' handles' own
    /// (`KiwiShelf.hiddenDepth`): its 6 pt tab and 5 pt of kiwi.
    static var handleDepth: CGFloat { KiwiShelf.hiddenDepth }

    /// The mark's side in a slot `depth` deep.
    static func markSide(depth: CGFloat) -> CGFloat { depth * markShare }

    /// How far a lit, lifted mark `side` long reaches past it on
    /// each side.
    static func spill(mark side: CGFloat) -> CGFloat {
        (side * (haloBlur + (lift - 1) / 2)).rounded(.up)
    }
}
