import AppKit

/// Fades a shelf section's content on each side that hides
/// entries (#1517): a gradient MASK on the item container — never
/// a gradient laid over it, which would paint a colour on the
/// plate that glass does not have. A side with nothing hidden
/// keeps its full ink.
@MainActor
enum ShelfFadeMask {
    /// Masks `view` with fades `leading` and `trailing` points
    /// long along the shelf's axis; removes the mask when both
    /// are zero.
    static func apply(
        to view: NSView,
        leading: CGFloat,
        trailing: CGFloat,
        horizontal: Bool
    ) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        let length = horizontal ? view.bounds.width : view.bounds.height
        guard leading > 0 || trailing > 0, length > 0 else {
            layer.mask = nil
            return
        }
        let mask = (layer.mask as? CAGradientLayer) ?? makeMask()
        mask.frame = view.bounds
        mask.startPoint =
            horizontal ? CGPoint(x: 0, y: 0.5) : CGPoint(x: 0.5, y: 1)
        mask.endPoint =
            horizontal ? CGPoint(x: 1, y: 0.5) : CGPoint(x: 0.5, y: 0)
        mask.locations = stops(
            leading: leading,
            trailing: trailing,
            length: length
        ).map { NSNumber(value: Double($0)) }
        layer.mask = mask
    }

    /// The gradient's four stops along the axis: clear at each
    /// hidden end, opaque from one fade's length in.
    nonisolated static func stops(
        leading: CGFloat,
        trailing: CGFloat,
        length: CGFloat
    ) -> [CGFloat] {
        let lead = min(max(leading / length, 0), 0.5)
        let trail = min(max(trailing / length, 0), 0.5)
        return [0, lead, 1 - trail, 1]
    }

    /// Clear at the ends and opaque between; a hidden side starts
    /// clear, a side at its end starts opaque (its stop at 0).
    private static func makeMask() -> CAGradientLayer {
        let mask = CAGradientLayer()
        mask.colors = [
            NSColor.clear.cgColor, NSColor.black.cgColor,
            NSColor.black.cgColor, NSColor.clear.cgColor,
        ]
        // A mask re-laid every render must land, not travel: the
        // bars start motion in BarMotion alone.
        mask.actions = [
            "bounds": NSNull(), "position": NSNull(),
            "frame": NSNull(), "locations": NSNull(),
            "startPoint": NSNull(), "endPoint": NSNull(),
        ]
        return mask
    }
}
