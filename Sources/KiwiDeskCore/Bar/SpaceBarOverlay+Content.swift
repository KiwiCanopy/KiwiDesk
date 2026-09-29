import CoreGraphics

/// Where the Space run's drawn content sits inside its run — what
/// the shelf's section divider centres against (#1779).
extension SpaceBarOverlay {
    /// How far in from the run's two ends its drawn content starts
    /// (#1779): each end item's `pad` and rounded-end clearance,
    /// none on a boxed shelf, and none at an end the front-app
    /// segment or a lone layer item's rule closes.
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
        let closedByRule =
            frontFollows || (last == 0 && leadsWithLayer(items))
        let trail = itemEnds(
            items,
            index: last,
            depth: depth,
            look: look,
            frontFollows: frontFollows
        )
        return ItemEnds(
            leading: SpaceBarItemView.contentInset(ends: lead).leading,
            trailing: closedByRule
                ? 0 : SpaceBarItemView.contentInset(ends: trail).trailing
        )
    }
}
