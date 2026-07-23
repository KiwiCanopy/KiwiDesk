import AppKit

/// Per-box Liquid Glass for the Space Bar (piece 2, App Bar twin).
/// Under `boxed + liquid_glass` each Space item gets its own frosted
/// `NSGlassEffectView` hosting the item as `contentView`, and the
/// trailing front-app segment gets a backdrop frosted box behind its
/// loose views (it is non-interactive, so it need not host them).
/// Colorless on macOS 26.5.2 — a look-first increment; drag-autoscroll
/// and container-merge follow once the look earns them.
extension SpaceBarOverlay {
    /// The resolved style wants per-box glass: the glass finish over
    /// the boxed shape. (Plain + glass keeps the single plate.)
    func wantsBoxGlass(_ style: SpaceBarStyle) -> Bool {
        style.glassEnabled && style.tabBackground == .boxed
    }

    /// Hosts each Space item in its own glass box at `frames[i]`,
    /// tinted by Fill and rounded against the bar's cross `depth`.
    func updateBoxGlasses(
        frames: [CGRect],
        style: SpaceBarStyle,
        depth: CGFloat
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
                tintHex: style.fillColor
            )
            // Colored backdrop behind the box so the glass refracts
            // a hue (#408); hidden with the box, or for a transparent
            // Fill (clear glass).
            let tint = boxTints[i]
            if tinted && !itemViews[i].isHidden {
                GlassTint.apply(
                    tint,
                    below: glass,
                    frame: frames[i],
                    cornerRadius: radius,
                    hex: style.fillColor
                )
            } else {
                tint.isHidden = true
            }
        }
    }

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

    /// The front-app segment's backdrop frosted box: sized to `rect`
    /// (nil hides it), sitting just below the segment's loose views.
    func updateFrontGlass(
        _ rect: CGRect?,
        radius: CGFloat,
        style: SpaceBarStyle
    ) {
        guard let rect else {
            frontGlass?.isHidden = true
            frontTint?.isHidden = true
            return
        }
        guard let glass = frontGlass ?? GlassPlate.make() else {
            return
        }
        frontGlass = glass
        // Follow the loose front views to their host (#409): the
        // clipping viewport as the run's tail, or the panel content
        // while pinned. Kept just below the divider so the segment's
        // real views paint over the frosted backdrop.
        let host = frontHost ?? itemContainer
        if glass.superview !== host {
            host.addSubview(
                glass,
                positioned: .below,
                relativeTo: frontDivider
            )
            // A backdrop glass renders flat without a contentView;
            // a throwaway empty view makes it frost as true glass,
            // and the segment's real views paint over it (they sit
            // above in z, in the same `frontHost` — the viewport, or
            // the panel content while pinned, #409).
            GlassPlate.setContent(glass, NSView())
        }
        glass.isHidden = false
        GlassPlate.update(
            glass,
            frame: rect,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
        // Colored backdrop so the front glass tints with the boxes
        // (#408), or hidden for a transparent Fill (clear glass).
        let tint = frontTint ?? NSView()
        frontTint = tint
        if GlassTint.wanted(style.fillColor) {
            GlassTint.apply(
                tint,
                below: glass,
                frame: rect,
                cornerRadius: radius,
                hex: style.fillColor
            )
        } else {
            tint.isHidden = true
        }
    }

    /// Returns every hosted item to `itemContainer` and tears the
    /// glass boxes down (glass off, or the shape left `boxed`). Uses
    /// `holds` per the reparent-restore gotcha so no item is trapped.
    func teardownBoxGlasses() {
        frontGlass?.isHidden = true
        frontTint?.isHidden = true
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
