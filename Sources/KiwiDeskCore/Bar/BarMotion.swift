import AppKit
import QuartzCore

/// Core's one Reduce Motion gate for AppKit and Core Animation
/// motion (#1078).
///
/// Every motion-starting AppKit and Core Animation call in Core
/// lives here, in one shape: a `@MainActor` wrapper reads the
/// setting and hands it to a pure decision that takes it as an
/// argument, so the decision is assertable and the read is the
/// one expression a test cannot reach. The argument, and what
/// the gate costs the drop ring, are in
/// `.claude/rules/bars.md` ▸ the bars start motion in one file.
enum BarMotion {
    #if DEBUG
        /// Test seam over the OS read; nil reads the machine. The
        /// spelled `= nil` ends the declaration for
        /// `BarMotionSeamTests`' member walker.
        @MainActor static var reducedOverride: Bool? = nil
    #endif

    /// Whether KiwiDesk plays less motion (`ReduceMotion`, #3238).
    @MainActor
    static var isReduced: Bool {
        #if DEBUG
            if let reducedOverride { return reducedOverride }
        #endif
        return ReduceMotion.isOn
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

    /// Runs `body` in the plate glide's group — the shelf's expand:
    /// a decelerating ease with no overshoot, played under Reduce
    /// Motion too (owner ruling, 2026-10-21).
    @MainActor
    static func runPlateGlide(_ body: () -> Void) {
        NSAnimationContext.runAnimationGroup { context in
            context.duration = shelfGlide
            context.timingFunction = CAMediaTimingFunction(
                controlPoints: 0.2,
                0.9,
                0.3,
                1
            )
            expanding(body)
        }
    }

    /// Whether a write is inside the expand's group, whose frames
    /// and fades travel under Reduce Motion (owner ruling,
    /// 2026-10-21); set by `expanding` alone.
    @MainActor private(set) static var inExpand = false

    /// Runs `body` as part of the expand, nested groups included.
    @MainActor
    static func expanding(_ body: () -> Void) {
        let outer = inExpand
        inExpand = true
        defer { inExpand = outer }
        body()
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
        // The expand travels under Reduce Motion; every other bar
        // frame write keeps the gate.
        if travels(
            animated,
            from: view.frame,
            to: frame,
            reduceMotion: isReduced && !inExpand
        ) {
            view.animator().frame = frame
        } else {
            view.frame = frame
        }
    }

    /// The key of a section's bounds-origin slide (#3386).
    static let boundsSlideKey = "boundsOrigin"

    /// Moves `view` to `frame` and its bounds origin to `origin` on
    /// one gate, so its content holds still while the frame clips
    /// it (#3386): the frame travels as `setFrame` does and the
    /// origin beside it, from where its layer is drawn. The origin
    /// lands at once and its layer travels on the open group's
    /// length and curve, since AppKit's animator steps a bounds
    /// origin on the main thread, a frame behind the frame. The
    /// frame is written first, so the origin's slide is the last
    /// animation on the layer's bounds.
    @MainActor
    static func setFrameHoldingContent(
        _ view: NSView,
        to frame: CGRect,
        boundsOrigin origin: CGPoint,
        animated: Bool
    ) {
        let travel = travels(
            animated,
            from: view.frame,
            to: frame,
            reduceMotion: isReduced && !inExpand
        )
        // A write that moves nothing leaves a glide in flight to it.
        guard travel || view.frame != frame || view.bounds.origin != origin
        else { return }
        let layer = view.layer
        let drawn =
            layer?.animation(forKey: boundsSlideKey) == nil
            ? nil : layer?.presentation()?.bounds.origin
        let from = drawn ?? view.bounds.origin
        layer?.removeAnimation(forKey: boundsSlideKey)
        if travel {
            view.animator().frame = frame
        } else {
            view.frame = frame
        }
        view.setBoundsOrigin(origin)
        let context = NSAnimationContext.current
        guard let layer,
            slidesBounds(
                travel,
                from: from,
                to: origin,
                duration: context.duration
            )
        else { return }
        let slide = CABasicAnimation(keyPath: "bounds.origin")
        slide.fromValue = NSValue(point: from)
        slide.toValue = NSValue(point: origin)
        slide.duration = context.duration
        slide.timingFunction =
            context.timingFunction
            ?? CAMediaTimingFunction(name: .default)
        layer.add(slide, forKey: boundsSlideKey)
    }

    /// Whether a bounds origin slides beside its frame: only where
    /// the frame travels, the origin moves and the group has a
    /// length, since Core Animation plays a zero length as its
    /// 0.25 s default.
    static func slidesBounds(
        _ travels: Bool,
        from: CGPoint,
        to origin: CGPoint,
        duration: TimeInterval
    ) -> Bool {
        travels && from != origin && duration > 0
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
}
