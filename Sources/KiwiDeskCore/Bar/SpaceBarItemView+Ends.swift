import AppKit

/// A Space item's rounded ends (#1763): the clearance its glyph
/// cell needs, at a rounded end (`KiwiShelf.roundsItemEnds`) where
/// an icon-like glyph sits — a symbol identifier, app glyphs or a
/// `+N` disc, a corner badge on the identifier — never a text
/// identifier alone (owner, 2026-09-29).
extension SpaceBarItemView {
    /// Whether the identifier cell carries a corner badge — a
    /// collapse's count or the held mark, at its trailing top.
    static func badgesIdentifier(collapsed: Bool, held: Bool) -> Bool {
        collapsed || held
    }

    /// Whether the trailing end holds an icon-like glyph: app
    /// glyphs, or the identifier's corner badge on a horizontal
    /// bar — the one reading the item and its measurement share.
    static func endsInIcon(
        appCount: Int,
        badged: Bool,
        horizontal: Bool
    ) -> Bool {
        appCount > 0 || (badged && horizontal)
    }

    /// Whether the leading end holds an icon-like glyph: a symbol
    /// identifier, or its corner badge at the top of a vertical bar.
    static func leadsWithIcon(
        _ glyph: SpaceGlyph,
        badged: Bool,
        horizontal: Bool
    ) -> Bool {
        if case .symbol = glyph { return true }
        return badged && !horizontal
    }

    private var badged: Bool {
        Self.badgesIdentifier(collapsed: collapse != nil, held: held != nil)
    }

    /// The extra end padding this item's rounded ends owe.
    var ends: ItemEnds {
        Self.ends(
            look: style,
            depth: depth,
            first: isFirstInRun,
            last: isLastInRun,
            leadsWithIcon: Self.leadsWithIcon(
                spaceGlyph,
                badged: badged,
                horizontal: style.edge.isHorizontal
            ),
            endsInIcon: Self.endsInIcon(
                appCount: apps.count,
                badged: badged,
                horizontal: style.edge.isHorizontal
            )
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
