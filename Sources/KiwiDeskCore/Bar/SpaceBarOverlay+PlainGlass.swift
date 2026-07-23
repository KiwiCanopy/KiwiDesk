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
        pinnedFront: Bool,
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
        if overflow && pinnedFront {
            // The front segment is pinned OUTSIDE the scrolling
            // viewport (#409), so the plate can't just host the item
            // viewport — it would leave the pinned app on bare panel.
            // Span the whole strip as a frosted backdrop under BOTH
            // the scrolling items and the pinned segment (siblings
            // above it), so the app sits on one continuous plate.
            spanBackdrop(
                plate: plate,
                content: content,
                viewport: viewport,
                plateFrame: plateFrame,
                radius: radius,
                style: style
            )
        } else if overflow {
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
        applyPlateTint(
            plate: plate,
            frame: viewport,
            radius: radius,
            hex: style.fillColor
        )
    }

    /// Pinned overflow (#409): the plate spans the WHOLE strip as a
    /// frosted backdrop (empty content frosts as true glass — the
    /// `frontGlass` precedent), sitting below both the scrolling
    /// item viewport and the pinned front segment (siblings above
    /// it), so the pinned app rides one continuous plate instead of
    /// bare panel. It does NOT host the items: a hosted view is
    /// auto-sized to the glass bounds, which would break the scroll
    /// clip. The items keep their own `itemContainer`.
    private func spanBackdrop(
        plate: NSView,
        content: NSView,
        viewport: CGRect,
        plateFrame: CGRect,
        radius: CGFloat,
        style: SpaceBarStyle
    ) {
        returnRunToContainer()
        // Release the item viewport back to a plain sibling if a
        // prior render hosted it (leaving span/hug hosting).
        if GlassPlate.holds(plate, itemContainer) {
            GlassPlate.detach(plate)
            content.addSubview(
                itemContainer,
                positioned: .below,
                relativeTo: backArrow
            )
            itemContainer.frame = viewport
        }
        GlassPlate.setContent(plate, glassBackdropFiller)
        content.addSubview(
            plate,
            positioned: .below,
            relativeTo: itemContainer
        )
        GlassPlate.update(
            plate,
            frame: plateFrame,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
        applyPlateTint(
            plate: plate,
            frame: plateFrame,
            radius: radius,
            hex: style.fillColor
        )
    }

    /// Solid colored backdrop behind the glass plate so the near-
    /// colorless glass refracts a hue (#408); hidden for a
    /// transparent Fill (clear glass). Tracks the plate's frame.
    private func applyPlateTint(
        plate: NSView,
        frame: CGRect,
        radius: CGFloat,
        hex: String
    ) {
        let backdrop = glassTint ?? NSView()
        glassTint = backdrop
        if GlassTint.wanted(hex) {
            GlassTint.apply(
                backdrop,
                below: plate,
                frame: frame,
                cornerRadius: radius,
                hex: hex
            )
        } else {
            backdrop.isHidden = true
        }
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
        applyPlateTint(
            plate: plate,
            frame: plateFrame,
            radius: radius,
            hex: style.fillColor
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
