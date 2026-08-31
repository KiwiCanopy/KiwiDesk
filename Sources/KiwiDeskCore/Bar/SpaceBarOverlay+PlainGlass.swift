import AppKit

/// Liquid Glass plate hosting and positioning for SpaceBarOverlay
/// (`GlassPlate`, #408, #409).
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

    /// Views participating in the glass run hierarchy.
    private var glassRunViews: [NSView] {
        var views: [NSView] = itemViews
        views += [
            frontBox, frontDivider, frontIcon, frontGlyph, frontName,
        ]
        if let frontGlass { views.append(frontGlass) }
        return views
    }

    /// Hosts item container in glass plate spanning the entire viewport.
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

    /// Spans the plate as a backdrop under items AND the pinned
    /// front segment (#409). It does NOT host the items: a hosted
    /// view is auto-sized to the glass bounds, which would break
    /// the scroll clip — the items keep their own
    /// `itemContainer`.
    private func spanBackdrop(
        plate: NSView,
        content: NSView,
        viewport: CGRect,
        plateFrame: CGRect,
        radius: CGFloat,
        style: SpaceBarStyle
    ) {
        returnRunToContainer()
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

    /// Applies optional colored backdrop tint behind glass plate
    /// (`GlassTint`, #408).
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

    /// Shrinks glass plate to hug run items and front segment.
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

    /// Restores run subviews to `itemContainer`.
    func returnRunToContainer() {
        guard let run = glassRun else { return }
        for view in glassRunViews where view.superview === run {
            itemContainer.addSubview(view)
        }
    }

    /// Detaches glass run wrapper and reparents views to item container.
    func teardownGlassRun() {
        guard let run = glassRun else { return }
        returnRunToContainer()
        if let plate = glassPlate, GlassPlate.holds(plate, run) {
            GlassPlate.detach(plate)
        }
    }
}
