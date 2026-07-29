import CoreGraphics
import Foundation

/// Damped spring parameters, matching SwiftUI's
/// `.spring(response:dampingFraction:)` semantics.
public struct Spring: Sendable, Equatable {
    public let stiffness: Double
    public let damping: Double
    /// The response this spring was built with, after `init`'s
    /// clamp. Kept rather than re-derived because the settle
    /// watchdog's bound scales with it (#611) and it is consulted
    /// once per animation per tick — and because the clamped value
    /// is the honest one: a caller that passed garbage should be
    /// aged against the spring that actually shipped.
    public let response: Double
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
    /// margin is never below **1.24×** (the minimum, at ζ = 0.5)
    /// and approaches but never reaches 2× as ζ → 0 or ζ → ∞ —
    /// **1.57×** at the engine's ζ = 0.85, **1.29×** at
    /// `DeadEndBump`'s ζ = 0.45, which sits near the tight end of
    /// the curve. So the halving is load-bearing, not slack:
    /// drop it and ζ = 0.85 lands on ωh = 1.18, amplification
    /// 1.91 — #599 again.
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
        // A non-finite `response` would propagate through `max`
        // into `maxStableStep`, and `step` guards against that by
        // returning — which would freeze the animation instead of
        // crashing it: never settling, never leaving the engine,
        // the #599 wedge through another door. Degrade to the
        // default instead. `init` is public, so this is reachable.
        let clamped = response.isFinite ? max(response, 0.01) : 0.35
        let omega = 2 * .pi / clamped
        self.response = clamped
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

    /// The real time one `step` call actually integrates for a
    /// caller's `dt` — the interval itself under the cap above,
    /// and **zero** for an interval `step` refuses outright.
    ///
    /// Extracted so the settle watchdog can age an animation by
    /// the same measure (#611). Ageing by simulated rather than
    /// wall-clock time is the point: a `DisplayLink` that stalls
    /// hands over one enormous `dt`, and an animation must age by
    /// what it moved, not by how long the display slept.
    static func integratedSpan(_ dt: Double) -> Double {
        guard dt.isFinite, dt > 0 else { return 0 }
        return min(dt, maxIntegratedStep)
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
        // Nothing meaningful to integrate, and `Int(.infinity)`
        // traps — this is a public entry point, so a garbage
        // interval must return rather than crash.
        guard maxStableStep.isFinite, maxStableStep > 0
        else { return }
        // A stall (display sleep, a wedged main actor) can hand
        // us an arbitrarily large interval. Integrating all of it
        // is neither wanted nor affordable, so `integratedSpan`
        // caps the span itself rather than the substep count:
        // capping the count would silently push `h` back above
        // `maxStableStep` — the exact amplifying regime this
        // method exists to prevent. `DisplayLinkDriver` already
        // clamps its own ticks the same way and for the same
        // reason; this makes the guarantee hold for any caller, so
        // `step` is unconditionally stable rather than stable
        // given a well-behaved driver.
        let span = Self.integratedSpan(dt)
        guard span > 0 else { return }
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
