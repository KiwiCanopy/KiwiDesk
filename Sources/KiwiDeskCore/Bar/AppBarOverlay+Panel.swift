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
        plateFrame: CGRect,
        animated: Bool = false
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
        // Ease alongside the tabs (same animation group): a
        // snapping hug plate pops while the tabs it wraps are
        // still sliding. Fresh plates take their frame direct.
        if animated, plate.frame != .zero,
            plate.frame != plateFrame
        {
            plate.animator().frame = plateFrame
        } else {
            plate.frame = plateFrame
        }
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
        plateFrame: CGRect,
        animated: Bool = false
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
            tintHex: style.backgroundColor,
            animated: animated
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

extension AppBarOverlay {
    /// Both shared plates (plain fill, Liquid Glass) in one
    /// call — exactly one is visible per mode, and both take
    /// the same `BarPlate` frame authority.
    func updatePlates(
        _ panel: NSPanel,
        style: AppBarStyle,
        strip: CGRect,
        plateFrame: CGRect,
        animated: Bool = false
    ) {
        updatePlainPlate(
            panel,
            style: style,
            strip: strip,
            plateFrame: plateFrame,
            animated: animated
        )
        updateGlassPlate(
            panel,
            style: style,
            strip: strip,
            plateFrame: plateFrame,
            animated: animated
        )
    }
}
