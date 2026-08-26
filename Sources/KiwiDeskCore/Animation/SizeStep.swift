import CoreGraphics
import Foundation

/// Which policy drives the *size* channel of an animation
/// (issue #47). Position is always spring-interpolated
/// regardless.
public enum SizePolicy: String, Sendable, Equatable,
    CaseIterable
{
    /// Legacy fallback (pre-#47). A growing axis holds its start
    /// size until halfway, then grows in a single frame where the
    /// ongoing slide masks the jump. One size-set lands mid-flight,
    /// so slow-AX apps (Electron/WebKit) reflow exactly once. Kept
    /// as a Lua-selectable escape hatch for an app that can't keep
    /// pace with the smooth default. Deaf to `BatchSizing` by
    /// definition: its whole contract is that single size-set, in
    /// whichever direction the axis moves.
    case midSlide = "mid_slide"
    /// Shipping default (#47). A growing axis follows the spring
    /// continuously — and so does a shrinking one, once the
    /// pass promises it (`BatchSizing.allSpringSized`, #593).
    /// `sizeRateHz` caps the size-set rate; its default `nil`
    /// means per **display tick** (60 on a 60 Hz panel, 120 on a
    /// 120), matching the position channel. Slow-AX apps reflow at
    /// that rate rather than once; lower the rate, or drop to
    /// `.midSlide`, if one falls behind.
    case throttledSmooth = "smooth"
}

/// Result of one size step: the size to render this frame plus the
/// carried-forward throttle accumulator.
struct SizeStepResult {
    let size: CGSize
    /// Seconds accumulated since the last emitted size-set. The
    /// engine stores this per window and feeds it back next tick.
    let elapsed: TimeInterval
}

/// Pure size-channel policy, split per axis. Actor-free and
/// unit-tested — the engine owns the per-window accumulator and
/// the rounding.
enum SizeStep {
    static func step(
        policy: SizePolicy,
        sizing: BatchSizing,
        held: CGSize,
        target: CGSize,
        spring: CGSize,
        pastHalfway: Bool,
        rateHz: Int?,
        elapsed: TimeInterval,
        dt: TimeInterval
    ) -> SizeStepResult {
        switch policy {
        case .midSlide:
            let width =
                target.width <= held.width || pastHalfway
                ? target.width : held.width
            let height =
                target.height <= held.height || pastHalfway
                ? target.height : held.height
            return SizeStepResult(
                size: CGSize(width: width, height: height),
                elapsed: 0
            )
        case .throttledSmooth:
            // `nil` rate = per-tick: every call is "due", so the
            // size follows the spring each frame and the
            // accumulator stays unused (0). A rate throttles below
            // the refresh: accrue dt and emit only when the
            // interval has elapsed.
            //
            // `dt` is the display-link interval, so this counts
            // real seconds between size-sets — which is what a cap
            // in Hz should count. `Spring.step`'s substepping
            // (#599) does not change that: it partitions one
            // tick's span into several integrations, but the tick
            // is still one frame of wall clock and still emits at
            // most one size. The two do diverge after a stall,
            // where `Spring.maxIntegratedStep` truncates the span
            // to 1/30 s while this accrues the whole gap — so the
            // next frame is instantly due and carries only 33 ms
            // of travel. Harmless, and the position channel
            // behaves the same way.
            let acc = elapsed + dt
            let due: Bool
            if let rateHz {
                due = acc >= 1.0 / Double(max(rateHz, 1))
            } else {
                due = true
            }
            let snapShrink = sizing == .mayInstantSize
            return SizeStepResult(
                size: CGSize(
                    width: smoothAxis(
                        held: held.width,
                        target: target.width,
                        spring: spring.width,
                        snapShrink: snapShrink,
                        due: due
                    ),
                    height: smoothAxis(
                        held: held.height,
                        target: target.height,
                        spring: spring.height,
                        snapShrink: snapShrink,
                        due: due
                    )
                ),
                elapsed: due ? 0 : acc
            )
        }
    }

    /// One axis under `.throttledSmooth`. A growing axis always
    /// follows the spring (holding its last emitted size between
    /// throttled frames); a shrinking one takes its target on the
    /// first frame while `snapShrink` holds, and otherwise follows
    /// the spring the same way.
    ///
    /// An axis that is not moving at all lands in the shrinking
    /// arm (`target == held`) under both branches and returns that
    /// same value either way — the spring sits exactly on its
    /// target with zero velocity — so a pure move still emits no
    /// resize.
    private static func smoothAxis(
        held: CGFloat,
        target: CGFloat,
        spring: CGFloat,
        snapShrink: Bool,
        due: Bool
    ) -> CGFloat {
        if target <= held, snapShrink { return target }
        return due ? spring : held
    }
}
