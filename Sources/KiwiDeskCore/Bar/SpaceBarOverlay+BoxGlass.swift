import AppKit

/// Per-box Liquid Glass layout and backdrop tinting for Space Bar
/// (`GlassPlate`, #408).
extension SpaceBarOverlay {
    /// Checks if style requires per-box glass rendering.
    func wantsBoxGlass(_ style: SpaceBarLook) -> Bool {
        style.glassEnabled && style.backgroundStyle == .boxed
    }

    /// Hosts each Space item in its own glass box with backdrop tint.
    func updateBoxGlasses(
        frames: [CGRect],
        style: SpaceBarLook,
        depth: CGFloat,
        animated: Bool
    ) {
        let n = min(frames.count, itemViews.count)
        syncBoxGlassCount(n)
        for i in 0..<n {
            let radius = SpaceBarItemView.boxRadius(
                look: style,
                depth: depth,
                size: frames[i].size
            )
            let glass = boxGlasses[i]
            GlassPlate.setContent(glass, itemViews[i])
            GlassBox.place(
                glass,
                tint: boxTints[i],
                at: frames[i],
                cornerRadius: radius,
                fill: style.glassFill,
                edge: style.edge,
                visible: !itemViews[i].isHidden,
                animated: animated,
                move: moveFrame
            )
        }
    }

    private func syncBoxGlassCount(_ n: Int) {
        while boxGlasses.count > n {
            // Its item left in this render's `syncItemViewCount`.
            GlassBox.drop(boxGlasses.removeLast(), boxTints.removeLast())
        }
        while boxGlasses.count < n {
            guard let pair = GlassBox.make(in: itemRun)
            else { break }
            boxGlasses.append(pair.glass)
            boxTints.append(pair.tint)
        }
    }

    /// Updates front-app segment frosted backdrop glass box (#408, #409).
    func updateFrontGlass(
        _ rect: CGRect?,
        radius: CGFloat,
        style: SpaceBarLook
    ) {
        guard let rect else {
            frontGlass?.isHidden = true
            return
        }
        guard let glass = frontGlass ?? GlassPlate.make() else {
            return
        }
        frontGlass = glass
        let host = frontHost ?? itemRun
        if glass.superview !== host {
            host.addSubview(
                glass,
                positioned: .below,
                relativeTo: frontBorder
            )
        }
        glass.isHidden = false
        GlassPlate.update(
            glass,
            frame: rect,
            cornerRadius: radius
        )
        let tint = frontTint ?? GlassBackdrop()
        frontTint = tint
        GlassTint.apply(
            tint,
            in: glass,
            cornerRadius: radius,
            fill: style.glassFill,
            edge: style.edge
        )
    }

    /// Restores hosted items to itemRun and tears down glass boxes.
    func teardownBoxGlasses() {
        frontGlass?.isHidden = true
        guard !boxGlasses.isEmpty else { return }
        for (glass, tint) in zip(boxGlasses, boxTints) {
            for item in itemViews where GlassPlate.holds(glass, item) {
                GlassPlate.release(glass)
                itemRun.addSubview(item)
            }
            GlassBox.drop(glass, tint)
        }
        boxGlasses.removeAll()
        boxTints.removeAll()
    }
}
