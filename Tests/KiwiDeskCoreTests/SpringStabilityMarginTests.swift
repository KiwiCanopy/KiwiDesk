import Foundation
import Testing

@testable import KiwiDeskCore

/// The margin `Spring.maxStableStep` keeps over the *real*
/// stability bound (#599, pinned for #614).
///
/// `input-and-animation.md` and `Spring`'s own doc comment argue
/// from three measured ratios — a minimum of 1.24× at ζ = 0.5,
/// 1.57× at the engine's ζ = 0.85, 1.29× at `DeadEndBump`'s
/// ζ = 0.45 — and conclude from them that the shipped
/// `1/max(ω, c)` form is load-bearing. Nothing computed any of
/// them, so the whole argument for the constant that prevented
/// #599 rested on prose that could not fail.
///
/// The real condition is `k·h² + 2·c·h < 4`, i.e.
/// `ωh < 2(√(1+ζ²) − ζ)`. Everything here derives from that and
/// from the *shipped* `maxStableStep`, so it guards the
/// implementation rather than restating the closed form.
@Suite("Spring stability margin")
struct SpringStabilityMarginTests {
    /// How much larger the true bound is than the step the spring
    /// actually integrates with. Must exceed 1 for the integrator
    /// to damp rather than amplify.
    private func margin(
        dampingFraction: Double,
        response: Double = 0.35
    ) -> Double {
        let spring = Spring(
            response: response,
            dampingFraction: dampingFraction
        )
        let omega = 2 * Double.pi / response
        let z = dampingFraction
        let realBound = 2 * ((1 + z * z).squareRoot() - z) / omega
        return realBound / spring.maxStableStep
    }

    @Test("The shipped step stays inside the real bound for any ζ")
    func marginNeverDropsBelowOne() {
        // The safety property, over the whole positive range
        // rather than the two shipped values — `dampingFraction`
        // is a public initializer parameter.
        for step in 1...400 {
            let z = Double(step) / 100
            let m = margin(dampingFraction: z)
            #expect(m > 1, "zeta \(z) margin \(m)")
        }
    }

    @Test("The margin bottoms out near 1.24x, at zeta = 0.5")
    func minimumMarginIsAtHalf() {
        var worst = Double.infinity
        var worstZ = 0.0
        for step in 1...400 {
            let z = Double(step) / 100
            let m = margin(dampingFraction: z)
            if m < worst {
                worst = m
                worstZ = z
            }
        }
        // Both halves of the prose claim: the value, and *where*
        // it sits. The location is what makes ζ < 0.5 worth
        // calling out — `DeadEndBump` ships at 0.45, on the far
        // side of the minimum from the engine.
        #expect(abs(worstZ - 0.5) < 0.02, "minimum at \(worstZ)")
        #expect(worst > 1.235 && worst < 1.237, "minimum \(worst)")
    }

    @Test("Both shipped springs clear the bound by their stated margin")
    func shippedSpringMargins() {
        // The engine's spring (`AnimationEngine.spring`) and
        // `DeadEndBump`'s. They sit on opposite sides of which
        // term `max(ω, c)` selects, which is why one value cannot
        // stand in for both.
        let engine = margin(dampingFraction: 0.85)
        let bump = margin(dampingFraction: 0.45)
        #expect(engine > 1.57 && engine < 1.58, "engine \(engine)")
        #expect(bump > 1.29 && bump < 1.30, "bump \(bump)")
        // The margin is scale-free in `response`, so the whole
        // duration clamp inherits these two numbers rather than
        // needing its own sweep.
        for response in [0.07, 0.35, 1.4] {
            let m = margin(
                dampingFraction: 0.85,
                response: response
            )
            #expect(abs(m - engine) < 1e-9, "\(response) -> \(m)")
        }
    }

    @Test("Doubling the step would be divergent at the engine's zeta")
    func theHalvingIsLoadBearing() {
        // `maxStableStep` is `1/max(ω, c)`, not `2/max(ω, c)`.
        // The prose calls that halving load-bearing; this is what
        // that means — the looser form lands outside the real
        // bound at the damping the engine actually ships, which
        // is #599 again.
        #expect(margin(dampingFraction: 0.85) / 2 < 1)
        #expect(margin(dampingFraction: 0.45) / 2 < 1)
    }
}
