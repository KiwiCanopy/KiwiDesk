import AppKit
import QuartzCore

/// A glass box's one frame writer and the follow that carries the
/// glass through its host's glide (#2878 ruling amendment,
/// 2026-11-14; `.claude/rules/bars.md` ▸ a glass is written without
/// motion and follows its host).
extension BarMotion {
    /// Writes `view`'s frame at once, with no motion, even inside an
    /// animation group: a glass frame written in the host's group
    /// was stepped by AppKit on the main thread, a frame behind the
    /// host (#2878, device). An equal frame is not rewritten.
    @MainActor
    static func writeStill(_ view: NSView, _ frame: CGRect) {
        guard view.frame != frame else { return }
        still { view.frame = frame }
    }

    /// Lays `view`'s subtree out now, with no motion, so its layers
    /// stand at its frame before `followHostResize` reads them.
    @MainActor
    static func layoutStill(_ view: NSView) {
        still { view.layoutSubtreeIfNeeded() }
    }

    @MainActor
    private static func still(_ body: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0
            context.allowsImplicitAnimation = false
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            body()
            CATransaction.commit()
        }
    }

    /// The key a follow animation is added under.
    static let followKey = "kiwi.follow.bounds"

    /// Copies `host`'s Core Animation bounds animation onto every
    /// layer of `pair` — the views the host writes to its bounds —
    /// that stands at the host's size, so glass and host share one
    /// clock. All or nothing: it adds nothing, and returns false,
    /// unless the shape check `followTargets` passes; the host's
    /// landing settle repairs the frame then, as before.
    @MainActor
    @discardableResult
    static func followHostResize(
        _ host: NSView,
        glass: NSView,
        pair: [NSView]
    ) -> Bool {
        guard let hostLayer = host.layer,
            let animation = hostLayer.animation(forKey: "bounds")
                as? CABasicAnimation,
            let targets = followTargets(
                host: hostLayer,
                glass: glass,
                pair: pair
            )
        else { return false }
        for layer in targets {
            layer.add(animation.copy() as! CAAnimation, forKey: followKey)
        }
        return true
    }

    /// The layers a follow animates, or nil where the glass is not
    /// the shape the follow was measured on (#2878): the glass's
    /// own layer filling the host after layout, which rounds it to
    /// the backing (#2388); at least one layer at the glass's size
    /// in its private tree that no view backs; and every layer at
    /// that size anchored at its origin and at the host's bounds
    /// origin, so a bounds animation alone carries it.
    @MainActor
    static func followTargets(
        host: CALayer,
        glass: NSView,
        pair: [NSView]
    ) -> [CALayer]? {
        guard let glassLayer = glass.layer,
            GlassPlate.fills(glassLayer.bounds, host.bounds)
        else { return nil }
        let size = glassLayer.bounds.size
        var matched: [CALayer] = []
        func walk(_ layer: CALayer) {
            if layer.bounds.size == size { matched.append(layer) }
            layer.sublayers?.forEach(walk)
        }
        pair.compactMap(\.layer).forEach(walk)
        let glassTree = Set(
            matched.filter { isInTree($0, of: glassLayer) }
                .map(ObjectIdentifier.init)
        )
        guard
            matched.contains(where: {
                glassTree.contains(ObjectIdentifier($0))
                    && !($0.delegate is NSView)
            }),
            matched.allSatisfy({
                $0.anchorPoint == .zero
                    && $0.bounds.origin == host.bounds.origin
            })
        else { return nil }
        return matched
    }

    @MainActor
    private static func isInTree(_ layer: CALayer, of root: CALayer) -> Bool {
        var current: CALayer? = layer
        while let node = current {
            if node === root { return true }
            current = node.superlayer
        }
        return false
    }
}
