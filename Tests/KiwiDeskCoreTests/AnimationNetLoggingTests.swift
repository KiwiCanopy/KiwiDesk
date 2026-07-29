import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Both force-settle nets are observable (#611).
///
/// The non-finite net fired silently until this issue, which
/// removed the symptom that made #599 findable and left only a
/// visible jump — the wrong trade, and a standing complaint from
/// that review. A net whose whole job is to hide a failure has to
/// say it did.
///
/// The last test is the one that matters most and is easiest to
/// forget: a seam that is declared but never wired bypasses the
/// sink in production while every unit test that sets it by hand
/// stays green. `SocketServer.onLog` sat unwired from the day it
/// was written until #622.
@Suite("Animation net logging")
@MainActor
struct AnimationNetLoggingTests {
    private let display = DisplayID(1)
    private let start = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let target = CGRect(
        x: 900,
        y: 600,
        width: 800,
        height: 700
    )

    private func drain(_ engine: AnimationEngine) -> Double {
        var steps = 0
        while engine.activeCount > 0, steps < 60 * 200 {
            engine.tick(display: display, dt: 1.0 / 60)
            steps += 1
        }
        return Double(steps) / 60
    }

    @Test("The watchdog names the window it rescued")
    func watchdogLogsOnce() {
        let engine = AnimationEngine()
        var log: [String] = []
        engine.onLog = { log.append($0) }
        engine.animations[display] = [
            WindowID(7): FrameAnimation(
                from: start,
                to: target,
                // Undamped: symplectic Euler conserves the orbit,
                // so it never converges. See
                // `AnimationSettleWatchdogTests`.
                spring: Spring(response: 0.35, dampingFraction: 0)
            )
        ]

        _ = drain(engine)

        #expect(log.count == 1, "\(log)")
        #expect(log.first?.contains("window#7") == true, "\(log)")
        #expect(log.first?.contains("did not settle") == true)
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

    @Test("The seam is actually wired to the core's log")
    func engineLogReachesTheCore() {
        // Every other assertion here sets `engine.onLog` by hand,
        // so all of them stay green if `KiwiCore+Bootstrap` stops
        // connecting it — and then both nets report past the sink
        // (`CoreLog.write`, #624) rather than into it, so nothing
        // the GUI console would show carries them. Assert the
        // wiring, not just the seam.
        let core = makeTestCore()
        var logs: [String] = []
        core.onLog = { logs.append($0) }
        core.tiler.animation.animations[display] = [
            WindowID(9): FrameAnimation(
                from: start,
                to: target,
                spring: Spring(response: 0.35, dampingFraction: 0)
            )
        ]
        _ = drain(core.tiler.animation)
        #expect(
            logs.contains { $0.contains("window#9") },
            "\(logs)"
        )
    }
}
