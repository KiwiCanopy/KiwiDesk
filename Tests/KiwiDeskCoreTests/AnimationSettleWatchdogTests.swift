import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The settle watchdog (#611) — the net under #599's fix.
///
/// An animation that never satisfies `settled` never leaves
/// `animations`, so `activeCount` never returns to zero and
/// `notifyIfIdle` stops emitting `onAllAnimationsEnded` for the
/// rest of the session, taking the deferred focus raise, the
/// z-order restore and the overlay re-sync with it.
///
/// **The wedge here is real, not a reverted fix.** #599's
/// substepping is in the tree and that divergence is unreachable,
/// so simulating it by removing the substepping would test a
/// state the code cannot enter. Instead these drive a spring at
/// zero damping: semi-implicit Euler is symplectic, so the orbit
/// is conserved exactly — finite, bounded, stable, and never
/// within epsilon of the target at negligible speed. That is the
/// class the watchdog exists for and the one the non-finite net
/// cannot reach, and `Spring.init` is public, so a
/// Lua-supplied spring could land there.
///
/// The inverse matters as much: a watchdog that fires on healthy
/// motion is worse than none, so `healthyMotionNeverTrips` sweeps
/// the whole clamped duration range at three refresh rates.
@Suite("Animation settle watchdog")
@MainActor
struct AnimationSettleWatchdogTests {
    /// `tick` takes a display id, so a wedge fixture needs no
    /// `NSScreen` at all — nothing here inherits the host's
    /// display (tests.md).
    private let display = DisplayID(1)
    private let start = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let target = CGRect(
        x: 900,
        y: 600,
        width: 800,
        height: 700
    )

    /// An animation that genuinely cannot converge — see the
    /// suite note. `response` is the engine's own spring
    /// parameter, so the values used below are the ends of the
    /// 50–1000 ms clamp as `AnimationEngine` maps them.
    private func wedge(response: Double) -> FrameAnimation {
        FrameAnimation(
            from: start,
            to: target,
            spring: Spring(response: response, dampingFraction: 0)
        )
    }

    /// Ticks until the engine drains, returning how many seconds
    /// of motion that took. The cap is a hang guard, far past any
    /// bound under test.
    private func drain(
        _ engine: AnimationEngine,
        hz: Double = 60,
        limitSeconds: Double = 60
    ) -> Double {
        var steps = 0
        let limit = Int(limitSeconds * hz)
        while engine.activeCount > 0, steps < limit {
            engine.tick(display: display, dt: 1 / hz)
            steps += 1
        }
        return Double(steps) / hz
    }

    @Test("A wedged animation is snapped home and the signal fires")
    func wedgedAnimationReleasesTheSettleSignal() {
        let window = WindowID(7)
        let engine = AnimationEngine()
        var ended = false
        var settledOn: [WindowID: CGRect] = [:]
        var animationEnded: [WindowID] = []
        var applied: [(WindowID, CGRect, Bool)] = []
        var log: [String] = []
        engine.onAllAnimationsEnded = { ended = true }
        engine.onWindowSettled = { settledOn[$0] = $1 }
        engine.onAnimationEnd = { animationEnded.append($0) }
        engine.apply = { applied.append(($0, $1, $2)) }
        engine.onLog = { log.append($0) }
        engine.animations[display] = [window: wedge(response: 0.35)]

        let seconds = drain(engine)

        // The property three subsystems arm behind. Without the
        // watchdog this loop runs to its hang guard and every one
        // of these fails.
        #expect(engine.activeCount == 0)
        #expect(ended)
        #expect(animationEnded == [window])
        // Snapped to the exact target, not abandoned mid-flight —
        // the same recovery shape as the non-finite net, which is
        // the shape already proven to release the signal.
        #expect(settledOn[window] == target)
        #expect(applied.last?.1 == target)
        #expect(applied.last?.2 == true)
        // Observable. A net that fires silently converts the loud
        // failure that made #599 findable into a quiet one.
        #expect(log.count == 1, "\(log)")
        #expect(log.first?.contains("window#7") == true, "\(log)")
        #expect(log.first?.contains("did not settle") == true)
        // Long enough that no real motion could reach it, short
        // enough to be a blip rather than a dead session.
        #expect(seconds > 4 && seconds < 7, "fired at \(seconds)s")
    }

    @Test("Both terms of the age bound are load-bearing")
    func bothTermsOfTheBoundBind() {
        // `AnimationEngine` maps its 50–1000 ms clamp onto
        // responses of 0.07 to 1.4 s, and the bound is
        // `max(5s, 12 x response)`. Each end proves a different
        // term is live: 12 x response alone fires at 0.84 s for
        // the fastest duration, inside the lag a slow-AX app
        // legitimately shows; the 5 s floor alone fires at 5 s
        // for the slowest, against a motion that legitimately
        // takes about 2.8 s to come to rest. Drop either term
        // and one of these rows moves.
        let cases: [(response: Double, low: Double, high: Double)] = [
            // Floor binds; the multiple alone would be 0.84 s.
            (0.07, 4, 7),
            // Floor binds; the multiple alone would be 4.2 s.
            (0.35, 4, 7),
            // Multiple binds at 16.8 s; the floor alone is 5 s.
            (1.4, 15, 19),
        ]
        for row in cases {
            let engine = AnimationEngine()
            engine.animations[display] = [
                WindowID(1): wedge(response: row.response)
            ]
            let seconds = drain(engine)
            #expect(engine.activeCount == 0, "\(row.response)")
            #expect(
                seconds > row.low && seconds < row.high,
                "response \(row.response)s fired at \(seconds)s"
            )
        }
    }

    @Test("No healthy duration trips it, at 30, 60 or 120 Hz")
    func healthyMotionNeverTrips() {
        // Through `animate`, so this rides the engine's real
        // duration-to-response mapping rather than a copy of it.
        guard let screen = NSScreen.main,
            let screenDisplay = screen.kiwiDisplay?.id
        else { return }
        let durations = [
            50, 60, 70, 80, 90, 100, 150, 250, 500, 1000,
        ]
        // 30 Hz is `DisplayLinkDriver`'s own clamped worst case,
        // and so the largest interval production can hand the
        // integrator — the slowest a healthy animation can age.
        for durationMS in durations {
            for hz in [30.0, 60.0, 120.0] {
                let engine = AnimationEngine()
                var log: [String] = []
                var ended = false
                engine.onLog = { log.append($0) }
                engine.onAllAnimationsEnded = { ended = true }
                engine.durationMS = durationMS
                engine.animate(
                    window: WindowID(1),
                    on: screen,
                    from: start,
                    to: target
                )
                var steps = 0
                let limit = Int(20 * hz)
                while engine.activeCount > 0, steps < limit {
                    engine.tick(display: screenDisplay, dt: 1 / hz)
                    steps += 1
                }
                let label = "\(durationMS)ms at \(Int(hz))Hz"
                #expect(steps < limit, "\(label) never drained")
                #expect(ended, "\(label) never settled")
                // The load-bearing one: it came to rest on its
                // own, not because a net rescued it. Either net
                // reports through this seam, so an empty log is
                // the whole claim.
                #expect(log.isEmpty, "\(label) logged \(log)")
            }
        }
    }

    @Test("The non-finite net reports itself exactly once")
    func nonFiniteRescueIsLoggedOnce() {
        let engine = AnimationEngine()
        var log: [String] = []
        engine.onLog = { log.append($0) }
        // A garbage AX read is this net's live trigger now that
        // the integrator cannot produce a non-finite value from
        // finite input (#599). One component only, so the
        // animation keeps stepping for many ticks after the
        // rescue — the notice must not re-log on each of them.
        engine.animations[display] = [
            WindowID(3): FrameAnimation(
                from: CGRect(
                    x: CGFloat.infinity,
                    y: 0,
                    width: 400,
                    height: 300
                ),
                to: target,
                spring: Spring(
                    response: 0.35,
                    dampingFraction: 0.85
                )
            )
        ]

        let seconds = drain(engine)

        #expect(engine.activeCount == 0)
        #expect(log.count == 1, "\(log)")
        #expect(log.first?.contains("window#3") == true, "\(log)")
        #expect(log.first?.contains("non-finite") == true, "\(log)")
        // Rescued by the component net and then converging on its
        // own, nowhere near the watchdog's bound.
        #expect(seconds < 4, "took \(seconds)s")
    }
}
