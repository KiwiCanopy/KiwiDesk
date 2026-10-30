import AppKit
import QuartzCore

/// The pocket mark's light (#2776): its edge fading in and out and
/// the lift it takes while hovered. Under Reduce Motion both land at
/// once, since the edge and the size are the cue.
extension BarMotion {
    /// Eases each layer's shadow opacity in `edge` and `lift`'s
    /// sublayer transform to their values; at once where not
    /// `animated` or under Reduce Motion.
    @MainActor
    static func playPocketLight(
        _ edge: [(CALayer, Float)],
        lift: CALayer,
        to transform: CATransform3D,
        lighting: Bool,
        animated: Bool
    ) {
        let eased = pocketLightDuration(
            lighting: lighting,
            reduceMotion: isReduced
        )
        let duration = animated ? eased : 0
        for (layer, opacity) in edge {
            pocketEase(layer, "shadowOpacity", to: opacity, for: duration)
        }
        pocketEase(
            lift,
            "sublayerTransform",
            to: NSValue(caTransform3D: transform),
            for: duration
        )
    }

    /// Nods `layer` once about `centre` from its own sublayer
    /// transform, the brief pocket's nod; nothing under Reduce
    /// Motion.
    @MainActor
    static func playPocketNod(_ layer: CALayer, centre: CGPoint) {
        guard
            let nod = pocketNod(
                from: layer.sublayerTransform,
                centre: centre,
                reduceMotion: isReduced
            )
        else { return }
        layer.add(nod, forKey: "pocketNod")
    }

    /// The nod's swell from `base` and back, sampled from
    /// `BriefPocketPlan.nodSwell` so both pockets nod alike; nil under
    /// `reduceMotion`.
    static func pocketNod(
        from base: CATransform3D,
        centre: CGPoint,
        reduceMotion: Bool
    ) -> CAKeyframeAnimation? {
        guard !reduceMotion else { return nil }
        let steps = 12
        let times = (0...steps).map { CGFloat($0) / CGFloat(steps) }
        let animation = CAKeyframeAnimation(keyPath: "sublayerTransform")
        animation.values = times.map { u in
            let scale = BriefPocketPlan.nodSwell(at: u)
            var swell = CATransform3DTranslate(base, centre.x, centre.y, 0)
            swell = CATransform3DScale(swell, scale, scale, 1)
            swell = CATransform3DTranslate(swell, -centre.x, -centre.y, 0)
            return NSValue(caTransform3D: swell)
        }
        animation.keyTimes = times.map { NSNumber(value: Double($0)) }
        animation.duration = BriefPocketPlan.nod
        return animation
    }

    /// The light's length: in quickly, out slower, nothing under
    /// `reduceMotion`.
    static func pocketLightDuration(
        lighting: Bool,
        reduceMotion: Bool
    ) -> TimeInterval {
        reduceMotion ? 0 : lighting ? 0.12 : 0.25
    }

    /// Writes `value` at `key` and eases there from what shows over
    /// `duration`.
    @MainActor
    private static func pocketEase(
        _ layer: CALayer,
        _ key: String,
        to value: Any,
        for duration: TimeInterval
    ) {
        // A re-paint at the value already written leaves its ease
        // running: a layout re-paints after the look eased (#2776).
        if let held = layer.value(forKeyPath: key) as? NSObject,
            held.isEqual(value)
        {
            return
        }
        let shown =
            layer.presentation()?.value(forKeyPath: key)
            ?? layer.value(forKeyPath: key)
        layer.setValue(value, forKeyPath: key)
        guard duration > 0 else {
            layer.removeAnimation(forKey: key)
            return
        }
        let animation = CABasicAnimation(keyPath: key)
        animation.fromValue = shown
        animation.toValue = value
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: key)
    }
}
