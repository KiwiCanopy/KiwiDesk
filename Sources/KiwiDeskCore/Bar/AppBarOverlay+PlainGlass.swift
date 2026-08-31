import AppKit

/// Plain Liquid Glass plate layout and item hugging for App Bar
/// (`GlassPlate`, #408).
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
            glassDragSpan = nil
            spanViewport(
                plate: plate,
                viewport: viewport,
                radius: radius,
                tintHex: style.fillColor
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

    /// Spans glass plate over full viewport on overflow.
    private func spanViewport(
        plate: NSView,
        viewport: CGRect,
        radius: CGFloat,
        tintHex: String
    ) {
        returnItemsFromGlassRun()
        if !GlassPlate.holds(plate, itemContainer) {
            GlassPlate.setContent(plate, itemContainer)
        }
        GlassPlate.update(
            plate,
            frame: viewport,
            cornerRadius: radius,
            tintHex: tintHex
        )
        applyPlateTint(
            plate: plate,
            frame: viewport,
            radius: radius,
            hex: tintHex
        )
    }

    /// Applies solid colored tint backdrop behind glass plate (#408).
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

    /// Spans glass plate over the viewport during drag reorder: a
    /// drag beginning while the plate hugs would split the mover
    /// (reparented to `itemContainer`) from its reflowing siblings
    /// still in `glassRun` — pre-empt by entering the span state
    /// the drag already works in; `render()` re-hugs on drop.
    func spanPlainGlassForDrag() {
        guard let plate = glassPlate, let run = glassRun,
            let span = glassDragSpan,
            itemViews.contains(where: { $0.superview === run })
        else { return }
        spanViewport(
            plate: plate,
            viewport: span.viewport,
            radius: span.radius,
            tintHex: span.tint
        )
    }

    /// Hugs glass plate around laid out item run.
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
        applyPlateTint(
            plate: plate,
            frame: plateFrame,
            radius: radius,
            hex: style.fillColor
        )
        glassDragSpan = GlassDragSpan(
            viewport: viewport,
            radius: radius,
            tint: style.fillColor
        )
    }

    /// Returns run-hosted items to item container.
    func returnItemsFromGlassRun() {
        guard let run = glassRun else { return }
        for item in itemViews where item.superview === run {
            itemContainer.addSubview(item)
        }
    }

    /// Detaches glass run wrapper and restores item hierarchy.
    func teardownGlassRun() {
        guard let run = glassRun else { return }
        returnItemsFromGlassRun()
        if let plate = glassPlate, GlassPlate.holds(plate, run) {
            GlassPlate.detach(plate)
        }
    }
}
