import AppKit
import QuartzCore

/// The bars' one Reduce Motion gate (#1078).
///
/// Core draws the bars through AppKit and Core Animation, which
/// `ReduceMotionGateTests` cannot reach, so the obligation
/// `.claude/rules/gui.md` states — a Core animation is gated at
/// its own site or it is ungated — is met by keeping every
/// motion-starting call under `Bar/` in this file. What holds
/// that is a pair: `BarMotionTests` on the decisions below, and
/// `BarMotionSeamTests` on the routing, since a decision proved
/// correct in a file nothing calls gates nothing.
///
/// The gate drops the MOTION, never the affordance: items land
/// in their new frames rather than sliding to them, and the
/// pending-spring ring marks its item instead of sweeping it.
enum BarMotion {
    /// Whether the user asked the system for less motion. The
    /// one read, and the only part of this file a test cannot
    /// reach: every decision below takes the answer as an
    /// argument instead, so what is left here is the expression
    /// that fetches it.
    @MainActor
    static var isReduced: Bool {
        NSWorkspace.shared
            .accessibilityDisplayShouldReduceMotion
    }

    /// Item-run slide, long enough to read as one run moving and
    /// short enough not to lag a focus change.
    static let slide: TimeInterval = 0.15

    /// The animation group every App Bar relayout runs in. Zero
    /// under Reduce Motion, so anything inside it that still
    /// reaches an animator proxy lands instead of travelling.
    @MainActor
    static func runLayout(_ body: () -> Void) {
        let reduceMotion = isReduced
        NSAnimationContext.runAnimationGroup { context in
            context.duration = duration(reduceMotion: reduceMotion)
            context.timingFunction = CAMediaTimingFunction(
                name: .easeOut
            )
            body()
        }
    }

    /// The group's duration.
    static func duration(reduceMotion: Bool) -> TimeInterval {
        reduceMotion ? 0 : slide
    }

    /// Moves `view` to `frame`, travelling only when the layout
    /// asked for it and the user has not asked for less.
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

    /// The pending-spring ring on a Space Bar item: `strokeEnd`
    /// from empty to whole across `fill`, held empty for `delay`
    /// first so a quick flick-to-relocate never flashes a
    /// loading ring (#372).
    ///
    /// Under Reduce Motion the ring MARKS instead of sweeping —
    /// the same trade `WaitingDot` makes. It keeps the quiet
    /// window, which is a delay and not motion, then appears
    /// whole for the rest of the dwell: the item still says "a
    /// hold here will spring", and only the countdown is lost.
    ///
    /// The caller has already set the layer's own `strokeEnd` to
    /// 1, so the mark is a flat 0-to-0 animation that expires:
    /// removing it IS the step, and nothing is interpolated
    /// anywhere. A `CABasicAnimation` of duration zero would not
    /// do — Core Animation substitutes a default duration for a
    /// zero one and sweeps after all.
    static func springSweep(
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
