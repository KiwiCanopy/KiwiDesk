import AppKit

/// A bar item's list grown out of the item (#2571 ▸ Ruling): it
/// rests where the hover peek rests, a gap off the bar, and grows
/// there from a seed the item's size at its near edge, on the
/// overflow mark's spring. The item stays drawn and clickable, so
/// nothing hides and no header is drawn.
extension BarPeekPanel {
    /// What a bar item's list is shown from, all on screen.
    struct GrowRequest {
        let item: NSView
        /// The item's frame.
        let frame: CGRect
        let edge: AppBarEdge
        /// The frame of the bar's panel.
        let strip: CGRect
    }

    /// Shows `content` grown out of `request`'s item inside the
    /// usable area `visible`; a list already shown for the same item
    /// is redrawn in place.
    func showGrown(
        _ content: BarPeekContent,
        shelf stored: KiwiShelf,
        request: GrowRequest,
        visible: CGRect
    ) {
        let shelf = LiquidGlassGate.rendered(stored)
        // An overflow mark's list in its place ends at once.
        if morph?.growth == .fromPill { dropMorph() }
        body.reserve = .none
        header.isHidden = true
        let size = Self.fittedSize(
            of: body,
            content,
            shelf: shelf,
            edge: request.edge,
            strip: request.strip,
            visible: visible
        )
        let list = CGRect(
            origin: Self.origin(
                size: size,
                edge: request.edge,
                anchor: request.frame,
                strip: request.strip,
                visible: visible
            ),
            size: size
        )
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.takesKey = true
        panel.setFrame(list, display: false)
        paint(shelf, edge: request.edge, size: size)
        let opens = adopt(
            content,
            Morph(growth: .outOfItem, item: request.item, edge: request.edge),
            panel: panel,
            redraws: morph?.item === request.item
        )
        guard opens else { return }
        playOpen(
            panel,
            from: BarPeekMorph.seed(
                item: request.frame,
                list: list,
                edge: request.edge
            ),
            in: list,
            anchor: nil
        )
    }
}
