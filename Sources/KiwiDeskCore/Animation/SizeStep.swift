import CoreGraphics
import Foundation

/// Which policy drives the *size* channel of an animation
/// (issue #47). Position is always spring-interpolated
/// regardless.
public enum SizePolicy: Sendable, Equatable {
    /// Legacy fallback (pre-#47). A growing axis holds its start
    /// size until halfway, then grows in a single frame where the
    /// ongoing slide masks the jump. One size-set lands mid-flight,
    /// so slow-AX apps (Electron/WebKit) reflow exactly once. Kept
    /// as a Lua-selectable escape hatch for an app that can't keep
    /// pace with the smooth default. Deaf to `SizeIntent` by
    /// definition: its whole contract is that single size-set, in
    /// whichever direction the axis moves.
    case midSlide
    /// Shipping default (#47). A growing axis follows the spring
    /// continuously — and so does a shrinking one, once the
    /// trigger vouches for it (`SizeIntent.resize`, #593).
    /// `sizeRateHz` caps the size-set rate; its default `nil`
    /// means per **display tick** (60 on a 60 Hz panel, 120 on a
    /// 120), matching the position channel. Slow-AX apps reflow at
    /// that rate rather than once; lower the rate, or drop to
    /// `.midSlide`, if one falls behind.
    case throttledSmooth
}

/// *Why* a window is animating — the one input that decides
/// whether a shrinking axis may follow the spring (#593).
///
/// The hazard the first-frame shrink snap exists for (#45) is
/// **not** "a window shrank slowly". It is an *instantly-sized*
/// window sharing the screen with a smoothly-sized one:
/// `AnimationEngine.animate(isNewWindow: true)` pre-sets a
/// newcomer's target size at its current position, so a window
/// that just opened is already full size on frame 1. A sibling
/// that vacates its room gradually is then visibly overlapped for
/// the length of the flight.
///
/// In a plain resize nothing is instantly sized: both panes run
/// the same spring, on the same clock, for the same duration, so
/// their shared edge moves in lockstep — no gap, no overlap. That
/// is why smoothing is safe there and only there.
///
/// So the discriminator is *does this batch contain any
/// instantly-sized window* — not "is this axis shrinking", and
/// not "did membership change".
///
/// **`.reflow` is the default and `.resize` is opt-in, never
/// inferred.** Forgetting to mark a new resize path costs a snap:
/// cosmetic, and exactly today's behavior. Marking a reflow path
/// by mistake costs a visible overlap. `SizeIntentRoutingTests`
/// pins which call sites may say `.resize`, and its `allowed` map
/// is that list.
public enum SizeIntent: Sendable, Equatable {
    /// Structural: window open/close, focus, swap, mode change,
    /// space switch, monitor change, profile apply, stash and
    /// restore. A shrinking axis snaps to its target on frame 1.
    case reflow
    /// A plain resize between already-placed windows — a ratio or
    /// gap edit, a mouse-resize settle — where the shared edge
    /// just slides. A shrinking axis follows the spring under the
    /// same throttle the growing one uses.
    case resize
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
        intent: SizeIntent,
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
            let acc = elapsed + dt
            let due: Bool
            if let rateHz {
                due = acc >= 1.0 / Double(max(rateHz, 1))
            } else {
                due = true
            }
            let snapShrink = intent == .reflow
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
