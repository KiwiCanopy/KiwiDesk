import AppKit

/// Panel plumbing for the Space Bar overlay: the non-activating
/// panel, the clipping item viewport and its scroll arrows inside
/// it, per-render strip styling, and the item-view pool. The
/// App Bar's `+Panel` twin.
extension SpaceBarOverlay {
    /// `plain` and `material` draw their shared plate as its
    /// own view (`updatePlainPlate` / `updateGlassPlate`) so it
    /// can hug the run (`tab_background_fit`); `boxed` boxes each
    /// item. The container itself never paints.
    func styleContainer(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect
    ) {
        guard let layer = panel.contentView?.layer else {
            return
        }
        layer.masksToBounds = true
        layer.cornerRadius = 0
        // The container never paints: the fill is drawn per item
        // (Boxed) or as a shared plate (Plain / Material glass).
        layer.backgroundColor = NSColor.clear.cgColor
    }

    /// Shows / sizes `plain`'s shared fill plate at
    /// `plateFrame`, else hides it.
    func updatePlainPlate(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect,
        plateFrame: CGRect
    ) {
        // Solid Plain plate: Plain shape without the glass finish.
        guard style.tabBackground == .plain, !style.glassEnabled,
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
            NSColor(kiwiHex: style.fillColor).cgColor
    }

    /// Liquid Glass path (#390): embeds the item run as the glass
    /// `contentView` — the supported usage that actually renders
    /// the tint (a bare backdrop plate renders degraded). The
    /// glass takes the `viewport` frame, so in Phase 1 material's
    /// `hug` (`tab_background_fit`) is inert; a run wrapper will
    /// restore it later. Leaving material hands the viewport back
    /// below the arrows and hides the glass. The front segment
    /// rides `itemContainer`, so it is tinted as part of the run.
    func updateGlassPlate(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect,
        viewport: CGRect
    ) {
        let depth =
            style.edge.isHorizontal ? strip.height : strip.width
        guard let content = panel.contentView else { return }
        // Glass fires on the finish, over either shape.
        guard style.glassEnabled else {
            restoreItemContainer(to: content, viewport: viewport)
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
                relativeTo: backArrow
            )
        }
        plate.isHidden = false
        GlassPlate.setContent(plate, itemContainer)
        GlassPlate.update(
            plate,
            frame: viewport,
            cornerRadius: style.resolvedCornerRadius(
                forThickness: depth
            ),
            tintHex: style.fillColor
        )
    }

    /// Reparents the item viewport out of a glass plate back to
    /// the panel content, below the arrows, at its viewport frame.
    /// No-op unless it currently rides the glass.
    private func restoreItemContainer(
        to content: NSView,
        viewport: CGRect
    ) {
        guard let plate = glassPlate,
            GlassPlate.holds(plate, itemContainer)
        else { return }
        GlassPlate.detach(plate)
        content.addSubview(
            itemContainer,
            positioned: .below,
            relativeTo: backArrow
        )
        itemContainer.frame = viewport
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

extension SpaceBarOverlay {
    /// Both shared plates (plain fill, Liquid Glass) in one
    /// call — exactly one is visible per mode, and both take
    /// the same `BarPlate` frame authority.
    func updatePlates(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect,
        plateFrame: CGRect,
        viewport: CGRect
    ) {
        updatePlainPlate(
            panel,
            style: style,
            strip: strip,
            plateFrame: plateFrame
        )
        updateGlassPlate(
            panel,
            style: style,
            strip: strip,
            viewport: viewport
        )
    }
}
