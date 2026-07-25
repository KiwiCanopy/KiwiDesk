import AppKit

/// Per-box Liquid Glass (piece 2). Under `boxed + liquid_glass`
/// each tab gets its own frosted `NSGlassEffectView` hosting the
/// item as its `contentView`, instead of the single shared plate —
/// so the "boxed" shape survives the glass finish. Drag/reflow
/// operates on the glass box (`draggableView`), and the scroll
/// arrows get frosted backdrop boxes so they match. Colorless on
/// macOS 26.5.2 (tint shifts luminance only). Container-merge (so
/// adjacent boxes fuse) is a remaining refinement.
extension AppBarOverlay {
    /// The resolved style wants per-box glass: the glass finish over
    /// the boxed shape. (Plain + glass keeps the single plate.)
    func wantsBoxGlass(_ style: AppBarStyle) -> Bool {
        style.glassEnabled && style.backgroundStyle == .boxed
    }

    /// Hosts each item in its own glass box at `frames[i]`, tinted
    /// by Fill and rounded against the bar's cross `depth`. The item
    /// is auto-sized to the glass bounds, so the box frame — not the
    /// item's own frame — carries the layout here.
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
            // Colored backdrop behind the box so the glass refracts
            // a hue (#408); hidden with the box, or when the Fill is
            // transparent (clear glass).
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

    /// Grows / shrinks the glass-box pool to `n`. Boxes live inside
    /// `itemContainer` so they clip and scroll with the run.
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
            // One tint backdrop per box, kept parallel (#408).
            boxTints.append(NSView())
        }
    }

    /// Frosted backdrop boxes behind the visible scroll arrows, so
    /// they match the tabs. The arrows stay on top and interactive
    /// (their own box is set transparent in `layoutArrows`); a
    /// backdrop is enough since they need no `contentView` hosting.
    func updateArrowGlasses(style: AppBarStyle) {
        // The arrows ride the panel content (itemContainer's
        // superview), the same layer they sit in when unglassed.
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
            // Dummy content so a backdrop glass frosts (see the front
            // segment); the arrow paints its chevron above it.
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
        // Colored backdrop so the arrow glass tints with the boxes
        // (#408), or hidden for a transparent Fill (clear glass).
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

    /// The view drag moves for `item`: its glass box while per-box
    /// glass hosts it, else the item itself. Both ride
    /// `itemContainer`, so the drag/reflow math is coordinate-
    /// identical either way.
    func draggableView(for item: AppBarItemView) -> NSView {
        guard let i = itemViews.firstIndex(of: item),
            i < boxGlasses.count,
            GlassPlate.holds(boxGlasses[i], item)
        else { return item }
        return boxGlasses[i]
    }

    /// Returns every hosted item to `itemContainer` and tears the
    /// glass boxes down (glass off, or the shape left `boxed`).
    /// Uses `holds` per the reparent-restore gotcha, so no item is
    /// left trapped inside a hidden glass wrapper.
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
