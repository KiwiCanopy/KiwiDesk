import AppKit

/// View plumbing for AppBarOverlay (#1517): the section draws into
/// `root`; the plate beneath it is the shelf's.
extension AppBarOverlay {
    /// Flipped so the first item sits at the visual top of
    /// vertical bars.
    /// Open, not `final`: the #1315 churn guard subclasses it.
    class FlippedView: NSView {
        override var isFlipped: Bool { true }

        #if DEBUG
            /// Subviews added, re-adds included: AppKit reports a
            /// same-parent re-add to no hook, so the #1315 churn
            /// guards count it at the parent.
            private(set) var insertCount = 0

            override func addSubview(_ view: NSView) {
                insertCount += 1
                super.addSubview(view)
            }

            override func addSubview(
                _ view: NSView,
                positioned place: NSWindow.OrderingMode,
                relativeTo otherView: NSView?
            ) {
                insertCount += 1
                super.addSubview(
                    view,
                    positioned: place,
                    relativeTo: otherView
                )
            }
        #endif
    }

    /// Resolves the section's own glass hosting (#407).
    func glassHosting(_ style: AppBarLook) -> GlassHosting {
        GlassHosting.resolve(
            available: AppBarStyle.glassAvailable,
            glassEnabled: style.glassEnabled,
            boxed: style.backgroundStyle == .boxed
        )
    }

    /// Installs per-item glass after item layout, or tears it
    /// down in any other mode (#407).
    func installGlassHosting(
        _ mode: GlassHosting,
        frames: [CGRect],
        style: AppBarLook,
        depth: CGFloat,
        animated: Bool
    ) {
        guard mode == .boxGlass else {
            teardownBoxGlasses()
            return
        }
        updateBoxGlasses(
            frames: frames,
            style: style,
            depth: depth,
            animated: animated
        )
    }

    func syncItemViewCount(_ count: Int) {
        while itemViews.count > count {
            itemViews.removeLast().removeFromSuperview()
        }
        while itemViews.count < count {
            let view = AppBarItemView()
            itemViews.append(view)
            itemContainer.addSubview(view)
        }
    }

    /// Builds the section's view once. Items render inside a
    /// clipping viewport that fades at its hidden ends (#1517).
    func configureRoot() {
        root.wantsLayer = true
        root.isHidden = true
        root.layer?.masksToBounds = true
        root.layer?.backgroundColor = NSColor.clear.cgColor
        itemContainer.wantsLayer = true
        itemContainer.layer?.masksToBounds = true
        root.addSubview(itemContainer)
        root.addSubview(backCount)
        root.addSubview(forwardCount)
        root.onScroll = { [weak self] in self?.scroll($0) ?? false }
    }
}
