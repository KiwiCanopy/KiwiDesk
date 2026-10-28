import AppKit

/// The Space Bar's corner state badges (#414, #429), split from
/// `SpaceBarItemView+Style` at the §2.1 ceiling.
extension SpaceBarItemView {
    /// Styles the sticky, floating and pocket badges; a badge
    /// exists only where `syncStateBadges` decided it is drawn
    /// (#1942), so styling never re-decides whether it shows.
    func styleStateBadges() {
        for (index, app) in apps.enumerated() {
            if index < stickyBadgeViews.count,
                let badge = stickyBadgeViews[index]
            {
                applyStateBadge(
                    badge,
                    markHex: stateMarkColors.sticky,
                    appFocused: app.focused
                )
            }
            if index < floatingBadgeViews.count,
                let badge = floatingBadgeViews[index]
            {
                // The pocket badge takes the float badge's slot and
                // its own colour (#2446, #2671).
                applyStateBadge(
                    badge,
                    markHex: stateMarkColors.floating,
                    pocketHex: app.pocket ? stateMarkColors.pocket : nil,
                    appFocused: app.focused
                )
            }
        }
    }

    /// State badge fill and contrast glyph (#429), its symbol on
    /// the dim ladder (`BarBadgeFace`). A pocket badge
    /// keeps the count badge's own disc and fills its pocket in
    /// `pocketHex`, the window mark's split (#2671); empty takes
    /// the disc's contrasting ink.
    private func applyStateBadge(
        _ badge: StateBadgeView,
        markHex: String,
        pocketHex: String? = nil,
        appFocused: Bool
    ) {
        let fill = NSColor.mark(
            hex: pocketHex == nil ? markHex : "",
            fallback: NSColor(kiwiHex: style.groupBadgeColor)
        )
        BarBadgeFace.disc(
            badge,
            fill: fill,
            shelfFill: style.shelf.fillColor
        )
        badge.symbol.contentTintColor = fill.contrastingGlyph
        badge.ink = NSColor.mark(
            hex: pocketHex ?? "",
            fallback: fill.contrastingGlyph
        )
        badge.symbol.alphaValue = untintedAppAlpha(focused: appFocused)
    }
}
