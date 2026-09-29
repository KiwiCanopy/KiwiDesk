import AppKit

/// A Space item's rounded ends (#1763): the clearance its glyph
/// cell needs, at a rounded end (`KiwiShelf.roundsItemEnds`) where
/// icon-like glyphs sit: the leading end behind a symbol
/// identifier — a number's or a name's ink clears the curve on its
/// own — and the trailing end of an item with apps, the `+N` disc
/// counting as an icon so a strip scrolled between the two keeps
/// its length (owner, 2026-09-29).
extension SpaceBarItemView {
    /// Whether the item's trailing run holds app glyphs — the one
    /// reading the item and its measurement share.
    static func endsInIcon(appCount: Int) -> Bool { appCount > 0 }

    /// Whether the identifier draws an icon-like symbol rather than
    /// text.
    static func leadsWithIcon(_ glyph: SpaceGlyph) -> Bool {
        if case .symbol = glyph { return true }
        return false
    }

    /// The extra end padding this item's rounded ends owe.
    var ends: ItemEnds {
        Self.ends(
            look: style,
            depth: depth,
            first: isFirstInRun,
            last: isLastInRun,
            leadsWithIcon: Self.leadsWithIcon(spaceGlyph),
            endsInIcon: Self.endsInIcon(appCount: apps.count)
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
        last: Bool,
        leadsWithIcon: Bool,
        endsInIcon: Bool
    ) -> ItemEnds {
        let rounded = look.shelf.itemEnds(
            clearance: endClearance(look: look, depth: depth),
            first: first,
            last: last,
            outlined: look.activeIndicator == .outline
        )
        return ItemEnds(
            leading: leadsWithIcon ? rounded.leading : 0,
            trailing: endsInIcon ? rounded.trailing : 0
        )
    }
}
