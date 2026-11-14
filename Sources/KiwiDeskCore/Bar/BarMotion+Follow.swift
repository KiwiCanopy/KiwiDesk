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

    /// Whether `host` is gliding to a new size: it carries a Core
    /// Animation bounds animation, the one a follow copies.
    @MainActor
    static func carriesResize(_ host: NSView) -> Bool {
        hostResize(host) != nil
    }

    @MainActor
    private static func hostResize(_ host: NSView) -> CABasicAnimation? {
        host.layer?.animation(forKey: "bounds") as? CABasicAnimation
    }

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
            let animation = hostResize(host),
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

    /// The layers a follow animates — every layer under `pair` at
    /// the host's size, within the half point the backing's
    /// rounding moves one (#2388) — or nil where the box is not the
    /// shape the follow was measured on (#2878): the glass's own
    /// layer filling the host; every pair view, and the glass's
    /// content chain, among the matched; one matched layer in the
    /// glass's private tree that no view backs; and every matched
    /// layer anchored at its origin and standing at the host's
    /// bounds origin, so a bounds animation alone carries it.
    @MainActor
    static func followTargets(
        host: CALayer,
        glass: NSView,
        pair: [NSView]
    ) -> [CALayer]? {
        let size = host.bounds.size
        let atSize = { (layer: CALayer) in
            abs(layer.bounds.width - size.width) <= 0.5
                && abs(layer.bounds.height - size.height) <= 0.5
        }
        guard let glassLayer = glass.layer,
            GlassPlate.fills(glassLayer.bounds, host.bounds)
        else { return nil }
        var matched: [CALayer] = []
        func walk(_ layer: CALayer) {
            if atSize(layer) { matched.append(layer) }
            layer.sublayers?.forEach(walk)
        }
        pair.compactMap(\.layer).forEach(walk)
        let ids = Set(matched.map(ObjectIdentifier.init))
        let required = (pair + GlassPlate.contentChain(glass))
            .map { $0.layer.map(ObjectIdentifier.init) }
        let origin = host.bounds.origin
        guard
            required.allSatisfy({ $0.map(ids.contains) ?? false }),
            matched.contains(where: {
                isInTree($0, of: glassLayer) && !($0.delegate is NSView)
            }),
            matched.allSatisfy({
                $0.anchorPoint == .zero
                    && abs($0.bounds.minX - origin.x) <= 0.5
                    && abs($0.bounds.minY - origin.y) <= 0.5
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
