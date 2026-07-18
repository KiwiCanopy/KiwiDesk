import AppKit

/// Panel plumbing: the non-activating panel, the clipping
/// item viewport inside it, and per-render container styling.
extension AppBarOverlay {
    /// Flipped so the first item sits at the visual top of
    /// vertical bars.
    final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// `plain` draws all names on one shared box (the strip
    /// itself, painted in `boxColor` and rounded by the
    /// roundness); `boxed` boxes each item and keeps the strip in
    /// the (default transparent) background color.
    func styleContainer(
        _ panel: NSPanel,
        style: AppBarStyle,
        depth: CGFloat
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        let rendered = style.tabBackground.rendered
        layer.masksToBounds = true
        // `boxed` keeps square corners; `plain` and `material`
        // round the shared plate.
        layer.cornerRadius =
            rendered == .boxed
            ? 0
            : style.resolvedCornerRadius(forThickness: depth)
        // `plain` paints the strip in the box color; `material`
        // stays clear (the glass plate is the background);
        // `boxed` keeps the (default transparent) background.
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
        style: AppBarStyle,
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
            let view = AppBarItemView()
            itemViews.append(view)
            itemContainer.addSubview(view)
        }
    }

    /// Items focus their window on click; the shared panel
    /// shell comes from `BarPanel` (#293).
    func makePanel() -> NSPanel {
        let panel = BarPanel.makeNonActivating()
        let view = FlippedView()
        view.wantsLayer = true
        panel.contentView = view
        // Items render inside a clipping viewport so that,
        // while scrolled, the cut-off item ends a gap short
        // of the arrows instead of sliding under them.
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = true
        view.addSubview(itemContainer)
        view.addSubview(backArrow)
        view.addSubview(forwardArrow)
        return panel
    }
}
