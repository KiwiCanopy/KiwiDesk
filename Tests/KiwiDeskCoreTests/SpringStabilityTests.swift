import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The integrator's stability across the whole clamped duration
/// range (#599). Semi-implicit Euler amplifies instead of damping
/// once the step is large relative to the spring's response, and
/// a 60 Hz tick was past that bound for every duration below
/// ~80 ms — the four bottom clicks of the GUI stepper. The
/// failure was silent because nothing drove the clock at the fast
/// end: a diverged animation never satisfies `settled`, so it
/// never leaves the engine and the settle signal dies with it.
///
/// The engine-layer half is `AnimationEngineStabilityTests`.
///
/// **Two tests here are the real barriers, and neither is the
/// obvious one.** Settling stopped being evidence of stability
/// once `FrameAnimation`'s non-finite net could force-settle a
/// run that already reached infinity, so at the shortest
/// durations a regressed integrator still *drains*.
/// `framesStayBounded` notices anyway. `deadEndBumpSpringIsStable`
/// is the more durable of the two: it builds its spring
/// literally, so unlike everything else in this file it does not
/// depend on the engine's `× 1.4` mapping, the 50–1000 clamp or
/// ζ = 0.85 — a change to any of those can disarm the sweeps
/// without disarming it. Do not demote either to "coverage".
@Suite("Spring integrator stability")
struct SpringStabilityTests {
    /// The engine's own mapping (`AnimationEngine.spring`).
    private func spring(durationMS: Int) -> Spring {
        Spring(
            response: Double(durationMS) / 1000 * 1.4,
            dampingFraction: 0.85
        )
    }

    /// Every duration the clamp admits, at both common refresh
    /// rates. 60 Hz is the one that used to diverge.
    private let durations = [
        50, 60, 70, 80, 90, 100, 150, 250, 500, 1000,
    ]
    // 60 Hz is the rate that diverged; 120 Hz never did. 30 Hz
    // is the driver's own worst case — `DisplayLinkDriver`
    // clamps a stalled tick to `max(nominal, 1/30)`, so this is
    // the largest interval production can hand the integrator,
    // and the largest substep count it can produce.
    private let intervals = [
        (30, 1.0 / 30), (60, 1.0 / 60), (120, 1.0 / 120),
    ]

    @Test("Every clamped duration settles at 30, 60 and 120 Hz")
    func everyDurationSettles() {
        for durationMS in durations {
            for (hz, dt) in intervals {
                var animation = FrameAnimation(
                    from: CGRect(x: 0, y: 0, width: 400, height: 300),
                    to: CGRect(x: 900, y: 600, width: 800, height: 700),
                    spring: spring(durationMS: durationMS)
                )
                // Ten seconds of ticks is far past any settle in
                // the range; before the fix, 50 ms at 60 Hz was
                // still running (at infinity) well beyond it.
                var ticks = 0
                let limit = Int(10 / dt)
                while ticks < limit, !animation.step(dt: dt) {
                    ticks += 1
                }
                #expect(
                    ticks < limit,
                    "\(durationMS)ms at \(hz)Hz never settled"
                )
            }
        }
    }

    @Test("No emitted frame escapes the motion's own bounds")
    func framesStayBounded() {
        let from = CGRect(x: 0, y: 0, width: 400, height: 300)
        let to = CGRect(x: 900, y: 600, width: 800, height: 700)
        // A damped spring overshoots, so the assertion is the
        // union of start and target grown by the travel distance
        // — generous, and still orders of magnitude short of the
        // millions-of-points excursions divergence produced.
        let slack = 900.0
        let maxX = to.maxX + slack
        let maxY = to.maxY + slack
        for durationMS in durations {
            for (hz, dt) in intervals {
                var animation = FrameAnimation(
                    from: from,
                    to: to,
                    spring: spring(durationMS: durationMS)
                )
                var ticks = 0
                let limit = Int(10 / dt)
                while ticks < limit, !animation.step(dt: dt) {
                    ticks += 1
                    let f = animation.frame
                    // Derived from the fixture, not restated —
                    // and sizes must stay positive, which a
                    // symmetric slack would have let through.
                    let ok =
                        f.minX > -slack && f.minX < maxX
                        && f.minY > -slack && f.minY < maxY
                        && f.width > 0 && f.width < maxX
                        && f.height > 0 && f.height < maxY
                    #expect(
                        ok,
                        "\(durationMS)ms at \(hz)Hz left bounds: \(f)"
                    )
                    if !ok { break }
                }
            }
        }
    }

    @Test("The default duration takes no substep at 60 Hz")
    func defaultDurationIsUnsubstepped() {
        // The 250 ms default must integrate exactly as before.
        let s = spring(durationMS: 250)
        #expect(s.maxStableStep > 1.0 / 60)
        // And the floor genuinely needs it.
        #expect(spring(durationMS: 50).maxStableStep < 1.0 / 60)
        // The threshold alone would stay green if the substep
        // count stopped rounding to 1, so pin the output: with
        // one substep the result must be bit-identical to a
        // single raw Euler step.
        var p1 = 0.0
        var v1 = 0.0
        s.step(position: &p1, velocity: &v1, target: 100, dt: 1.0 / 60)
        var p2 = 0.0
        var v2 = 0.0
        let h = 1.0 / 60
        v2 += (-s.stiffness * (p2 - 100) - s.damping * v2) * h
        p2 += v2 * h
        #expect(p1 == p2)
        #expect(v1 == v2)
        // Substepping engages below ~127 ms, not at the ~81 ms
        // instability threshold — so 90-120 ms was already stable
        // and now integrates differently (more accurately). The
        // default is untouched; "only the unstable band changed"
        // would be wrong.
        #expect(spring(durationMS: 120).maxStableStep < 1.0 / 60)
    }

    @Test("A dt spike stays inside the motion, not just finite")
    func hugeDeltaIsBounded() {
        // A stall (display sleep, a wedged main actor) can hand
        // us a second-long dt. Capping the SPAN keeps the step
        // stable; capping the substep count instead would have
        // pushed `h` back above the bound, leaving a state that
        // is astronomically large yet finite — which an
        // `isFinite` assertion would happily pass.
        let to = CGRect(x: 900, y: 600, width: 800, height: 700)
        let slack = 900.0
        var animation = FrameAnimation(
            from: CGRect(x: 0, y: 0, width: 400, height: 300),
            to: to,
            spring: spring(durationMS: 50)
        )
        _ = animation.step(dt: 5.0)
        let f = animation.frame
        #expect(f.minX > -slack && f.minX < to.maxX + slack)
        #expect(f.minY > -slack && f.minY < to.maxY + slack)
    }

    @Test("A garbage interval returns instead of trapping")
    func nonFiniteDeltaIsRefused() {
        // `step` is public API. The substep count goes through
        // `Int(...)`, which TRAPS on a non-finite quotient — so a
        // guard against a hang must not introduce a crash.
        var animation = FrameAnimation(
            from: CGRect(x: 0, y: 0, width: 400, height: 300),
            to: CGRect(x: 900, y: 600, width: 800, height: 700),
            spring: spring(durationMS: 250)
        )
        _ = animation.step(dt: .infinity)
        _ = animation.step(dt: .nan)
        _ = animation.step(dt: 0)
        _ = animation.step(dt: -1)
        #expect(animation.frame.minX == 0)
    }

    @Test("A non-finite component is forced home, not left to run")
    func nonFiniteIsForcedHome() {
        // The net under the substepping: if anything ever escapes
        // to infinity it can never return, because
        // `abs(inf - target)` is never within epsilon — the
        // animation would run forever and take the settle signal
        // with it.
        let target = CGRect(x: 10, y: 20, width: 30, height: 40)
        var animation = FrameAnimation(
            from: CGRect(
                x: CGFloat.infinity,
                y: 0,
                width: 30,
                height: 40
            ),
            to: target,
            spring: spring(durationMS: 250)
        )
        _ = animation.step(dt: 1.0 / 60)
        #expect(animation.frame.minX.isFinite)
    }

    @Test("The other shipped spring is inside the bound too")
    func deadEndBumpSpringIsStable() {
        // `DeadEndBump` builds its own spring at zeta 0.45 and is
        // driven by its own per-monitor DisplayLink — so it is a
        // second, independent consumer of `Spring.step`, and the
        // one where `max(omega, damping)` actually selects the
        // restoring term rather than the damping one. Below 0.5
        // is not a hypothetical future value; it ships today.
        let bump = Spring(response: 0.15, dampingFraction: 0.45)
        #expect(bump.maxStableStep > 1.0 / 60)
        var position = 0.0
        var velocity = 0.0
        for _ in 0..<600 {
            bump.step(
                position: &position,
                velocity: &velocity,
                target: 100,
                dt: 1.0 / 30
            )
            #expect(position.isFinite)
            #expect(position > -1000 && position < 1000)
        }
        #expect(abs(position - 100) < 1)
    }
}
