import AppKit

/// A bar item's hover fill on glass (#2645): the hover fades with
/// the shelf's Fill, through `GlassTint.applyHover`, on a backdrop
/// at the bottom of the item. A solid shelf keeps the flat hover
/// on the item's own layer, its Fill not fading.
@MainActor
enum BarHoverFill {
    /// Paints `backdrop` for a `hovered` item and says whether it
    /// shows; where it does not, the caller paints its flat colour.
    static func paint(
        _ backdrop: GlassBackdrop,
        hovered: Bool,
        hex: String,
        shelf: KiwiShelf,
        edge: AppBarEdge,
        cornerRadius: CGFloat,
        corners: CACornerMask
    ) -> Bool {
        let shown =
            hovered && shelf.glassEnabled
            && GlassTint.applyHover(
                backdrop,
                cornerRadius: cornerRadius,
                fill: shelf.glassFill(hover: hex),
                edge: edge
            )
        backdrop.isHidden = !shown
        backdrop.gradient?.maskedCorners = corners
        return shown
    }
}
