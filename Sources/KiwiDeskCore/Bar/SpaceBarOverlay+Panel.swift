import AppKit

/// Panel plumbing and view hierarchy for SpaceBarOverlay (`BarPanel`, #407).
extension SpaceBarOverlay {
    /// Configures base panel container styling.
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
        layer.backgroundColor = NSColor.clear.cgColor
    }

    /// Updates or hides solid plain background plate (`SpaceBarStyle`).
    func updatePlainPlate(
        _ panel: NSPanel,
        style: SpaceBarStyle,
        strip: CGRect,
        plateFrame: CGRect
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
        plate.frame = plateFrame
        let depth =
            style.edge.isHorizontal ? strip.height : strip.width
        plate.layer?.cornerRadius =
            style.resolvedCornerRadius(forThickness: depth)
        plate.layer?.backgroundColor =
            NSColor(kiwiHex: style.fillColor).cgColor
    }

    /// Resolves glass hosting mode for current render pass (#407).
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

    /// Prepares view hierarchy for target glass hosting mode before layout
    /// (#407).
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

    /// Installs glass views after item layout passes (#407).
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
        // Clipping viewport prevents scrolled items sliding under arrows
        // (#385).
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = true
        view.addSubview(itemContainer)
        view.addSubview(backArrow)
        view.addSubview(forwardArrow)
        return panel
    }
}
