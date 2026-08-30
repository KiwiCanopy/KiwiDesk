import CoreGraphics
import Foundation

/// Damped spring parameters matching SwiftUI `.spring` semantics.
public struct Spring: Sendable, Equatable {
    public let stiffness: Double
    public let damping: Double
    /// Clamped response time for watchdog scaling (#611).
    public let response: Double
    /// Maximum stable integration step (#599). The REAL stability
    /// condition is `k·h² + 2·c·h < 4` (closed form
    /// `ωh < 2(√(1+ζ²) − ζ)`); never reason from either term alone
    /// — `k·h² < 4` is the undamped special case and `|1 − c·h| < 1`
    /// is necessary-but-not-sufficient. `1/max(ω, c)` is a
    /// deliberately conservative form satisfying the condition for
    /// every ζ > 0; the halving is load-bearing, not slack —
    /// `SpringStabilityMarginTests` computes the margin, so read it
    /// there rather than from a number in a comment (#614). Both
    /// terms stay because ζ below 0.5 flips which one `max` picks,
    /// and `DeadEndBump` already ships ζ = 0.45.
    let maxStableStep: Double

    public init(
        response: Double = 0.35,
        dampingFraction: Double = 0.85
    ) {
        // A non-finite response would freeze the animation (never
        // settling — the #599 wedge through another door), so it
        // degrades to the default. `dampingFraction` is
        // deliberately left unclamped: the settle watchdog covers
        // it, and clamping would delete the only way to exercise
        // `aFrozenSpringIsStillRescued`. Do not "finish the job".
        let clamped = response.isFinite ? max(response, 0.01) : 0.35
        let omega = 2 * .pi / clamped
        self.response = clamped
        self.stiffness = omega * omega
        self.damping = 2 * dampingFraction * omega
        self.maxStableStep = 1 / max(omega, self.damping)
    }

    /// Maximum time integrated in a single step (#599): one 30 Hz
    /// frame, matching `DisplayLinkDriver`'s own clamp floor —
    /// below 30 Hz motion runs slightly slow rather than
    /// integrating an unbounded span, a deliberate trade.
    static let maxIntegratedStep = 1.0 / 30.0

    /// Simulated time span integrated for `dt` (#611). Ageing by
    /// simulated rather than wall-clock time is the point: a
    /// stalled `DisplayLink` hands over one enormous `dt`, and an
    /// animation must age by what it moved
    /// (`aFrozenSpringIsStillRescued`).
    static func integratedSpan(_ dt: Double) -> Double {
        guard dt.isFinite, dt > 0 else { return 0 }
        return min(dt, maxIntegratedStep)
    }

    /// Integrates position and velocity with substepping (#599, #596).
    public func step(
        position: inout Double,
        velocity: inout Double,
        target: Double,
        dt: Double
    ) {
        guard maxStableStep.isFinite, maxStableStep > 0
        else { return }
        // Caps the SPAN, not the substep count: capping the count
        // would silently push `h` back above `maxStableStep` — the
        // exact amplifying regime this method exists to prevent.
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
