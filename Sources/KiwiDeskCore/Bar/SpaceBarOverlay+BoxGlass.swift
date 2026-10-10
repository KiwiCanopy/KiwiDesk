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
        // Only the box's host travels (#2095): a glass and its
        // backdrop animating their own frames drift a frame apart,
        // so both fill it by autoresizing; an equal write is skipped.
        let fill: BarFrameMove = { [moveFrame] view, frame, animated in
            if view.frame != frame { moveFrame(view, frame, animated) }
        }
        for i in 0..<n {
            let radius = SpaceBarItemView.boxRadius(
                look: style,
                depth: depth,
                size: frames[i].size
            )
            let glass = boxGlasses[i]
            guard let host = GlassBox.host(of: glass) else { continue }
            host.isHidden = itemViews[i].isHidden
            GlassPlate.setContent(glass, itemViews[i])
            // The pair takes the host's CURRENT bounds before it
            // moves: AppKit steps a travelling frame, and each step
            // autoresizes them by the rest of the size change.
            let bounds = host.bounds
            GlassPlate.update(
                glass,
                frame: bounds,
                cornerRadius: radius,
                move: fill
            )
            let tint = boxTints[i]
            if itemViews[i].isHidden {
                tint.isHidden = true
            } else {
                GlassTint.apply(
                    tint,
                    below: glass,
                    frame: bounds,
                    cornerRadius: radius,
                    hex: style.fillColor,
                    edge: style.edge,
                    animated: false,
                    move: fill
                )
            }
            // A fresh host lands; only a drawn box travels.
            moveFrame(host, frames[i], animated && host.frame != .zero)
        }
    }

    private func syncBoxGlassCount(_ n: Int) {
        while boxGlasses.count > n {
            // Its item left in this render's `syncItemViewCount`.
            GlassBox.drop(boxGlasses.removeLast(), boxTints.removeLast())
        }
        while boxGlasses.count < n {
            guard let pair = GlassBox.make(in: itemRun, spansParent: false)
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
            frontTint?.isHidden = true
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
            GlassPlate.setContent(glass, NSView())
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
            below: glass,
            frame: rect,
            cornerRadius: radius,
            hex: style.fillColor,
            edge: style.edge
        )
    }

    /// Restores hosted items to itemRun and tears down glass boxes.
    func teardownBoxGlasses() {
        frontGlass?.isHidden = true
        frontTint?.isHidden = true
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
