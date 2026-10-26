import AppKit

/// A bar item's hover fill on glass (#2645): the hover fades with
/// the shelf's Fill, through `GlassTint.applyHover`, on a backdrop
/// the item places beneath its content and its box border. A solid
/// shelf keeps the flat hover on the item's own layer, its Fill not
/// fading.
@MainActor
enum BarHoverFill {
    /// Paints `backdrop` for an item that `showsHover` and says
    /// whether it shows; where it does not, the caller paints its
    /// flat colour.
    static func paint(
        _ backdrop: GlassBackdrop,
        showsHover: Bool,
        hex: String,
        shelf: KiwiShelf,
        edge: AppBarEdge,
        cornerRadius: CGFloat,
        corners: CACornerMask
    ) -> Bool {
        let shown =
            showsHover && shelf.glassEnabled
            && GlassTint.applyHover(
                backdrop,
                cornerRadius: cornerRadius,
                corners: corners,
                fill: shelf.glassFill(hover: hex),
                edge: edge
            )
        backdrop.isHidden = !shown
        return shown
    }

    /// Seats `backdrop` at the bottom of `item`, below its box
    /// `border` while the item holds it, so the rim draws over the
    /// hover hosted or not (#2595). Moves nothing already seated.
    static func seat(
        _ backdrop: GlassBackdrop,
        below border: NSView,
        in item: NSView
    ) {
        let floor = border.superview === item ? border : nil
        let order = item.subviews
        if let floor,
            let own = order.firstIndex(of: backdrop),
            let rim = order.firstIndex(of: floor),
            own + 1 == rim
        {
            return
        }
        if floor == nil, order.first === backdrop { return }
        item.addSubview(backdrop, positioned: .below, relativeTo: floor)
    }
}
