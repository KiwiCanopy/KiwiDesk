import AppKit

/// View plumbing for SpaceBarOverlay (#407, #1517): the section
/// draws into `root`; the plate beneath it is the shelf's.
extension SpaceBarOverlay {
    /// Resolves the section's own glass hosting (#407).
    func glassHosting(_ style: SpaceBarLook) -> GlassHosting {
        GlassHosting.resolve(
            available: AppBarStyle.glassAvailable,
            glassEnabled: style.glassEnabled,
            boxed: style.backgroundStyle == .boxed
        )
    }

    /// Prepares the hierarchy for `mode` before layout, and picks
    /// the front segment's host with it: the root while pinned,
    /// else the item container — so a steady render reparents
    /// nothing (#1315).
    func prepareGlassHosting(
        _ mode: GlassHosting,
        pinnedFront: Bool
    ) {
        if mode != .boxGlass { teardownBoxGlasses() }
        frontHost = pinnedFront ? root : itemContainer
    }

    /// Installs per-item glass after item layout (#407).
    func installGlassHosting(
        _ mode: GlassHosting,
        frames: [CGRect],
        style: SpaceBarLook,
        depth: CGFloat
    ) {
        guard mode == .boxGlass else { return }
        updateBoxGlasses(frames: frames, style: style, depth: depth)
    }

    func syncItemViewCount(_ count: Int) {
        while itemViews.count > count {
            itemViews.removeLast().removeFromSuperview()
        }
        while itemViews.count < count {
            let view = SpaceBarItemView()
            itemViews.append(view)
            itemContainer.addSubview(view)
        }
    }

    /// Builds the section's view once.
    func configureRoot() {
        root.wantsLayer = true
        root.isHidden = true
        root.layer?.masksToBounds = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        // Clipping viewport: the run fades at its hidden ends
        // (#385, #1517).
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = true
        itemContainer.addSubview(layerDivider)
        root.addSubview(itemContainer)
        root.addSubview(backCount)
        root.addSubview(forwardCount)
    }
}
