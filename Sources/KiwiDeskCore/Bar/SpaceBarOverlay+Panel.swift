import AppKit

/// Panel plumbing for the Space Bar overlay: the non-activating
/// panel, the clipping item viewport and its scroll arrows inside
/// it, per-render strip styling, and the item-view pool. The
/// App Bar's `+Panel` twin.
extension SpaceBarOverlay {
    /// `plain` paints the whole strip in `boxColor` and rounds it;
    /// `boxed` boxes each item and keeps the strip in the (default
    /// transparent) background color.
    func styleContainer(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        let depth =
            style.edge.isHorizontal
            ? strip.height : strip.width
        layer.masksToBounds = true
        layer.cornerRadius =
            style.tabBackground == .plain
            ? style.resolvedCornerRadius(forThickness: depth)
            : 0
        let background =
            style.tabBackground == .plain
            ? style.boxColor
            : style.backgroundColor
        layer.backgroundColor =
            NSColor(kiwiHex: background).cgColor
    }

    func syncItemViewCount(_ count: Int) {
        while itemViews.count > count {
            itemViews.removeLast().removeFromSuperview()
        }
        while itemViews.count < count {
            let view = SpaceBarItemView()
            itemViews.append(view)
            itemContainer.addSubview(view)
        }
    }

    func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        let view = AppBarOverlay.FlippedView()
        view.wantsLayer = true
        panel.contentView = view
        // Items and the front segment render inside a clipping
        // viewport so a scrolled item ends a gap short of the
        // arrows instead of sliding under them (#385); the arrows
        // sit above it at the strip's ends.
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = true
        view.addSubview(itemContainer)
        view.addSubview(backArrow)
        view.addSubview(forwardArrow)
        return panel
    }
}
