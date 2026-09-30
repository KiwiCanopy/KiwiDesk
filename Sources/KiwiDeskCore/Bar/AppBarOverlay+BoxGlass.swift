import AppKit

/// Per-item frosted glass rendering and lifecycle for App Bar
/// (`GlassPlate`, #408).
extension AppBarOverlay {
    /// Indicates whether styling specifies per-box glass.
    func wantsBoxGlass(_ style: AppBarLook) -> Bool {
        style.glassEnabled && style.backgroundStyle == .boxed
    }

    /// Hosts each item view in an individual glass plate
    /// (`GlassPlate`, `GlassTint`, #408).
    func updateBoxGlasses(
        frames: [CGRect],
        style: AppBarLook,
        depth: CGFloat,
        animated: Bool
    ) {
        let n = min(frames.count, itemViews.count)
        syncBoxGlassCount(n)
        let radius = style.resolvedCornerRadius(forThickness: depth)
        for i in 0..<n {
            let glass = boxGlasses[i]
            // A member still sliding out of its group travels bare
            // and takes its glass when it lands (#1831).
            let gliding = glidingIn.contains(ObjectIdentifier(itemViews[i]))
            glass.isHidden = itemViews[i].isHidden || gliding
            if !gliding { GlassPlate.setContent(glass, itemViews[i]) }
            GlassPlate.update(
                glass,
                frame: frames[i],
                cornerRadius: radius,
                animated: animated
            )
            let tint = boxTints[i]
            if itemViews[i].isHidden || gliding {
                tint.isHidden = true
            } else {
                GlassTint.apply(
                    tint,
                    below: glass,
                    frame: frames[i],
                    cornerRadius: radius,
                    hex: style.fillColor,
                    edge: style.edge,
                    animated: animated
                )
            }
        }
    }

    /// Adjusts size of box glass and tint views pool.
    private func syncBoxGlassCount(_ n: Int) {
        while boxGlasses.count > n {
            // Its item left in this render's `syncItemViewCount`.
            let glass = boxGlasses.removeLast()
            GlassPlate.release(glass)
            glass.removeFromSuperview()
            boxTints.removeLast().removeFromSuperview()
        }
        while boxGlasses.count < n {
            guard let glass = GlassPlate.make() else { break }
            itemRun.addSubview(glass)
            boxGlasses.append(glass)
            boxTints.append(GlassBackdrop())
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
        guard !boxGlasses.isEmpty else { return }
        for glass in boxGlasses {
            for item in itemViews where GlassPlate.holds(glass, item) {
                GlassPlate.release(glass)
                itemRun.addSubview(item)
            }
            glass.removeFromSuperview()
        }
        boxGlasses.removeAll()
        for tint in boxTints { tint.removeFromSuperview() }
        boxTints.removeAll()
    }
}
