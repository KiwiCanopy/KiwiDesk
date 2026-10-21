import AppKit
import QuartzCore

/// `BarMotion`'s unfold half (owner ruling, 2026-10-21), split
/// from the reveal at the §2.1 target: the plate's two-stage
/// stretch, played for `playReveal` alone (`+Spread` the Boxed
/// half).
/// The same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// The timing `playReveal` hands each animation: its fill and
    /// its start, held or at an offset.
    typealias RevealTiming = (CAAnimation, TimeInterval) -> Void

    /// Where a clip of `rect` (the layer's own coordinates) puts
    /// `layer`'s position, so the content stays where it rests.
    @MainActor
    static func clipPlace(_ rect: CGRect, on layer: CALayer) -> CGPoint {
        let frame = layer.convert(rect, to: layer.superlayer)
        let anchor = layer.anchorPoint
        return CGPoint(
            x: frame.minX + anchor.x * frame.width,
            y: frame.minY + anchor.y * frame.height
        )
    }

    /// Plays a plate unfold on the content `layer` and its `items`:
    /// a reveal stretches the clip along the edge and deepens it on
    /// two springs, the items rising on it; a retract fades the
    /// items and collapses the clip back through `along` to the
    /// mark. Either continues from where a motion in flight stands.
    @MainActor
    static func playUnfold(
        _ stretch: ShelfUnfold.Stretch,
        on layer: CALayer,
        items strip: CALayer,
        timed: RevealTiming
    ) {
        let current =
            layer.animationKeys()?.contains(revealKey) == true
            ? layer.presentation() : nil
        let shown =
            strip.animationKeys()?.contains(revealKey) == true
            ? strip.presentation()?.opacity : nil
        let entering = stretch.entering
        let from = current?.bounds ?? (entering ? stretch.mark : stretch.plate)
        let fromPlace = current?.position ?? clipPlace(from, on: layer)
        let fromRadius =
            current?.cornerRadius
            ?? (entering ? stretch.markRadius : stretch.plateRadius)
        let clip: CAAnimation
        if entering {
            clip = unfoldStretch(
                stretch,
                on: layer,
                from: (from, fromPlace, fromRadius)
            )
        } else {
            clip = unfoldCollapse(
                stretch,
                on: layer,
                from: (from, fromPlace, fromRadius)
            )
        }
        timed(clip, entering ? 0 : ShelfUnfold.collapseDelay)
        layer.add(clip, forKey: revealKey)
        let rise = itemsRise(
            entering: entering,
            opacity: shown,
            centre: CGPoint(x: stretch.plate.midX, y: stretch.plate.midY),
            on: strip
        )
        timed(rise, entering ? ShelfUnfold.itemsDelay : 0)
        strip.add(rise, forKey: revealKey)
    }

    /// A clip's start: its bounds, position and corner radius.
    typealias ClipStart = (bounds: CGRect, place: CGPoint, radius: CGFloat)

    /// The reveal's clip: along the edge on one spring, the depth on
    /// a second from `deepenDelay`, each channel its own key paths
    /// so the two compose.
    @MainActor
    private static func unfoldStretch(
        _ stretch: ShelfUnfold.Stretch,
        on layer: CALayer,
        from start: ClipStart
    ) -> CAAnimation {
        let to = clipPlace(stretch.plate, on: layer)
        let along = stretch.horizontal ? "x" : "y"
        let across = stretch.horizontal ? "y" : "x"
        let size = { (rect: CGRect, axis: String) -> CGFloat in
            axis == "x" ? rect.width : rect.height
        }
        let origin = { (rect: CGRect, axis: String) -> CGFloat in
            axis == "x" ? rect.minX : rect.minY
        }
        let point = { (place: CGPoint, axis: String) -> CGFloat in
            axis == "x" ? place.x : place.y
        }
        let spring = {
            (path: String, from: CGFloat, to: CGFloat, deep: Bool)
                -> CASpringAnimation in
            let animation =
                deep
                ? CASpringAnimation(
                    perceptualDuration: ShelfUnfold.deepenDuration,
                    bounce: ShelfUnfold.deepenBounce
                )
                : CASpringAnimation(
                    perceptualDuration: ShelfUnfold.alongDuration,
                    bounce: ShelfUnfold.alongBounce
                )
            animation.keyPath = path
            animation.fromValue = from
            animation.toValue = to
            animation.duration = animation.settlingDuration
            animation.fillMode = .both
            if deep { animation.beginTime = ShelfUnfold.deepenDelay }
            return animation
        }
        let dimension = { (axis: String) -> String in
            axis == "x" ? "width" : "height"
        }
        let channel = { (axis: String, deep: Bool) -> [CASpringAnimation] in
            [
                spring(
                    "bounds.origin.\(axis)",
                    origin(start.bounds, axis),
                    origin(stretch.plate, axis),
                    deep
                ),
                spring(
                    "bounds.size.\(dimension(axis))",
                    size(start.bounds, axis),
                    size(stretch.plate, axis),
                    deep
                ),
                spring(
                    "position.\(axis)",
                    point(start.place, axis),
                    point(to, axis),
                    deep
                ),
            ]
        }
        let parts =
            channel(along, false) + channel(across, true)
            + [
                spring(
                    "cornerRadius",
                    start.radius,
                    stretch.plateRadius,
                    true
                )
            ]
        let group = CAAnimationGroup()
        group.animations = parts
        group.duration = parts.map { $0.beginTime + $0.duration }.max() ?? 0
        return group
    }

    /// The retract's clip: back through `along` to the mark over
    /// `collapse`, ease-in.
    @MainActor
    private static func unfoldCollapse(
        _ stretch: ShelfUnfold.Stretch,
        on layer: CALayer,
        from start: ClipStart
    ) -> CAAnimation {
        let times = [0, ShelfUnfold.alongKeyTime, 1].map {
            NSNumber(value: $0)
        }
        let curve = [
            CAMediaTimingFunction(name: .easeIn),
            CAMediaTimingFunction(name: .easeIn),
        ]
        let frame = { (path: String, values: [Any]) -> CAKeyframeAnimation in
            let animation = CAKeyframeAnimation(keyPath: path)
            animation.values = values
            animation.keyTimes = times
            animation.timingFunctions = curve
            animation.duration = ShelfUnfold.collapse
            return animation
        }
        let alongRadius = min(stretch.along.width, stretch.along.height) / 2
        let group = CAAnimationGroup()
        group.animations = [
            frame("bounds", [start.bounds, stretch.along, stretch.mark]),
            frame(
                "position",
                [
                    start.place,
                    clipPlace(stretch.along, on: layer),
                    clipPlace(stretch.mark, on: layer),
                ]
            ),
            frame(
                "cornerRadius",
                [start.radius, alongRadius, stretch.markRadius]
            ),
        ]
        group.duration = ShelfUnfold.collapse
        return group
    }

    /// The items rising on a plate unfold, or sinking: a fade and a
    /// scale from `itemsScale` about `centre`, the strip's own
    /// coordinates.
    @MainActor
    private static func itemsRise(
        entering: Bool,
        opacity shown: Float?,
        centre: CGPoint,
        on strip: CALayer
    ) -> CAAnimation {
        let length =
            entering ? ShelfUnfold.itemsFadeIn : ShelfUnfold.itemsFadeOut
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = shown ?? (entering ? 0 : 1)
        fade.toValue = entering ? 1 : 0
        let small = scaled(
            ShelfUnfold.itemsScale,
            about: centre,
            on: strip
        )
        let scale = CABasicAnimation(keyPath: "transform")
        scale.fromValue = NSValue(
            caTransform3D: entering
                ? small
                : strip.presentation()?.transform ?? CATransform3DIdentity
        )
        scale.toValue = NSValue(
            caTransform3D: entering ? CATransform3DIdentity : small
        )
        let group = CAAnimationGroup()
        group.animations = [fade, scale]
        group.duration = length
        group.timingFunction = CAMediaTimingFunction(
            name: entering ? .easeOut : .easeIn
        )
        return group
    }

    /// `layer` scaled by `scale` about `point`, its own coordinates.
    @MainActor
    static func scaled(
        _ scale: CGFloat,
        about point: CGPoint,
        on layer: CALayer
    ) -> CATransform3D {
        let anchor = CGPoint(
            x: layer.bounds.minX + layer.anchorPoint.x * layer.bounds.width,
            y: layer.bounds.minY + layer.anchorPoint.y * layer.bounds.height
        )
        return CATransform3DConcat(
            CATransform3DMakeScale(scale, scale, 1),
            CATransform3DMakeTranslation(
                (point.x - anchor.x) * (1 - scale),
                (point.y - anchor.y) * (1 - scale),
                0
            )
        )
    }
}
