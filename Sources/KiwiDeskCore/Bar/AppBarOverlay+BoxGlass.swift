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
        boxGlassOwners = itemViews.prefix(n).map(\.windowID)
        for i in 0..<n {
            let glass = boxGlasses[i]
            // A member still sliding out of its group travels bare
            // and takes its glass when it lands (#1831).
            let gliding = glidingIn.contains(itemViews[i].windowID)
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
            // Its item left in this render's `syncItemViews`.
            let glass = boxGlasses.removeLast()
            GlassPlate.release(glass)
            glass.removeFromSuperview()
            boxTints.removeLast().removeFromSuperview()
        }
        while boxGlasses.count < n {
            guard let pair = makeBoxGlass() else { break }
            boxGlasses.append(pair.glass)
            boxTints.append(pair.tint)
        }
    }

    /// A fresh glass and tint in the run — the pool's one mint.
    private func makeBoxGlass() -> (glass: NSView, tint: GlassBackdrop)? {
        guard let glass = GlassPlate.make() else { return nil }
        itemRun.addSubview(glass)
        return (glass, GlassBackdrop())
    }

    /// Re-orders the glass pool to follow `ids`, by the window each
    /// glass is paired with (#1831): a window with no glass yet
    /// takes a fresh one at its place, and a glass no window keeps
    /// leaves through `GlassPlate.release` (#1730). A pool that
    /// cannot mint is left short for `syncBoxGlassCount` to refill.
    func pairBoxGlasses(
        with ids: [WindowID],
        hosts: [WindowID: (glass: NSView, tint: GlassBackdrop)]
    ) {
        var unpaired = hosts
        var glasses: [NSView] = []
        var tints: [GlassBackdrop] = []
        for id in ids {
            if let host = unpaired.removeValue(forKey: id) {
                glasses.append(host.glass)
                tints.append(host.tint)
            } else if let pair = makeBoxGlass() {
                glasses.append(pair.glass)
                tints.append(pair.tint)
            } else {
                break
            }
        }
        for host in unpaired.values {
            GlassPlate.release(host.glass)
            host.glass.removeFromSuperview()
            host.tint.removeFromSuperview()
        }
        boxGlasses = glasses
        boxTints = tints
        boxGlassOwners = Array(ids.prefix(glasses.count))
    }

    /// Each box glass and tint by the window it is paired with.
    func boxGlassHosts() -> [WindowID: (glass: NSView, tint: GlassBackdrop)] {
        var hosts: [WindowID: (glass: NSView, tint: GlassBackdrop)] = [:]
        for (index, id) in boxGlassOwners.enumerated()
        where index < boxGlasses.count && index < boxTints.count {
            hosts[id] = (boxGlasses[index], boxTints[index])
        }
        return hosts
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
        boxGlassOwners.removeAll()
    }
}
