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
    /// own view (`updatePlainPlate` / the glass-hosting dispatch)
    /// so it can hug the run (`background_fit`); `boxed` boxes
    /// each tab. The container itself never paints.
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

    /// The one hosting mode for this render (#407), from the
    /// resolved style and whether the run overflows.
    func glassHosting(
        _ style: AppBarStyle,
        overflow: Bool
    ) -> GlassHosting {
        GlassHosting.resolve(
            available: AppBarStyle.glassAvailable,
            glassEnabled: style.glassEnabled,
            boxed: style.backgroundStyle == .boxed,
            overflow: overflow
        )
    }

    /// Teardown half of the one glass-hosting dispatch (#407): run
    /// once per render, *before* the item loop, so the items sit in
    /// the container the target mode expects while their frames are
    /// laid out. It tears down every mode except `mode`; the target
    /// itself is installed post-loop by `installGlassHosting`, which
    /// needs those frames (per-box and plain-glass both place items
    /// from them). The solid plain plate self-gates in
    /// `updatePlainPlate`. Keeps the `GlassPlate.holds` idempotency:
    /// the target's parenting is left in place across renders.
    func prepareGlassHosting(
        _ mode: GlassHosting,
        panel: NSPanel,
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
        guard let content = panel.contentView else { return }
        switch mode {
        case .boxGlass:
            // Per-box glass keeps its boxes; hand the item run back
            // so the boxes can reparent items out of it, unwind any
            // plain-glass run, and hide the single plate.
            restoreItemContainer(to: content, viewport: viewport)
            teardownGlassRun()
            glassPlate?.isHidden = true
            glassTint?.isHidden = true
        case .plainGlassHug, .plainGlassSpan:
            // The run + single plate are hosted post-loop by
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

    /// Install half of the one glass-hosting dispatch (#407): run
    /// once per render, *after* the item loop, to host the target
    /// mode from the laid-out `frames`. The teardown of the other
    /// modes already happened in `prepareGlassHosting`.
    func installGlassHosting(
        _ mode: GlassHosting,
        panel: NSPanel,
        frames: [CGRect],
        viewport: CGRect,
        plateFrame: CGRect,
        style: AppBarStyle,
        depth: CGFloat,
        animated: Bool
    ) {
        switch mode {
        case .boxGlass:
            updateBoxGlasses(
                frames: frames,
                style: style,
                depth: depth,
                animated: animated
            )
        case .plainGlassHug, .plainGlassSpan:
            updatePlainGlass(
                panel: panel,
                frames: frames,
                viewport: viewport,
                plateFrame: plateFrame,
                overflow: mode == .plainGlassSpan,
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
