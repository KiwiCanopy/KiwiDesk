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
    private let intervals = [(60, 1.0 / 60), (120, 1.0 / 120)]

    @Test("Every clamped duration settles at 60 and 120 Hz")
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
                    let ok =
                        f.minX > -slack && f.minX < 900 + slack
                        && f.minY > -slack && f.minY < 600 + slack
                        && f.width > -slack && f.width < 800 + slack
                        && f.height > -slack
                        && f.height < 700 + slack
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
        // The common path must be untouched: substepping only
        // engages where the tick was actually unstable, so the
        // 250 ms default integrates exactly as before.
        let s = spring(durationMS: 250)
        #expect(s.maxStableStep > 1.0 / 60)
        // And the floor genuinely needs it.
        #expect(spring(durationMS: 50).maxStableStep < 1.0 / 60)
    }

    @Test("A dt spike is bounded, not turned into a huge loop")
    func hugeDeltaIsBounded() {
        // A stall (display sleep, a wedged main actor) can hand
        // us a second-long dt; that must not become thousands of
        // iterations on the main actor.
        var animation = FrameAnimation(
            from: CGRect(x: 0, y: 0, width: 400, height: 300),
            to: CGRect(x: 900, y: 600, width: 800, height: 700),
            spring: spring(durationMS: 50)
        )
        _ = animation.step(dt: 5.0)
        #expect(animation.frame.minX.isFinite)
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
}
