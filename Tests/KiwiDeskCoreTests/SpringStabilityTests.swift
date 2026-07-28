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
/// **`framesStayBounded` is the real barrier here.** Settling is
/// no longer evidence of stability, because `FrameAnimation`'s
/// non-finite net force-settles a run that has already reached
/// infinity — so at the shortest durations a regressed
/// integrator still *drains*, and only the bounds check notices.
/// Do not delete or loosen it on the grounds that the settle
/// tests cover the same ground; they do not.
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
        // The common path must be untouched: substepping only
        // engages where the tick was actually unstable, so the
        // 250 ms default integrates exactly as before.
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
        var animation = FrameAnimation(
            from: CGRect(x: 0, y: 0, width: 400, height: 300),
            to: CGRect(x: 900, y: 600, width: 800, height: 700),
            spring: spring(durationMS: 50)
        )
        _ = animation.step(dt: 5.0)
        let f = animation.frame
        #expect(f.minX > -900 && f.minX < 1800)
        #expect(f.minY > -900 && f.minY < 1500)
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

    /// The reported symptom lived one layer above `FrameAnimation`:
    /// the ENGINE never returned to idle, so `onAllAnimationsEnded`
    /// stopped firing and the deferred focus raise, the z-order
    /// restore and the overlay re-sync all died with it. Every
    /// pre-existing engine drain ticks at 1/120 — precisely the
    /// rate at which this could not reproduce, which is a large
    /// part of why it was silent.
    @MainActor
    @Test("The engine drains at the shortest duration on 60 Hz")
    func engineDrainsAtShortDurationOn60Hz() {
        guard let screen = NSScreen.main,
            let display = screen.kiwiDisplay?.id
        else { return }
        // The whole unstable band, not just its floor — the
        // duration chosen matters, and 50 ms is the wrong one.
        // Measured with the substepping removed: 50 ms drains at
        // tick 590, 60 ms at 890, 70 ms at 1711, all because
        // divergence reaches infinity and `FrameAnimation`'s
        // non-finite net force-settles it. Only 80 ms diverges
        // slowly enough to stay finite and hang outright. So a
        // single-duration version of this test pinned at the
        // floor would pass against the very bug it names; the
        // sweep is what makes it fire.
        for durationMS in [50, 60, 70, 80] {
            let engine = AnimationEngine()
            var ended = false
            engine.onAllAnimationsEnded = { ended = true }
            engine.durationMS = durationMS
            engine.animate(
                window: WindowID(1),
                on: screen,
                from: CGRect(x: 0, y: 0, width: 400, height: 300),
                to: CGRect(x: 900, y: 600, width: 800, height: 700)
            )
            var steps = 0
            while engine.activeCount > 0, steps < 2000 {
                engine.tick(display: display, dt: 1.0 / 60.0)
                steps += 1
            }
            // Before the substepping this exhausted its 2000
            // ticks — over 33 s of animation — with the engine
            // still busy and the settle signal never emitted.
            #expect(engine.activeCount == 0, "\(durationMS)ms")
            #expect(ended, "\(durationMS)ms never settled")
        }
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

    @MainActor
    @Test("A non-finite target is refused, never handed to AX")
    func nonFiniteTargetIsRefused() {
        // The net in `FrameAnimation` cannot recover this case —
        // it assigns the target onto the position, so a NaN
        // target would reach AX as a NaN frame. Refused upstream.
        #expect(
            !AnimationEngine.isRenderable(
                CGRect(x: 0, y: 0, width: CGFloat.nan, height: 100)
            )
        )
        #expect(
            !AnimationEngine.isRenderable(
                CGRect(
                    x: CGFloat.infinity,
                    y: 0,
                    width: 10,
                    height: 10
                )
            )
        )
        #expect(
            AnimationEngine.isRenderable(
                CGRect(x: 1, y: 2, width: 3, height: 4)
            )
        )
        guard let screen = NSScreen.main else { return }
        let engine = AnimationEngine()
        var applied: [CGRect] = []
        engine.apply = { _, frame, _ in applied.append(frame) }
        engine.animate(
            window: WindowID(1),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 0, y: 0, width: CGFloat.nan, height: 100)
        )
        #expect(engine.activeCount == 0)
        #expect(applied.isEmpty)
    }
}
