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
            let bare = itemViews[i].isHidden || gliding
            glass.isHidden = bare
            if !gliding { GlassPlate.setContent(glass, itemViews[i]) }
            GlassBox.place(
                glass,
                tint: boxTints[i],
                at: frames[i],
                cornerRadius: radius,
                hex: bare ? nil : style.fillColor,
                edge: style.edge,
                animated: animated,
                move: moveFrame
            )
        }
    }

    /// Adjusts size of box glass and tint views pool.
    private func syncBoxGlassCount(_ n: Int) {
        while boxGlasses.count > n {
            // Its item left in this render's `syncItemViews`.
            GlassBox.drop(boxGlasses.removeLast(), boxTints.removeLast())
        }
        while boxGlasses.count < n {
            guard let pair = makeBoxGlass() else { break }
            boxGlasses.append(pair.glass)
            boxTints.append(pair.tint)
        }
    }

    /// A fresh glass and tint in the run, in a box host of their
    /// own that fades (#1842) and travels (#2095) — the pool's one
    /// mint.
    private func makeBoxGlass() -> (glass: NSView, tint: GlassBackdrop)? {
        GlassBox.make(in: itemRun)
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
        for host in unpaired.values { GlassBox.drop(host.glass, host.tint) }
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

    /// The view a drag moves for `item`: its box's host where a
    /// glass hosts it, so the glass and tint move as one (#2095).
    func draggableView(for item: AppBarItemView) -> NSView {
        guard let i = itemViews.firstIndex(of: item),
            i < boxGlasses.count,
            GlassPlate.holds(boxGlasses[i], item),
            let host = GlassBox.host(of: boxGlasses[i])
        else { return item }
        return host
    }

    /// Detaches items from glass wrappers and tears down box glass views.
    func teardownBoxGlasses() {
        guard !boxGlasses.isEmpty else { return }
        for glass in boxGlasses {
            for item in itemViews where GlassPlate.holds(glass, item) {
                GlassPlate.release(glass)
                itemRun.addSubview(item)
            }
            GlassBox.drop(glass, nil)
        }
        boxGlasses.removeAll()
        for tint in boxTints { tint.removeFromSuperview() }
        boxTints.removeAll()
        boxGlassOwners.removeAll()
    }
}
