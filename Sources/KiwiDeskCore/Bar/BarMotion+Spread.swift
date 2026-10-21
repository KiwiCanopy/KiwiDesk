import AppKit
import QuartzCore

/// `BarMotion`'s Boxed unfold (owner ruling, 2026-10-21), split
/// from the plate unfold at the §2.1 target: each box springs out
/// of the mark to its slot, played for `playReveal` alone. The
/// same one home — `BarMotionSeamTests` censuses this file.
extension BarMotion {
    /// The boxes a spread moves, in `items`: each box host, and
    /// each item a host does not hold; what holds no box, as a
    /// whole, fades in place (`still`).
    @MainActor
    static func spreadUnits(
        in items: NSView
    ) -> (boxes: [NSView], still: [NSView]) {
        var boxes: [NSView] = []
        var still: [NSView] = []
        func isBox(_ view: NSView) -> Bool { view is ShelfSpreadBox }
        func holdsBox(_ view: NSView) -> Bool {
            view.subviews.contains { isBox($0) || holdsBox($0) }
        }
        func walk(_ view: NSView) {
            for sub in view.subviews where !sub.isHidden {
                if isBox(sub) {
                    boxes.append(sub)
                } else if holdsBox(sub) {
                    walk(sub)
                } else {
                    still.append(sub)
                }
            }
        }
        walk(items)
        return (boxes, still)
    }

    /// Plays a Boxed unfold: each box — its glass host, never the
    /// glass — springs out of the mark to its slot, the farther
    /// later, or gathers back into it, the outer first; what holds
    /// no box fades in place. A box in flight continues from where
    /// it stands.
    @MainActor
    static func playSpread(
        _ spread: ShelfUnfold.Spread,
        on content: NSView,
        items: NSView,
        timed: RevealTiming
    ) {
        content.layer?.removeAnimation(forKey: revealKey)
        items.layer?.removeAnimation(forKey: revealKey)
        let entering = spread.entering
        let (boxes, still) = spreadUnits(in: items)
        for view in boxes {
            view.wantsLayer = true
            // In view coordinates, which are the superlayer's for a
            // layer-backed view: the layer tree may not be connected
            // yet in the pass that orders the panel in.
            guard let layer = view.layer, let parent = view.superview
            else { continue }
            let mark = parent.convert(spread.mark, from: content)
            let frame = view.frame
            let shift = CGPoint(x: mark.x - frame.midX, y: mark.y - frame.midY)
            let away = CATransform3DConcat(
                PopRoom.transform(
                    scale: ShelfUnfold.spreadScale,
                    size: layer.bounds.size,
                    anchor: layer.anchorPoint
                ),
                CATransform3DMakeTranslation(shift.x, shift.y, 0)
            )
            let delay = ShelfUnfold.delay(
                distance: spread.horizontal ? shift.x : shift.y,
                span: spread.span,
                entering: entering
            )
            let current =
                layer.animationKeys()?.contains(revealKey) == true
                ? layer.presentation() : nil
            let move: CABasicAnimation
            if entering {
                let spring = CASpringAnimation(
                    perceptualDuration: ShelfUnfold.spreadDuration,
                    bounce: ShelfUnfold.spreadBounce
                )
                spring.duration = spring.settlingDuration
                move = spring
            } else {
                move = CABasicAnimation()
                move.duration = ShelfUnfold.gather
                move.timingFunction = CAMediaTimingFunction(name: .easeIn)
            }
            move.keyPath = "transform"
            move.fromValue = NSValue(
                caTransform3D: current?.transform
                    ?? (entering ? away : CATransform3DIdentity)
            )
            move.toValue = NSValue(
                caTransform3D: entering ? CATransform3DIdentity : away
            )
            move.fillMode = .both
            let fade = spreadFade(
                entering: entering,
                from: current?.opacity,
                at: entering ? 0 : ShelfUnfold.gatherFadeDelay
            )
            let group = CAAnimationGroup()
            group.animations = [move, fade]
            group.duration = max(
                move.duration,
                fade.beginTime + fade.duration
            )
            timed(group, delay)
            layer.add(group, forKey: revealKey)
        }
        for view in still {
            view.wantsLayer = true
            guard let layer = view.layer else { continue }
            let shown =
                layer.animationKeys()?.contains(revealKey) == true
                ? layer.presentation()?.opacity : nil
            let fade = spreadFade(entering: entering, from: shown, at: 0)
            timed(fade, entering ? 0 : ShelfUnfold.gatherFadeDelay)
            layer.add(fade, forKey: revealKey)
        }
    }

    /// A box's fade in or out over `spreadFade`, from `at` inside
    /// its group.
    private static func spreadFade(
        entering: Bool,
        from shown: Float?,
        at offset: TimeInterval
    ) -> CABasicAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = shown ?? (entering ? 0 : 1)
        fade.toValue = entering ? 1 : 0
        fade.duration = ShelfUnfold.spreadFade
        fade.beginTime = offset
        fade.fillMode = .both
        return fade
    }

    /// Ends a spread's motion on every view under `items`, hidden
    /// ones too: a box hidden mid-spread would show again held at
    /// its retract's end.
    @MainActor
    static func endSpread(in items: NSView) {
        for view in items.subviews {
            view.layer?.removeAnimation(forKey: revealKey)
            endSpread(in: view)
        }
    }
}

/// A view a Boxed unfold springs out of the mark as one box: a box
/// glass's host, or an item no host holds. A view that draws a box
/// declares it here, where it is declared, or it fades in place.
@MainActor protocol ShelfSpreadBox: NSView {}

extension GlassBoxHost: ShelfSpreadBox {}
extension SpaceBarItemView: ShelfSpreadBox {}
extension AppBarItemView: ShelfSpreadBox {}
