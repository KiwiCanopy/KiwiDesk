import CoreGraphics
import Foundation

/// Damped spring parameters, matching SwiftUI's
/// `.spring(response:dampingFraction:)` semantics.
public struct Spring: Sendable, Equatable {
    public let stiffness: Double
    public let damping: Double

    public init(
        response: Double = 0.35,
        dampingFraction: Double = 0.85
    ) {
        let omega = 2 * .pi / max(response, 0.01)
        self.stiffness = omega * omega
        self.damping = 2 * dampingFraction * omega
    }

    /// The largest step this spring may be integrated with
    /// before semi-implicit Euler stops damping and starts
    /// amplifying (#599).
    ///
    /// Two conditions, and the tighter one wins. The restoring
    /// term needs `k·h² < 4`, i.e. `h < 2/ω`; the damping term
    /// needs `|1 − c·h| < 1`, i.e. `h < 2/c`. With the fixed
    /// `dampingFraction` of 0.85, `c = 1.7ω`, so damping is
    /// always the binding one here — both are kept because a
    /// future fraction below 0.5 would flip that. Halved for
    /// margin, since these are the bounds where the amplification
    /// factor reaches exactly 1 and the motion merely stops
    /// converging.
    ///
    /// Concretely: a 60 Hz tick is 16.7 ms, and at the default
    /// 250 ms duration this allows 32.8 ms — one substep, so the
    /// common path is untouched. At the 50 ms floor it allows
    /// 6.6 ms and the tick is split three ways. A 120 Hz display
    /// was already inside the bound across the whole range, which
    /// is why this only ever bit some machines.
    var maxStableStep: Double {
        let omega = stiffness.squareRoot()
        return 1 / max(omega, damping)
    }

    /// Advances one scalar by `dt` seconds (semi-implicit
    /// Euler). Mutates position and velocity in place.
    ///
    /// Substepped so the integration stays inside
    /// `maxStableStep` whatever the caller's frame interval is.
    /// Without it, a duration below ~80 ms on a 60 Hz display
    /// diverges — the position runs away to infinity, and since
    /// `FrameAnimation.step` only reports settled once it is
    /// within epsilon of the target, that animation never settles
    /// and never leaves the engine. Everything waiting on
    /// `onAllAnimationsEnded` then stops for the rest of the
    /// session: the deferred focus raise, the z-order restore and
    /// the overlay re-sync (#599, #596).
    ///
    /// Substepping is the refresh-rate-independent fix, which
    /// matters with one `DisplayLink` per monitor at mixed rates
    /// — a per-duration clamp would have to know the display.
    public func step(
        position: inout Double,
        velocity: inout Double,
        target: Double,
        dt: Double
    ) {
        // Bounded: a `dt` spike after a stall (display sleep, a
        // wedged main actor) must not turn one tick into
        // thousands of iterations. Past this the frame is so late
        // that integration accuracy is moot anyway.
        let count = min(
            16,
            max(1, Int((dt / maxStableStep).rounded(.up)))
        )
        let h = dt / Double(count)
        for _ in 0..<count {
            let acceleration =
                -stiffness * (position - target)
                - damping * velocity
            velocity += acceleration * h
            position += velocity * h
        }
    }
}

/// One in-flight window frame animation.
///
/// Four independent springs (x, y, width, height). Retargeting
/// keeps the current position and velocity, so an interrupted
/// animation redirects smoothly instead of jumping.
public struct FrameAnimation: Sendable {
    public private(set) var current: [Double]
    public private(set) var velocity: [Double]
    public private(set) var target: [Double]
    public let spring: Spring

    /// Settled when within this distance at negligible speed.
    /// Sub-pixel tails are invisible but cost real AX calls,
    /// so half a point is close enough (the final frame snaps
    /// to the exact target anyway).
    private static let epsilon = 0.5

    /// Total distance at start (or last retarget); yardstick
    /// for `pastHalfway`.
    private var initialDistance: Double

    public init(from: CGRect, to: CGRect, spring: Spring) {
        self.current = Self.vector(from)
        self.velocity = [0, 0, 0, 0]
        self.target = Self.vector(to)
        self.spring = spring
        self.initialDistance = Self.distance(
            self.current,
            self.target
        )
    }

    /// Redirects the animation to a new target mid-flight.
    public mutating func retarget(to frame: CGRect) {
        target = Self.vector(frame)
        initialDistance = Self.distance(current, target)
    }

    /// True once at least half the distance is covered. A
    /// growing window switches to its target size here, where
    /// the ongoing slide masks the single-frame size jump and
    /// the window already sits near its final origin.
    public var pastHalfway: Bool {
        Self.distance(current, target) * 2 <= initialDistance
    }

    /// Advances by `dt`; returns true when settled.
    public mutating func step(dt: Double) -> Bool {
        var settled = true
        for i in 0..<4 {
            spring.step(
                position: &current[i],
                velocity: &velocity[i],
                target: target[i],
                dt: dt
            )
            // Backstop under the substepping (#599): if a
            // component ever stops being finite it can never come
            // back — `abs(inf - target)` is never within epsilon,
            // so the animation would run forever and take the
            // whole settle signal with it. Force it home instead.
            // A visible jump beats a permanently wedged engine,
            // and this is deliberately a net rather than the fix:
            // if it ever fires, the integration is wrong.
            if !current[i].isFinite || !velocity[i].isFinite {
                current[i] = target[i]
                velocity[i] = 0
            }
            if abs(current[i] - target[i]) > Self.epsilon
                || abs(velocity[i]) > Self.epsilon
            {
                settled = false
            }
        }
        if settled {
            current = target
            velocity = [0, 0, 0, 0]
        }
        return settled
    }

    public var frame: CGRect {
        CGRect(
            x: current[0],
            y: current[1],
            width: current[2],
            height: current[3]
        )
    }

    public var targetFrame: CGRect {
        CGRect(
            x: target[0],
            y: target[1],
            width: target[2],
            height: target[3]
        )
    }

    private static func distance(
        _ a: [Double],
        _ b: [Double]
    ) -> Double {
        var sum = 0.0
        for i in 0..<4 {
            sum += (a[i] - b[i]) * (a[i] - b[i])
        }
        return sum.squareRoot()
    }

    private static func vector(_ rect: CGRect) -> [Double] {
        [
            rect.origin.x,
            rect.origin.y,
            rect.size.width,
            rect.size.height,
        ]
    }
}
