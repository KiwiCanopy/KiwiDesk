import AppKit
import QuartzCore

/// Core's one Reduce Motion gate for AppKit and Core Animation
/// motion (#1078) — the bars', and since #1391 the Monocle
/// flip's.
///
/// Every motion-starting AppKit and Core Animation call in Core
/// lives here, in one shape: a `@MainActor` wrapper reads the
/// setting and hands it to a pure decision that takes it as an
/// argument, so the decision is assertable and the read is the
/// one expression a test cannot reach. The argument, and what
/// the gate costs the drop ring, are in
/// `.claude/rules/bars.md` ▸ the bars start motion in one file.
enum BarMotion {
    /// Whether the user asked the system for less motion.
    @MainActor
    static var isReduced: Bool {
        NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
    }

    /// Item-run slide, long enough to read as one run moving and
    /// short enough not to lag a focus change.
    static let slide: TimeInterval = 0.15

    /// Runs `body` in the bars' item-slide animation group: every
    /// App Bar relayout and the Space run's glide (#1683).
    @MainActor
    static func runLayout(_ body: () -> Void) {
        let reduceMotion = isReduced
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration(
                reduceMotion: reduceMotion
            )
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            body()
        }
    }

    /// One view's part in a Space chip's strip walk (#1528 item
    /// 21), as offsets from where the view already stands: it
    /// starts `slide` away, in its own superview's coordinates,
    /// and `fade` off its opacity, and travels to where it is.
    struct WalkStep {
        let view: NSView
        var slide = CGVector.zero
        var fade: CGFloat = 0
    }

    /// Plays a strip walk on the views' layers, ADDITIVE — offsets
    /// over the model values — so a later layout pass, which
    /// writes the same final frames and resting alphas, cannot
    /// cancel it; `completion` runs once it lands — on a timer of
    /// the walk's length, since a transaction completion begun
    /// inside a layout pass never fired (device, 2026-09-29) — and
    /// at once under Reduce Motion, which plays nothing.
    @MainActor
    static func playWalk(
        _ steps: [WalkStep],
        completion: @escaping @MainActor @Sendable () -> Void
    ) {
        let reduceMotion = isReduced
        let span = walkDuration(reduceMotion: reduceMotion)
        for step in steps {
            step.view.wantsLayer = true
            guard let layer = step.view.layer else { continue }
            // A layer flipped unlike its view counts y the other way.
            let flip: CGFloat =
                (step.view.superview?.isFlipped ?? false)
                    == (layer.superlayer?.isGeometryFlipped ?? false)
                ? 1 : -1
            let offset = CGPoint(
                x: step.slide.dx,
                y: step.slide.dy * flip
            )
            if offset != .zero,
                let slide = walkAnimation(
                    keyPath: "position",
                    by: NSValue(point: offset),
                    zero: NSValue(point: .zero),
                    duration: span
                )
            {
                layer.add(slide, forKey: "kiwi.walk.slide")
            }
            if step.fade != 0,
                let fade = walkAnimation(
                    keyPath: "opacity",
                    by: Float(step.fade),
                    zero: Float(0),
                    duration: span
                )
            {
                layer.add(fade, forKey: "kiwi.walk.fade")
            }
        }
        Task { @MainActor in
            if span > 0 { try? await Task.sleep(for: .seconds(span)) }
            completion()
        }
    }

    /// A strip walk's length: a glyph walking under a disc must
    /// read as travel, so it runs longer than an item slide and
    /// just short of the plate glide, never lagging a held key.
    static let walk: TimeInterval = 0.25

    /// The walk's duration: zero under Reduce Motion, which plays
    /// no walk at all.
    static func walkDuration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : walk
    }

    /// A walk step's additive animation from `by` to `zero` over
    /// `duration`; nil for a zero one, where the view simply
    /// stands where it is.
    static func walkAnimation(
        keyPath: String,
        by: Any,
        zero: Any,
        duration: TimeInterval
    ) -> CAAnimation? {
        guard duration > 0 else { return nil }
        let step = CABasicAnimation(keyPath: keyPath)
        step.fromValue = by
        step.toValue = zero
        step.isAdditive = true
        step.duration = duration
        step.timingFunction = CAMediaTimingFunction(name: .easeOut)
        return step
    }

    /// Runs `body` in the plate glide's group: a decelerating
    /// ease with no overshoot, zero-length under Reduce Motion so
    /// the plate arrives without travelling.
    @MainActor
    static func runPlateGlide(_ body: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = plateGlideDuration(
                reduceMotion: isReduced,
                seconds: shelfGlide
            )
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.2,
                0.9,
                0.3,
                1
            )
            body()
        }
    }

    /// The plate glide's duration: zero under Reduce Motion.
    static func plateGlideDuration(
        reduceMotion: Bool,
        seconds: TimeInterval
    ) -> TimeInterval {
        reduceMotion ? 0 : seconds
    }

    /// The group's duration. Zero under Reduce Motion, so
    /// anything inside it that still reaches an animator proxy
    /// lands instead of travelling.
    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : slide
    }

    /// Moves `view` to `frame`, travelling only where `travels`
    /// allows it.
    @MainActor
    static func setFrame(
        _ view: NSView,
        to frame: CGRect,
        animated: Bool
    ) {
        if travels(
            animated,
            from: view.frame,
            to: frame,
            reduceMotion: isReduced
        ) {
            view.animator().frame = frame
        } else {
            view.frame = frame
        }
    }

    /// Whether a frame write may travel. A view still at `.zero`
    /// has never been laid out, so its first frame is an
    /// appearance rather than a move, and a write that changes
    /// nothing animates nothing.
    static func travels(
        _ animated: Bool,
        from current: CGRect,
        to frame: CGRect,
        reduceMotion: Bool
    ) -> Bool {
        guard animated, !reduceMotion else { return false }
        return current != .zero && current != frame
    }

    /// The pending-spring ring animation for a Space Bar item.
    @MainActor
    static func springSweep(
        fill: TimeInterval,
        delay: TimeInterval
    ) -> CAAnimation {
        springAnimation(
            fill: fill,
            delay: delay,
            reduceMotion: isReduced
        )
    }

    /// `strokeEnd` from empty to whole across `fill`, held empty
    /// for `delay` first; under Reduce Motion the same quiet
    /// window, then a step to whole with no travel.
    ///
    /// **Precondition:** the caller has already set the layer's
    /// own `strokeEnd` to 1, which is what the reduced shape
    /// steps to — it animates 0 to 0 and expires, so removal IS
    /// the step. A zero-duration `CABasicAnimation` would not
    /// do: Core Animation substitutes a default duration for a
    /// zero one and sweeps after all.
    static func springAnimation(
        fill: TimeInterval,
        delay: TimeInterval,
        reduceMotion: Bool
    ) -> CAAnimation {
        let sweep = CABasicAnimation(keyPath: "strokeEnd")
        sweep.fromValue = 0
        guard !reduceMotion else {
            sweep.toValue = 0
            sweep.duration = delay
            return sweep
        }
        sweep.toValue = 1
        sweep.duration = fill
        // `.both` shows the fromValue before beginTime, which is
        // what makes the quiet window quiet.
        sweep.beginTime = CACurrentMediaTime() + delay
        sweep.timingFunction = CAMediaTimingFunction(
            name: .linear
        )
        sweep.fillMode = .both
        sweep.isRemovedOnCompletion = false
        return sweep
    }

    /// The Monocle flip plate's turn (#1391): `transform.rotation`
    /// about `axis` (`"x"` or `"y"`) from `from` to `to` radians
    /// across `duration`, starting `delay` after it is added and
    /// holding `from` until then, eased both ends. Under Reduce
    /// Motion the flip never plays — `MonocleFlipPlan.decide`
    /// stands the whole transition down — so the reduced shape
    /// here is a zero-travel step, the net `springAnimation`
    /// keeps.
    static func flipTurn(
        axis: String,
        from: Double,
        to: Double,
        duration: TimeInterval,
        delay: TimeInterval,
        reduceMotion: Bool
    ) -> CAAnimation {
        let turn = CABasicAnimation(
            keyPath: "transform.rotation.\(axis)"
        )
        turn.fromValue = reduceMotion ? to : from
        turn.toValue = to
        turn.duration = duration
        turn.beginTime = CACurrentMediaTime() + delay
        turn.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut
        )
        turn.fillMode = .both
        turn.isRemovedOnCompletion = false
        return turn
    }

    /// The flip blur's morph (#1391): one layer property —
    /// `bounds`, `position` or `cornerRadius` of the blur's mask —
    /// from `from` to `to` across the turn, so the blurred cover
    /// shrinks or grows with the plate. Reduced: the zero-travel
    /// step.
    static func flipMorph(
        keyPath: String,
        from: Any,
        to: Any,
        duration: TimeInterval,
        delay: TimeInterval,
        reduceMotion: Bool
    ) -> CAAnimation {
        let morph = CABasicAnimation(keyPath: keyPath)
        morph.fromValue = reduceMotion ? to : from
        morph.toValue = to
        morph.duration = duration
        morph.beginTime = CACurrentMediaTime() + delay
        morph.timingFunction = CAMediaTimingFunction(
            name: .easeInEaseOut
        )
        morph.fillMode = .both
        morph.isRemovedOnCompletion = false
        return morph
    }

    /// A layer `opacity` fade for the flip's blur and plate
    /// (#1391), from `from` to `to` across `duration`, starting
    /// `delay` after it is added; the reduced shape is the same
    /// zero-travel step as `flipTurn`'s.
    static func flipFade(
        from: Float,
        to: Float,
        duration: TimeInterval,
        delay: TimeInterval,
        reduceMotion: Bool
    ) -> CAAnimation {
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = reduceMotion ? to : from
        fade.toValue = to
        fade.duration = duration
        fade.beginTime = CACurrentMediaTime() + delay
        fade.timingFunction = CAMediaTimingFunction(
            name: delay > 0 ? .easeIn : .easeOut
        )
        // Forwards only: a delayed fade with a backwards fill
        // would override the fade before it on the same key
        // path from the start.
        fade.fillMode = .forwards
        fade.isRemovedOnCompletion = false
        return fade
    }
}
