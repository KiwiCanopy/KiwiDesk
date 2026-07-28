import CoreGraphics
import Foundation

/// Which policy drives the *size* channel of an animation while a
/// window grows (issue #47). Position is always spring-interpolated
/// regardless.
public enum GrowPolicy: Sendable, Equatable {
    /// Legacy fallback (pre-#47). A growing axis holds its start
    /// size until halfway, then grows in a single frame where the
    /// ongoing slide masks the jump. One size-set lands mid-flight,
    /// so slow-AX apps (Electron/WebKit) reflow exactly once. Kept
    /// as a Lua-selectable escape hatch for an app that can't keep
    /// pace with the smooth default.
    case midSlide
    /// Shipping default (#47). A growing axis follows the spring
    /// continuously, size-sets throttled by `growRateHz` (default
    /// 120 = per-tick). Slow-AX apps reflow at that rate rather
    /// than once; lower the rate, or drop to `.midSlide`, if one
    /// falls behind.
    case throttledSmooth
}

/// Result of one size step: the size to render this frame plus the
/// carried-forward throttle accumulator.
struct GrowSizeStep {
    let size: CGSize
    /// Seconds accumulated since the last emitted size-set. The
    /// engine stores this per window and feeds it back next tick.
    let elapsed: TimeInterval
}

/// Pure size-channel policy, split per axis. A *shrinking* axis
/// always snaps to its target on the first frame (overlap must
/// clear at once); only the *growing* direction differs by policy.
/// Actor-free and unit-tested — the engine owns the per-window
/// accumulator and the rounding.
enum GrowSize {
    static func step(
        policy: GrowPolicy,
        held: CGSize,
        target: CGSize,
        spring: CGSize,
        pastHalfway: Bool,
        rateHz: Int?,
        elapsed: TimeInterval,
        dt: TimeInterval
    ) -> GrowSizeStep {
        switch policy {
        case .midSlide:
            let width =
                target.width <= held.width || pastHalfway
                ? target.width : held.width
            let height =
                target.height <= held.height || pastHalfway
                ? target.height : held.height
            return GrowSizeStep(
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
            let width =
                target.width <= held.width
                ? target.width
                : (due ? spring.width : held.width)
            let height =
                target.height <= held.height
                ? target.height
                : (due ? spring.height : held.height)
            return GrowSizeStep(
                size: CGSize(width: width, height: height),
                elapsed: due ? 0 : acc
            )
        }
    }
}
