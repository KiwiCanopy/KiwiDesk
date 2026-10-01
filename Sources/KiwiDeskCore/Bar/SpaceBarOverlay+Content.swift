import CoreGraphics

/// Where the Space run's drawn content sits inside its run — what
/// the shelf's section divider centres against (#1779).
extension SpaceBarOverlay {
    /// How far in from the run's two ends its drawn content starts
    /// (#1779): each end item's `pad` and rounded-end clearance,
    /// none on a boxed shelf, the front-app chip's own end pad
    /// where it closes the run (#1856), and none at an end a lone
    /// layer item's rule closes.
    static func contentInsets(
        items: [Item],
        depth: CGFloat,
        look: SpaceBarLook,
        frontFollows: Bool
    ) -> ItemEnds {
        guard look.shelf.drawsPlate, !items.isEmpty else { return .zero }
        let last = items.count - 1
        let lead = itemEnds(
            items,
            index: 0,
            depth: depth,
            look: look,
            frontFollows: frontFollows
        )
        let closedByRule = last == 0 && leadsWithLayer(items)
        let trail = itemEnds(
            items,
            index: last,
            depth: depth,
            look: look,
            frontFollows: frontFollows
        )
        let trailing =
            frontFollows
            ? chipEndPad(look, depth: depth).trailing
            : closedByRule
                ? 0 : SpaceBarItemView.contentInset(ends: trail).trailing
        return ItemEnds(
            leading: SpaceBarItemView.contentInset(ends: lead).leading,
            trailing: trailing
        )
    }
}
