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
        let rendered = style.tabBackground.rendered
        layer.masksToBounds = true
        // `boxed` keeps square corners; `plain` and `material`
        // round the shared plate.
        layer.cornerRadius =
            rendered == .boxed
            ? 0
            : style.resolvedCornerRadius(forThickness: depth)
        // `material` stays clear — the glass plate is the
        // background; `plain` paints the box color; `boxed` keeps
        // the (default transparent) background.
        let background: String
        switch rendered {
        case .plain: background = style.boxColor
        case .material: background = "#00000000"
        case .boxed: background = style.backgroundColor
        }
        layer.backgroundColor =
            NSColor(kiwiHex: background).cgColor
    }

    /// Shows / sizes the Liquid Glass plate under the items when
    /// the background resolves to `material`, else hides it (#390).
    func updateGlassPlate(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect
    ) {
        let depth =
            style.edge.isHorizontal ? strip.height : strip.width
        guard style.tabBackground.rendered == .material,
            let content = panel.contentView
        else {
            glassPlate?.isHidden = true
            return
        }
        guard let plate = glassPlate ?? GlassPlate.make() else {
            return
        }
        glassPlate = plate
        if plate.superview !== content {
            content.addSubview(
                plate,
                positioned: .below,
                relativeTo: nil
            )
        }
        plate.isHidden = false
        GlassPlate.update(
            plate,
            frame: CGRect(
                x: 0,
                y: 0,
                width: strip.width,
                height: strip.height
            ),
            cornerRadius: style.resolvedCornerRadius(
                forThickness: depth
            ),
            tintHex: style.backgroundColor
        )
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
