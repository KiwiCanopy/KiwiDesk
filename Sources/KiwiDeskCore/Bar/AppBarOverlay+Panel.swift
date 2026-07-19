import AppKit

/// Panel plumbing: the non-activating panel, the clipping
/// item viewport inside it, and per-render container styling.
extension AppBarOverlay {
    /// Flipped so the first item sits at the visual top of
    /// vertical bars.
    final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// `plain` and `material` draw their shared plate as its
    /// own view (`updatePlainPlate` / `updateGlassPlate`) so it
    /// can hug the run (`tab_background_fit`); the container
    /// itself only ever paints `boxed`'s (default transparent)
    /// background.
    func styleContainer(
        _ panel: NSPanel,
        style: AppBarStyle,
        depth: CGFloat
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        layer.masksToBounds = true
        layer.cornerRadius = 0
        let background =
            style.tabBackground.rendered == .boxed
            ? style.backgroundColor : "#00000000"
        layer.backgroundColor =
            NSColor(kiwiHex: background).cgColor
    }

    /// Shows / sizes `plain`'s shared fill plate at
    /// `plateFrame`, else hides it. Rounds against the real
    /// (clamped) cross depth, like the glass plate.
    func updatePlainPlate(
        _ panel: NSPanel,
        style: AppBarStyle,
        strip: CGRect,
        plateFrame: CGRect
    ) {
        guard style.tabBackground.rendered == .plain,
            let content = panel.contentView
        else {
            plainPlate?.isHidden = true
            return
        }
        let plate = plainPlate ?? NSView()
        plainPlate = plate
        plate.wantsLayer = true
        if plate.superview !== content {
            content.addSubview(
                plate,
                positioned: .below,
                relativeTo: nil
            )
        }
        plate.isHidden = false
        plate.frame = plateFrame
        let depth =
            style.edge.isHorizontal ? strip.height : strip.width
        plate.layer?.cornerRadius =
            style.resolvedCornerRadius(forThickness: depth)
        plate.layer?.backgroundColor =
            NSColor(kiwiHex: style.boxColor).cgColor
    }

    /// Shows / sizes the Liquid Glass plate under the items when
    /// the background resolves to `material`, else hides it (#390).
    func updateGlassPlate(
        _ panel: NSPanel,
        style: AppBarStyle,
        strip: CGRect,
        plateFrame: CGRect
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
            frame: plateFrame,
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
