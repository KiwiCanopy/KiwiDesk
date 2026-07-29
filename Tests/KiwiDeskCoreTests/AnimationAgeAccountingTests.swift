import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// How the settle watchdog measures time (#611).
///
/// The bound itself is `AnimationSettleWatchdogTests`. This suite
/// exists because everything that suite drives ticks at 30, 60 or
/// 120 Hz, where the simulated-age machinery is indistinguishable
/// from `age += dt` — so the two properties that make the
/// watchdog safe in production are invisible to it. Both were
/// unguarded when first written, and both survive deletion
/// silently, which is precisely the class of rot #614 is about.
@Suite("Animation age accounting")
struct AnimationAgeAccountingTests {
    private let start = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let target = CGRect(
        x: 900,
        y: 600,
        width: 800,
        height: 700
    )

    private func wedge(
        response: Double = 0.35,
        damping: Double = 0
    ) -> FrameAnimation {
        FrameAnimation(
            from: start,
            to: target,
            spring: Spring(
                response: response,
                dampingFraction: damping
            )
        )
    }

    @Test("A stalled tick ages by what it moved, not by the stall")
    func ageIsSimulatedNotWallClock() {
        // The whole reason the accumulator is not a timestamp: a
        // `DisplayLink` that stalls (display sleep, a wedged main
        // actor) resumes with one enormous `dt`, and an animation
        // that was not running must not be aged for it. `step`
        // integrates at most `Spring.maxIntegratedStep`, so it
        // must age by at most that too.
        var animation = wedge()
        _ = animation.step(dt: 5.0)
        #expect(animation.age == Spring.maxIntegratedStep)
        // Ten minutes of display sleep is still one frame of age.
        _ = animation.step(dt: 600)
        #expect(animation.age == 2 * Spring.maxIntegratedStep)
        // And an ordinary interval ages exactly itself, so the
        // clamp is not quietly rewriting normal motion.
        var normal = wedge()
        _ = normal.step(dt: 1.0 / 60)
        #expect(normal.age == 1.0 / 60)
    }

    @Test("An interval the integrator refuses ages nothing")
    func refusedIntervalsAgeNothing() {
        // A garbage interval must not age the animation either —
        // and `.infinity` in particular would otherwise make `age`
        // infinite and force-settle a healthy animation on the
        // very next tick.
        var animation = wedge()
        for dt in [Double.infinity, .nan, 0, -1] {
            _ = animation.step(dt: dt)
        }
        #expect(animation.age == 0)
        #expect(!animation.isOverdue)
    }

    @Test("Retargeting to a new frame restarts the clock")
    func retargetResetsAge() {
        // A live make-room drag retargets its siblings for as
        // long as the user holds the mouse. Without the reset it
        // would trip the watchdog mid-drag, and a watchdog that
        // fires on healthy motion is worse than none.
        var animation = wedge()
        for _ in 0..<(60 * 4) {
            _ = animation.step(dt: 1.0 / 60)
        }
        #expect(!animation.isOverdue)
        animation.retarget(to: CGRect(x: 1, y: 2, width: 30, height: 40))
        #expect(animation.age == 0)
        // Still under the bound a full second past where the
        // un-retargeted animation would have fired.
        for _ in 0..<(60 * 2) {
            _ = animation.step(dt: 1.0 / 60)
        }
        #expect(!animation.isOverdue)
    }

    @Test("Retargeting to the same frame does not restart it")
    func unchangedRetargetKeepsAgeing() {
        // An echo/retile feedback loop re-issuing one placement is
        // the wedge the watchdog could plausibly meet in
        // production, and a reset on every `retarget` — changed
        // target or not — would blind it to exactly that. Nothing
        // about the journey changed, so nothing about its clock
        // should.
        var animation = wedge()
        for _ in 0..<(60 * 6) {
            _ = animation.step(dt: 1.0 / 60)
            animation.retarget(to: target)
        }
        #expect(animation.age > 5)
        #expect(animation.isOverdue)
    }

    @Test("A frozen spring is still rescued")
    func aFrozenSpringIsStillRescued() {
        // `Spring.init` clamps `response` but not
        // `dampingFraction`, so a caller can build a spring whose
        // `maxStableStep` is unusable. `Spring.step` then returns
        // without integrating — motionless, never settling, the
        // #599 wedge through another door (its own comment says
        // so). It is rescued only because `age` does NOT share
        // `step`'s refusal predicate, so do not unify them.
        let frozen = Spring(
            response: 0.35,
            dampingFraction: .infinity
        )
        #expect(frozen.maxStableStep == 0)
        var animation = wedge(damping: .infinity)
        for _ in 0..<(60 * 6) {
            _ = animation.step(dt: 1.0 / 60)
        }
        // Motionless, as `Spring.step` promises...
        #expect(animation.frame == start)
        // ...and aged anyway, so the watchdog can reach it.
        #expect(animation.isOverdue)
    }
}
