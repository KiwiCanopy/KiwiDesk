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
/// cannot reach, and `Spring.init` is public, so a Lua-supplied
/// spring could land there.
///
/// The inverse matters as much: a watchdog that fires on healthy
/// motion is worse than none, so `healthyMotionNeverTrips` sweeps
/// the whole clamped duration range at three refresh rates and
/// `slowestHealthySettleIsPinned` records the margin the bound
/// is chosen against. How `age` is measured is
/// `AnimationAgeAccountingTests`; that both nets are observable
/// is `AnimationNetLoggingTests`.
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
        limitSeconds: Double = 200
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
        var log: [String] = []
        engine.onLog = { log.append($0) }
        var ended = false
        var settledOn: [WindowID: CGRect] = [:]
        var animationEnded: [WindowID] = []
        var applied: [(WindowID, CGRect, Bool)] = []
        engine.onAllAnimationsEnded = { ended = true }
        engine.onWindowSettled = { settledOn[$0] = $1 }
        engine.onAnimationEnd = { animationEnded.append($0) }
        engine.apply = { applied.append(($0, $1, $2)) }
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
        // Long enough that no real motion could reach it, short
        // enough to be a blip rather than a dead session.
        #expect(seconds > 4 && seconds < 7, "fired at \(seconds)s")
        // The rescue is only useful if it says it happened —
        // input-and-animation.md writes that as an obligation
        // ("report both nets through `AnimationEngine.onLog`"),
        // and every other assertion here would hold on a silent
        // watchdog.
        #expect(log.count == 1, "\(log)")
        #expect(log.first?.contains("window#7") == true, "\(log)")
    }

    @Test("Both terms of the age bound are load-bearing")
    func bothTermsOfTheBoundBind() {
        // `AnimationEngine` maps its 50-1000 ms clamp onto
        // responses of 0.07 to 1.4 s, and the bound is
        // `max(5s, 12 x response)`. Each row is placed so that
        // deleting ONE term moves it out of its window — the 0.35
        // case is not a third data point, it is the default
        // duration, and its low bound is set at 4.5 so that the
        // floor's removal (which would fire it at 4.2 s) fails
        // here rather than passing on a coincidence.
        let cases: [(response: Double, low: Double, high: Double)] = [
            // Floor binds; the multiple alone would be 0.84 s.
            (0.07, 4, 7),
            // Floor binds; the multiple alone would be 4.2 s.
            (0.35, 4.5, 7),
            // Multiple binds at 16.8 s; the floor alone is 5 s.
            (1.4, 15, 19),
        ]
        for row in cases {
            let engine = AnimationEngine()
            var log: [String] = []
            engine.onLog = { log.append($0) }
            engine.animations[display] = [
                WindowID(1): wedge(response: row.response)
            ]
            let seconds = drain(engine)
            #expect(engine.activeCount == 0, "\(row.response)")
            #expect(
                seconds > row.low && seconds < row.high,
                "response \(row.response)s fired at \(seconds)s"
            )
            #expect(log.count == 1, "\(row.response): \(log)")
        }
    }

    @Test("A spring cannot scale itself out of the watchdog")
    func hugeResponseStillTrips() {
        // The multiple term scales with a caller-supplied
        // response and `Spring.init` clamps it only from below,
        // so without a ceiling this buys a 139-day bound — a
        // spring opting out of the one net that covers it. Not
        // reachable through `durationMS` today; the suite header's
        // motivating case is a spring built directly, which is
        // exactly what this is.
        let engine = AnimationEngine()
        var log: [String] = []
        engine.onLog = { log.append($0) }
        engine.animations[display] = [
            WindowID(1): wedge(response: 1_000_000)
        ]
        let seconds = drain(engine)
        #expect(engine.activeCount == 0)
        #expect(seconds < 70, "fired at \(seconds)s")
        #expect(log.count == 1, "\(log)")
    }

    @Test("No healthy duration trips it, at 30, 60 or 120 Hz")
    func healthyMotionNeverTrips() {
        // Through `animate`, so this rides the engine's real
        // duration-to-response mapping rather than a copy of it.
        guard let screen = NSScreen.main,
            let screenDisplay = screen.kiwiDisplay?.id
        else { return }
        for durationMS in Self.durations {
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

    @Test("The bound's margin over healthy motion still holds")
    func slowestHealthySettleIsPinned() {
        // The prose in `FrameAnimation` and the rule file argues
        // from RATIOS — which term is thin at which end. A number
        // that is restated rather than computed drifts (#511), and
        // a ratio restated in three places drifts three ways, so
        // the ratios are asserted here and both prose sites cite
        // this test instead of the digits.
        //
        // Travel is deliberately wider than the fixture above: a
        // two-display move is the slowest real settle, and it is
        // what sets every margin below. Deterministic and
        // host-independent (no `NSScreen`, pure float).
        let far = CGRect(x: 15360, y: 2160, width: 1920, height: 1080)
        var floorOnly: [Int: Double] = [:]
        var multipleOnly: [Int: Double] = [:]
        for durationMS in [50, 1000] {
            let response = Double(durationMS) / 1000 * 1.4
            let spring = Spring(
                response: response,
                dampingFraction: 0.85
            )
            var worst = 0.0
            for hz in [30.0, 60.0, 120.0] {
                var animation = FrameAnimation(
                    from: start,
                    to: far,
                    spring: spring
                )
                var ticks = 0
                while ticks < Int(20 * hz),
                    !animation.step(dt: 1 / hz)
                {
                    ticks += 1
                }
                worst = max(worst, Double(ticks) / hz)
            }
            floorOnly[durationMS] = 5 / worst
            multipleOnly[durationMS] = 12 * response / worst
            // The safety property: the SHIPPED bound — the larger
            // of the two terms — clears the slowest healthy settle
            // by a wide margin at both ends.
            let shipped = max(5, 12 * response) / worst
            #expect(shipped > 5, "\(durationMS)ms margin \(shipped)")
        }
        // And the argument for keeping both terms, as the
        // comparison it actually is. Each term is the thin one at
        // the end the other covers, so dropping either halves the
        // worst-case margin even though neither alone would fire
        // on today's measurements. That "neither alone fires" is
        // why this is a margin argument and not a correctness one
        // — say so rather than claiming a bare term is unsafe.
        #expect(multipleOnly[50] ?? 0 < 5, "\(multipleOnly)")
        #expect(floorOnly[50] ?? 0 > 20, "\(floorOnly)")
        #expect(floorOnly[1000] ?? 0 < 2, "\(floorOnly)")
        #expect(multipleOnly[1000] ?? 0 > 5, "\(multipleOnly)")
    }

    /// Every duration the 50–1000 clamp admits.
    private static let durations = [
        50, 60, 70, 80, 90, 100, 150, 250, 500, 1000,
    ]
}
