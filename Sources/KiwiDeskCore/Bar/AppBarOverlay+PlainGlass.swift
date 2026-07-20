import AppKit

/// Plain + Liquid Glass hug (piece 1). The single frosted plate
/// hugs the item run when it fits, instead of spanning the whole
/// viewport. Driven at the end of `render` because hugging places
/// the items run-local, which needs their laid-out frames. On
/// overflow the run scrolls and fills the strip, so the plate falls
/// back to hosting the whole viewport (nothing to hug there).
extension AppBarOverlay {
    func updatePlainGlass(
        panel: NSPanel,
        frames: [CGRect],
        viewport: CGRect,
        plateFrame: CGRect,
        overflow: Bool,
        style: AppBarStyle,
        depth: CGFloat
    ) {
        guard let content = panel.contentView,
            let plate = glassPlate ?? GlassPlate.make()
        else { return }
        glassPlate = plate
        if plate.superview !== content {
            content.addSubview(
                plate,
                positioned: .below,
                relativeTo: backArrow
            )
        }
        plate.isHidden = false
        let radius = style.resolvedCornerRadius(forThickness: depth)
        if overflow {
            spanViewport(
                plate: plate,
                viewport: viewport,
                radius: radius,
                style: style
            )
        } else {
            hugRun(
                plate: plate,
                content: content,
                frames: frames,
                viewport: viewport,
                plateFrame: plateFrame,
                radius: radius,
                style: style
            )
        }
    }

    /// Overflow / fallback: host the whole item viewport at its
    /// frame — the scrolling run fills the strip, nothing to hug.
    private func spanViewport(
        plate: NSView,
        viewport: CGRect,
        radius: CGFloat,
        style: AppBarStyle
    ) {
        returnItemsFromGlassRun()
        if !GlassPlate.holds(plate, itemContainer) {
            GlassPlate.setContent(plate, itemContainer)
        }
        GlassPlate.update(
            plate,
            frame: viewport,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
    }

    /// Hug: the glass takes the plate frame and hosts a run wrapper
    /// with the items placed run-local inside it (their viewport
    /// position shifted into the plate's coordinate space).
    private func hugRun(
        plate: NSView,
        content: NSView,
        frames: [CGRect],
        viewport: CGRect,
        plateFrame: CGRect,
        radius: CGFloat,
        style: AppBarStyle
    ) {
        let run = glassRun ?? AppBarOverlay.FlippedView()
        glassRun = run
        // Hand the viewport back if it currently rides the plate,
        // so only the run wrapper does.
        if GlassPlate.holds(plate, itemContainer) {
            GlassPlate.detach(plate)
            content.addSubview(
                itemContainer,
                positioned: .below,
                relativeTo: backArrow
            )
            itemContainer.frame = viewport
        }
        let dx = viewport.minX - plateFrame.minX
        let dy = viewport.minY - plateFrame.minY
        for (i, item) in itemViews.enumerated() where i < frames.count {
            if item.superview !== run { run.addSubview(item) }
            item.frame = frames[i].offsetBy(dx: dx, dy: dy)
        }
        if !GlassPlate.holds(plate, run) {
            GlassPlate.setContent(plate, run)
        }
        GlassPlate.update(
            plate,
            frame: plateFrame,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
    }

    /// Returns any run-hosted items to `itemContainer` (leaving hug
    /// mode within plain + glass).
    func returnItemsFromGlassRun() {
        guard let run = glassRun else { return }
        for item in itemViews where item.superview === run {
            itemContainer.addSubview(item)
        }
    }

    /// Tears the run wrapper down: items back to `itemContainer`,
    /// wrapper detached from the plate (glass off / shape changed).
    func teardownGlassRun() {
        guard let run = glassRun else { return }
        returnItemsFromGlassRun()
        if let plate = glassPlate, GlassPlate.holds(plate, run) {
            GlassPlate.detach(plate)
        }
    }
}
