import AppKit

/// Per-item frosted glass rendering and lifecycle for App Bar
/// (`GlassPlate`, #408).
extension AppBarOverlay {
    /// Indicates whether styling specifies per-box glass.
    func wantsBoxGlass(_ style: AppBarStyle) -> Bool {
        style.glassEnabled && style.backgroundStyle == .boxed
    }

    /// Hosts each item view in an individual glass plate
    /// (`GlassPlate`, `GlassTint`, #408).
    func updateBoxGlasses(
        frames: [CGRect],
        style: AppBarStyle,
        depth: CGFloat,
        animated: Bool
    ) {
        let n = min(frames.count, itemViews.count)
        syncBoxGlassCount(n)
        let radius = style.resolvedCornerRadius(forThickness: depth)
        let tinted = GlassTint.wanted(style.fillColor)
        for i in 0..<n {
            let glass = boxGlasses[i]
            glass.isHidden = itemViews[i].isHidden
            GlassPlate.setContent(glass, itemViews[i])
            GlassPlate.update(
                glass,
                frame: frames[i],
                cornerRadius: radius,
                tintHex: style.fillColor,
                animated: animated
            )
            let tint = boxTints[i]
            if tinted && !itemViews[i].isHidden {
                GlassTint.apply(
                    tint,
                    below: glass,
                    frame: frames[i],
                    cornerRadius: radius,
                    hex: style.fillColor,
                    animated: animated
                )
            } else {
                tint.isHidden = true
            }
        }
    }

    /// Adjusts size of box glass and tint views pool.
    private func syncBoxGlassCount(_ n: Int) {
        while boxGlasses.count > n {
            let glass = boxGlasses.removeLast()
            GlassPlate.detach(glass)
            glass.removeFromSuperview()
            boxTints.removeLast().removeFromSuperview()
        }
        while boxGlasses.count < n {
            guard let glass = GlassPlate.make() else { break }
            itemContainer.addSubview(glass)
            boxGlasses.append(glass)
            boxTints.append(NSView())
        }
    }

    /// Updates frosted glass backdrops behind scroll arrows
    /// (`BarArrowView`, #408).
    func updateArrowGlasses(style: AppBarStyle) {
        guard let content = itemContainer.superview else { return }
        updateArrowGlass(
            &backArrowGlass,
            tint: &backArrowTint,
            behind: backArrow,
            in: content,
            style: style
        )
        updateArrowGlass(
            &forwardArrowGlass,
            tint: &forwardArrowTint,
            behind: forwardArrow,
            in: content,
            style: style
        )
    }

    private func updateArrowGlass(
        _ glass: inout NSView?,
        tint: inout NSView?,
        behind arrow: BarArrowView,
        in content: NSView,
        style: AppBarStyle
    ) {
        guard !arrow.isHidden else {
            glass?.isHidden = true
            tint?.isHidden = true
            return
        }
        guard let box = glass ?? GlassPlate.make() else { return }
        glass = box
        if box.superview !== content {
            content.addSubview(box, positioned: .below, relativeTo: arrow)
            GlassPlate.setContent(box, NSView())
        }
        box.isHidden = false
        let radius =
            max(0, min(style.cornerRoundness, 100)) / 100
            * (min(arrow.frame.width, arrow.frame.height) / 2)
        GlassPlate.update(
            box,
            frame: arrow.frame,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
        let backdrop = tint ?? NSView()
        tint = backdrop
        if GlassTint.wanted(style.fillColor) {
            GlassTint.apply(
                backdrop,
                below: box,
                frame: arrow.frame,
                cornerRadius: radius,
                hex: style.fillColor
            )
        } else {
            backdrop.isHidden = true
        }
    }

    /// Returns the target view for drag operations (`AppBarItemView`).
    func draggableView(for item: AppBarItemView) -> NSView {
        guard let i = itemViews.firstIndex(of: item),
            i < boxGlasses.count,
            GlassPlate.holds(boxGlasses[i], item)
        else { return item }
        return boxGlasses[i]
    }

    /// Detaches items from glass wrappers and tears down box glass views.
    func teardownBoxGlasses() {
        backArrowGlass?.isHidden = true
        forwardArrowGlass?.isHidden = true
        backArrowTint?.isHidden = true
        forwardArrowTint?.isHidden = true
        guard !boxGlasses.isEmpty else { return }
        for glass in boxGlasses {
            for item in itemViews where GlassPlate.holds(glass, item) {
                GlassPlate.detach(glass)
                itemContainer.addSubview(item)
            }
            glass.removeFromSuperview()
        }
        boxGlasses.removeAll()
        for tint in boxTints { tint.removeFromSuperview() }
        boxTints.removeAll()
    }
}
