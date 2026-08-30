import CoreGraphics
import Foundation

/// Damped spring parameters matching SwiftUI `.spring` semantics.
public struct Spring: Sendable, Equatable {
    public let stiffness: Double
    public let damping: Double
    /// Clamped response time for watchdog scaling (#611).
    public let response: Double
    /// Maximum stable integration step (`1/max(ω, c)`, #599;
    /// `SpringStabilityMarginTests`, #614).
    let maxStableStep: Double

    public init(
        response: Double = 0.35,
        dampingFraction: Double = 0.85
    ) {
        let clamped = response.isFinite ? max(response, 0.01) : 0.35
        let omega = 2 * .pi / clamped
        self.response = clamped
        self.stiffness = omega * omega
        self.damping = 2 * dampingFraction * omega
        self.maxStableStep = 1 / max(omega, self.damping)
    }

    /// Maximum time integrated in a single step (1/30s, #599).
    static let maxIntegratedStep = 1.0 / 30.0

    /// Simulated time span integrated for `dt` (#611;
    /// `aFrozenSpringIsStillRescued`).
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
