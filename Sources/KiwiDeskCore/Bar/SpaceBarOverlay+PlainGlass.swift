import AppKit

/// Plain + Liquid Glass hug for the Space Bar (piece 1, App Bar
/// twin). The frosted plate hugs the run — Space items AND the
/// trailing front-app segment — when it fits, instead of spanning
/// the viewport. Driven at the end of `render`: hugging places the
/// run run-local, which needs the laid-out frames. On overflow the
/// run scrolls and fills the strip, so the plate spans the viewport.
extension SpaceBarOverlay {
    func updatePlainGlass(
        panel: NSPanel,
        viewport: CGRect,
        plateFrame: CGRect,
        overflow: Bool,
        style: SpaceBarStyle,
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
                viewport: viewport,
                plateFrame: plateFrame,
                radius: radius,
                style: style
            )
        }
    }

    /// Every view that rides the run: the Space items plus the loose
    /// front-app segment views. Moved together into the run wrapper.
    private var glassRunViews: [NSView] {
        var views: [NSView] = itemViews
        views += [
            frontBox, frontDivider, frontIcon, frontGlyph, frontName,
        ]
        if let frontGlass { views.append(frontGlass) }
        return views
    }

    /// Overflow / fallback: host the whole item viewport at its
    /// frame — the scrolling run fills the strip, nothing to hug.
    private func spanViewport(
        plate: NSView,
        viewport: CGRect,
        radius: CGFloat,
        style: SpaceBarStyle
    ) {
        returnRunToContainer()
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
    /// with the run (items + front segment) placed run-local — each
    /// view's viewport frame shifted into the plate's space, so it
    /// stays visually put while the plate shrinks to hug it.
    private func hugRun(
        plate: NSView,
        content: NSView,
        viewport: CGRect,
        plateFrame: CGRect,
        radius: CGFloat,
        style: SpaceBarStyle
    ) {
        let run = glassRun ?? AppBarOverlay.FlippedView()
        glassRun = run
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
        for view in glassRunViews {
            if view.superview !== run { run.addSubview(view) }
            view.frame = view.frame.offsetBy(dx: dx, dy: dy)
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

    /// Returns the run views to `itemContainer` (leaving hug mode).
    func returnRunToContainer() {
        guard let run = glassRun else { return }
        for view in glassRunViews where view.superview === run {
            itemContainer.addSubview(view)
        }
    }

    /// Tears the run wrapper down: run back to `itemContainer`, the
    /// wrapper detached from the plate (glass off / shape changed).
    func teardownGlassRun() {
        guard let run = glassRun else { return }
        returnRunToContainer()
        if let plate = glassPlate, GlassPlate.holds(plate, run) {
            GlassPlate.detach(plate)
        }
    }
}
