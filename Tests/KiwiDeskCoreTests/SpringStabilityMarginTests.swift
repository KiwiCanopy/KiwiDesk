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
/// `ωh < 2(√(1+ζ²) − ζ)`. The numerator comes from that closed
/// form and the denominator from the spring the code actually
/// builds, so this guards the implementation rather than
/// comparing a formula with itself.
///
/// What it does **not** pin: that `step` uses `maxStableStep` at
/// all — force the substep count to 1 and this stays green, and
/// `SpringStabilityTests` / `AnimationEngineStabilityTests` are
/// what catch that — nor that the damping fractions below are
/// the ones the shipped springs use, since both are private to
/// their types.
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
        // From the SHIPPED spring, not from `response` — `init`
        // clamps that, so recomputing omega from the argument
        // would measure a spring nobody built.
        let omega = spring.stiffness.squareRoot()
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
            // The ceiling is the general reason the step cannot
            // simply be doubled at ANY damping — without it the
            // argument only covers the two shipped values.
            #expect(m < 2, "zeta \(z) margin \(m)")
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
        // The two damping fractions that ship today — the
        // engine's spring and `DeadEndBump`'s. They sit on
        // opposite sides of which term `max(ω, c)` selects, which
        // is why one value cannot stand in for both. Both are
        // private to their types, so these are literals: change a
        // shipped zeta and this suite keeps passing about the old
        // one.
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

    @Test("The step could never simply be doubled, at any zeta")
    func doublingTheStepIsNeverSafe() {
        // `maxStableStep` is `1/max(ω, c)`, not `2/max(ω, c)`, and
        // this is the property that forbids the looser form: the
        // margin never reaches 2×, so twice the shipped step is
        // always outside the real bound.
        //
        // Note what this does NOT catch, because the naming is
        // easy to over-read: if `maxStableStep` *already* shipped
        // as `2/max(ω, c)`, the measured margin halves and every
        // assertion here still passes. `marginNeverDropsBelowOne`
        // is what fails in that case — it is the test that says
        // the shipped step is inside the bound, and this one only
        // says the bound has no room for a second factor of two.
        for step in 1...400 {
            let z = Double(step) / 100
            let doubled = 2 * margin(dampingFraction: z)
            #expect(doubled > 2, "zeta \(z)")
        }
        #expect(margin(dampingFraction: 0.85) < 2)
        #expect(margin(dampingFraction: 0.45) < 2)
    }
}
