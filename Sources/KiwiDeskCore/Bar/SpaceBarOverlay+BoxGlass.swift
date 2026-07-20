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
        }
    }

    private func syncBoxGlassCount(_ n: Int) {
        while boxGlasses.count > n {
            let glass = boxGlasses.removeLast()
            GlassPlate.detach(glass)
            glass.removeFromSuperview()
        }
        while boxGlasses.count < n {
            guard let glass = GlassPlate.make() else { break }
            itemContainer.addSubview(glass)
            boxGlasses.append(glass)
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
            return
        }
        guard let glass = frontGlass ?? GlassPlate.make() else {
            return
        }
        frontGlass = glass
        if glass.superview !== itemContainer {
            itemContainer.addSubview(
                glass,
                positioned: .below,
                relativeTo: frontDivider
            )
            // A backdrop glass renders flat without a contentView;
            // a throwaway empty view makes it frost as true glass,
            // and the segment's real views paint over it (they sit
            // above in z, laid out in `itemContainer`).
            GlassPlate.setContent(glass, NSView())
        }
        glass.isHidden = false
        GlassPlate.update(
            glass,
            frame: rect,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
    }

    /// Returns every hosted item to `itemContainer` and tears the
    /// glass boxes down (glass off, or the shape left `boxed`). Uses
    /// `holds` per the reparent-restore gotcha so no item is trapped.
    func teardownBoxGlasses() {
        frontGlass?.isHidden = true
        guard !boxGlasses.isEmpty else { return }
        for glass in boxGlasses {
            for item in itemViews where GlassPlate.holds(glass, item) {
                GlassPlate.detach(glass)
                itemContainer.addSubview(item)
            }
            glass.removeFromSuperview()
        }
        boxGlasses.removeAll()
    }
}
