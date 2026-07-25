import AppKit

/// Panel plumbing for the Space Bar overlay: the non-activating
/// panel, the clipping item viewport and its scroll arrows inside
/// it, per-render strip styling, and the item-view pool. The
/// App Bar's `+Panel` twin.
extension SpaceBarOverlay {
    /// `plain` and `material` draw their shared plate as its
    /// own view (`updatePlainPlate` / the glass-hosting dispatch)
    /// so it can hug the run (`background_fit`); `boxed` boxes
    /// each item. The container itself never paints.
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
        guard style.backgroundStyle == .plain, !style.glassEnabled,
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

    /// The one hosting mode for this render (#407), from the
    /// resolved style and whether the run overflows.
    func glassHosting(
        _ style: SpaceBarStyle,
        overflow: Bool
    ) -> GlassHosting {
        GlassHosting.resolve(
            available: AppBarStyle.glassAvailable,
            glassEnabled: style.glassEnabled,
            boxed: style.backgroundStyle == .boxed,
            overflow: overflow
        )
    }

    /// Teardown half of the one glass-hosting dispatch (#407, App Bar
    /// twin): run once per render, *before* the item + front passes,
    /// so the run sits in the container the target mode expects while
    /// frames are laid out. Tears down every mode except `mode`; the
    /// target is installed post-passes by `installGlassHosting`. The
    /// front segment rides `itemContainer`, so it is tinted as part of
    /// the run. The solid plain plate self-gates in `updatePlainPlate`.
    func prepareGlassHosting(
        _ mode: GlassHosting,
        panel: NSPanel,
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
        guard let content = panel.contentView else { return }
        switch mode {
        case .boxGlass:
            // Per-box glass keeps its boxes; hand the run back so the
            // boxes can reparent items out of it, unwind any
            // plain-glass run, and hide the single plate.
            restoreItemContainer(to: content, viewport: viewport)
            teardownGlassRun()
            glassPlate?.isHidden = true
            glassTint?.isHidden = true
        case .plainGlassHug, .plainGlassSpan:
            // The run + single plate are hosted post-passes by
            // `updatePlainGlass`; only the boxes must go first.
            teardownBoxGlasses()
        case .plainPlate, .none:
            // No glass: unwind boxes and run, restore the plain
            // hierarchy, and hide the glass plate.
            teardownBoxGlasses()
            restoreItemContainer(to: content, viewport: viewport)
            teardownGlassRun()
            glassPlate?.isHidden = true
            glassTint?.isHidden = true
        }
    }

    /// Install half of the one glass-hosting dispatch (#407, App Bar
    /// twin): run once per render, *after* the item + front passes,
    /// to host the target mode from the laid-out `frames`.
    func installGlassHosting(
        _ mode: GlassHosting,
        panel: NSPanel,
        frames: [CGRect],
        viewport: CGRect,
        plateFrame: CGRect,
        pinnedFront: Bool,
        style: SpaceBarStyle,
        depth: CGFloat
    ) {
        switch mode {
        case .boxGlass:
            updateBoxGlasses(
                frames: frames,
                style: style,
                depth: depth
            )
        case .plainGlassHug, .plainGlassSpan:
            updatePlainGlass(
                panel: panel,
                viewport: viewport,
                plateFrame: plateFrame,
                overflow: mode == .plainGlassSpan,
                pinnedFront: pinnedFront,
                style: style,
                depth: depth
            )
        case .plainPlate, .none:
            break
        }
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
