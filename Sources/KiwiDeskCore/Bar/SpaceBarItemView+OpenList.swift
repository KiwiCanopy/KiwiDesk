import AppKit

/// A Space item whose list a click holds open (#2571 ▸ Ruling): the
/// glyph or `+n` stays lit until its list closes; a badge keeps its
/// number.
extension SpaceBarItemView {
    /// The target whose list is open, if one of this item's is.
    var openListTarget: SpaceBarGlyphTarget? {
        targetsForHover.first { $0.actions?.peek?.holdsOpen($0) == true }
    }
}

/// A glyph or `+n`: its release decides every left press — a list's
/// click opens or closes it, a one-window glyph's picks — and its
/// list opening or closing re-reads its item's lit state (#2571).
extension SpaceBarGlyphTarget: BarPeekListAnchor {
    var sparesLeftPress: Bool { true }

    func listOpenChanged() {
        (superview as? SpaceBarItemView)?.syncHoverToPointer()
    }
}
