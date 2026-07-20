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
    /// can hug the run (`tab_background_fit`); `boxed` boxes each
    /// tab. The container itself never paints.
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
        // The container never paints: the fill is drawn per item
        // (Boxed) or as a shared plate (Plain / Material glass).
        layer.backgroundColor = NSColor.clear.cgColor
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
        // Solid Plain plate: the Plain shape without the glass
        // finish (Plain + glass draws the glass plate instead).
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
            NSColor(kiwiHex: style.fillColor).cgColor
    }

    /// Liquid Glass path (#390): embeds the item run as the glass
    /// `contentView` — the supported usage that actually renders
    /// the tint (a bare backdrop plate renders degraded). The
    /// glass takes the `viewport` frame, so in Phase 1 material's
    /// `hug` (`tab_background_fit`) is inert; a run wrapper will
    /// restore it later. Leaving material hands the viewport back
    /// below the arrows and hides the glass.
    func updateGlassPlate(
        _ panel: NSPanel,
        style: AppBarStyle,
        strip: CGRect,
        viewport: CGRect,
        animated: Bool = false
    ) {
        let depth =
            style.edge.isHorizontal ? strip.height : strip.width
        guard let content = panel.contentView else { return }
        // Boxed + glass hosts each item in its own glass box
        // (per-box, driven at the end of `render`); leave the single
        // plate hidden and hand the item run back so the boxes can
        // reparent the items out of it.
        if wantsBoxGlass(style) {
            restoreItemContainer(to: content, viewport: viewport)
            glassPlate?.isHidden = true
            return
        }
        // Any other mode: no per-box glass — return items to the
        // container before the plain/single-plate hierarchy resolves.
        teardownBoxGlasses()
        // Glass fires on the finish, over the plain shape (one shared
        // plate). Leaving glass restores the plain hierarchy.
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
            tintHex: style.fillColor,
            animated: animated
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
        viewport: CGRect,
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
            viewport: viewport,
            animated: animated
        )
    }
}
