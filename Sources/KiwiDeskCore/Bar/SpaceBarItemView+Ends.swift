import AppKit

/// A Space item's rounded ends (#1763): the clearance its glyph
/// cell needs, at the ends `KiwiShelf.roundsItemEnds` rounds.
extension SpaceBarItemView {
    /// The extra end padding this item's rounded ends owe.
    var ends: ItemEnds {
        Self.ends(
            look: style,
            depth: depth,
            first: isFirstInRun,
            last: isLastInRun
        )
    }

    /// A rounded end's clearance for a Space Bar glyph cell, which
    /// the items and the front-app chip share.
    static func endClearance(look: SpaceBarLook, depth: CGFloat) -> CGFloat {
        let cell = cell(contentDepth: look.contentDepth(forDepth: depth))
        return KiwiShelf.endClearance(
            radius: look.resolvedCornerRadius(forThickness: depth),
            crossOffset: (depth - cell) / 2
        )
    }

    /// The end insets of an item at its place in the run — the one
    /// reading `autoLength`'s callers and `layout()` share.
    static func ends(
        look: SpaceBarLook,
        depth: CGFloat,
        first: Bool,
        last: Bool
    ) -> ItemEnds {
        look.shelf.itemEnds(
            clearance: endClearance(look: look, depth: depth),
            first: first,
            last: last,
            outlined: look.activeIndicator == .outline
        )
    }
}
