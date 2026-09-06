import AppKit
import QuartzCore

/// The bars' one Reduce Motion gate (#1078).
///
/// Every motion-starting AppKit and Core Animation call under
/// `Bar/` lives here, in one shape: a `@MainActor` wrapper reads
/// the setting and hands it to a pure decision that takes it as
/// an argument, so the decision is assertable and the read is
/// the one expression a test cannot reach. The argument, and
/// what the gate costs the drop ring, are in
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

    /// Runs `body` in the animation group every App Bar relayout
    /// uses.
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
}
