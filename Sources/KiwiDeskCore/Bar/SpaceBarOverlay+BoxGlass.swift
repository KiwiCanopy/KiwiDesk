import AppKit

/// Per-box Liquid Glass layout and backdrop tinting for Space Bar
/// (`GlassPlate`, #408).
extension SpaceBarOverlay {
    /// Checks if style requires per-box glass rendering.
    func wantsBoxGlass(_ style: SpaceBarStyle) -> Bool {
        style.glassEnabled && style.backgroundStyle == .boxed
    }

    /// Hosts each Space item in its own glass box with backdrop tint.
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
            boxTints.append(NSView())
        }
    }

    /// Updates front-app segment frosted backdrop glass box (#408, #409).
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
        let host = frontHost ?? itemContainer
        if glass.superview !== host {
            host.addSubview(
                glass,
                positioned: .below,
                relativeTo: frontDivider
            )
            GlassPlate.setContent(glass, NSView())
        }
        glass.isHidden = false
        GlassPlate.update(
            glass,
            frame: rect,
            cornerRadius: radius,
            tintHex: style.fillColor
        )
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

    /// Restores hosted items to itemContainer and tears down glass boxes.
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
