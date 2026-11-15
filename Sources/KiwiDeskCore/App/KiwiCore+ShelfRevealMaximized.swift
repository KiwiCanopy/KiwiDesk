import AppKit

/// The bands a maximized window's bars come in through (#3346): no
/// handle at rest, the band along the whole edge, and nothing of it
/// over the window, so its tab bar and toolbar stay clear.
extension KiwiCore.HidingShelves {
    /// The band of each of `bars` on `plan`'s edge, Cocoa: along
    /// `ShelfMarkPlacement.maximizedBands`, reaching only outward
    /// past the shelf's screen side — into a menu bar or a Dock,
    /// where resting brings the bar in — so at a bare screen edge
    /// only a push opens it.
    @MainActor static func maximizedBands(
        _ bars: Set<ShelfBar>,
        of plan: KiwiCore.ShelfPlan,
        shelf: KiwiShelf
    ) -> [ShelfBar: CGRect] {
        guard !bars.isEmpty else { return [:] }
        let primary = GeometryUtils.primaryHeight
        let flip = { GeometryUtils.flip($0, primaryHeight: primary) }
        let spans = ShelfMarkPlacement.maximizedBands(
            for: bars,
            length: plan.length,
            shelf: shelf
        )
        return spans.mapValues { range in
            ShelfReveal.band(
                of: flip(plan.strip),
                edge: plan.edge,
                along: flip(Self.span(range, of: plan)),
                outward: shelf.outerMargin + ShelfReveal.overshoot,
                inward: 0
            )
        }
    }
}
