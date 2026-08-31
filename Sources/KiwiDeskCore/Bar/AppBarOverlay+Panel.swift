import AppKit

/// Panel plumbing and view container styling for AppBarOverlay.
extension AppBarOverlay {
    /// Flipped so the first item sits at the visual top of
    /// vertical bars.
    final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// Configures container layer properties (`background_fit`).
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
        layer.backgroundColor = NSColor.clear.cgColor
    }

    /// Updates plain shared background plate geometry and style.
    func updatePlainPlate(
        _ panel: NSPanel,
        style: AppBarStyle,
        strip: CGRect,
        plateFrame: CGRect,
        animated: Bool = false
    ) {
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

    /// Resolves glass hosting mode (#407).
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

    /// Prepares container hierarchy for glass hosting before item layout
    /// (`GlassPlate.holds`, #407).
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
            restoreItemContainer(to: content, viewport: viewport)
            teardownGlassRun()
            glassPlate?.isHidden = true
            glassTint?.isHidden = true
        case .plainGlassHug, .plainGlassSpan:
            teardownBoxGlasses()
        case .plainPlate, .none:
            teardownBoxGlasses()
            restoreItemContainer(to: content, viewport: viewport)
            teardownGlassRun()
            glassPlate?.isHidden = true
            glassTint?.isHidden = true
        }
    }

    /// Installs target glass hosting mode from computed frames (#407).
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
