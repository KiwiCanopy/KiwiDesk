import CoreGraphics
import Foundation

/// Damped spring parameters, matching SwiftUI's
/// `.spring(response:dampingFraction:)` semantics.
public struct Spring: Sendable, Equatable {
    public let stiffness: Double
    public let damping: Double
    /// The largest step this spring may be integrated with
    /// before semi-implicit Euler stops damping and starts
    /// amplifying (#599). Precomputed alongside the two above —
    /// it is a fixed property of the spring, not a per-tick
    /// question.
    ///
    /// **The real stability condition is
    /// `k·h² + 2·c·h < 4`**, closed form `ωh < 2(√(1+ζ²) − ζ)`.
    /// Do not reason from either term alone: `k·h² < 4` is the
    /// undamped (ζ = 0) special case, and `|1 − c·h| < 1` is a
    /// necessary-but-not-sufficient Jury condition. At ζ = 0.85
    /// the combined bound (ωh < 0.925) is what binds, and the
    /// amplification factor at the two single-term bounds is
    /// 1.9 and 5.8 — both already divergent.
    ///
    /// `1/max(ω, c)` is a deliberately conservative closed form
    /// that satisfies the real condition for every ζ > 0. Its
    /// margin is **1.24×–1.81×, not 2×** (1.57× at ζ = 0.85,
    /// bottoming out at 1.24× near ζ = 0.5). That margin is
    /// load-bearing, not slack: drop it and ζ = 0.85 lands on
    /// ωh = 1.18, amplification 1.91 — #599 again.
    ///
    /// Both terms are kept because ζ below 0.5 flips which one
    /// `max` selects, and that is not hypothetical — `DeadEndBump`
    /// already ships ζ = 0.45.
    ///
    /// Concretely at ζ = 0.85: a 60 Hz tick is 16.7 ms, and the
    /// 250 ms default allows 32.8 ms — one substep, so the
    /// default is untouched. At the 50 ms floor it allows 6.6 ms
    /// and the tick splits three ways. A 120 Hz display was
    /// inside the bound across the whole range, which is why this
    /// only ever bit some machines.
    let maxStableStep: Double

    public init(
        response: Double = 0.35,
        dampingFraction: Double = 0.85
    ) {
        let omega = 2 * .pi / max(response, 0.01)
        self.stiffness = omega * omega
        self.damping = 2 * dampingFraction * omega
        self.maxStableStep = 1 / max(omega, self.damping)
    }

    /// The most real time one `step` call will integrate,
    /// however large its `dt` (#599). One 30 Hz frame, chosen to
    /// match the floor of `DisplayLinkDriver`'s own clamp
    /// (`max(nominal, 1/30)`). The two agree at 30 Hz and above,
    /// which is every display this runs on in practice; below it
    /// — a panel at a 24 Hz ProMotion floor — this truncates the
    /// driver's longer interval, so the motion runs slightly slow
    /// rather than integrating an unbounded span. That trade is
    /// deliberate: a bounded loop matters more than exact pace on
    /// a display that is already dropping frames.
    static let maxIntegratedStep = 1.0 / 30.0

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
        // Nothing meaningful to integrate, and `Int(.infinity)`
        // traps — this is a public entry point, so a garbage
        // interval must return rather than crash.
        guard dt.isFinite, dt > 0, maxStableStep.isFinite,
            maxStableStep > 0
        else { return }
        // A stall (display sleep, a wedged main actor) can hand
        // us an arbitrarily large interval. Integrating all of it
        // is neither wanted nor affordable, so cap the span
        // itself rather than the substep count: capping the count
        // would silently push `h` back above `maxStableStep` —
        // the exact amplifying regime this method exists to
        // prevent. `DisplayLinkDriver` already clamps its own
        // ticks the same way and for the same reason; this makes
        // the guarantee hold for any caller, so `step` is
        // unconditionally stable rather than stable given a
        // well-behaved driver.
        let span = min(dt, Self.maxIntegratedStep)
        let count = max(1, Int((span / maxStableStep).rounded(.up)))
        let h = span / Double(count)
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
            // A visible jump beats a permanently wedged engine.
            // With the substepping above, a finite input can no
            // longer produce a non-finite output at any `dt`, so
            // the live trigger is a non-finite START — a garbage
            // AX read — not the integrator. Check there first if
            // this ever fires. It is deliberately silent: there
            // is no log seam on a pure value type, and the engine
            // would have to poll for it. A non-finite TARGET is a
            // different matter and is refused upstream, in
            // `AnimationEngine.animate`, because this recovery
            // cannot help there — it would assign the NaN target
            // onto `current` and hand a NaN rect to AX.
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
