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
                    hex: stateMarkColors.sticky,
                    appFocused: app.focused
                )
            }
            if index < floatingBadgeViews.count,
                let badge = floatingBadgeViews[index]
            {
                applyStateBadge(
                    badge,
                    hex: stateMarkColors.floating,
                    appFocused: app.focused
                )
            }
            if index < pocketBadgeViews.count,
                let badge = pocketBadgeViews[index]
            {
                applyStateBadge(
                    badge,
                    hex: stateMarkColors.pocket,
                    appFocused: app.focused
                )
            }
        }
    }

    /// A state badge: the count badge's own disc for every state,
    /// the state's colour on its symbol, its contrasting ink on
    /// Automatic (#2831), the symbol on the dim ladder
    /// (`BarBadgeFace`).
    private func applyStateBadge(
        _ badge: StateBadgeView,
        hex: String,
        appFocused: Bool
    ) {
        let fill = NSColor(kiwiHex: style.groupBadgeColor)
        let tier = untintedAppAlpha(focused: appFocused)
        BarBadgeFace.disc(
            badge,
            fill: fill,
            shelf: style.shelf,
            tier: tier
        )
        let ink = NSColor.mark(hex: hex, fallback: fill.contrastingGlyph)
        badge.symbol.contentTintColor = ink
        badge.ink = ink
        badge.symbol.alphaValue = tier
    }
}
