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
