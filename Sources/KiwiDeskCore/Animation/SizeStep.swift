import CoreGraphics
import Foundation

/// Policy driving animation size channel updates (#47, #593).
public enum SizePolicy: String, Sendable, Equatable,
    CaseIterable
{
    /// Single size-set at halfway point for slow-AX apps — a
    /// Lua-selectable escape hatch, and deaf to `BatchSizing` by
    /// definition: its whole contract is that one size-set.
    case midSlide = "mid_slide"
    /// Continuous spring-interpolated sizing throttled by rateHz
    /// (#47, #593). `nil` rate means per display TICK (60 or
    /// 120 Hz), matching the position channel.
    case throttledSmooth = "smooth"
}

/// Result of one size step containing calculated size and throttle
/// accumulator.
struct SizeStepResult {
    let size: CGSize
    let elapsed: TimeInterval
}

/// Pure size-channel calculation per axis (#47, #599).
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

    /// Single axis calculation under `.throttledSmooth`
    /// (`Spring.step`). An axis not moving at all lands in the
    /// shrinking arm under both branches and returns the same
    /// value — a pure move still emits no resize.
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
