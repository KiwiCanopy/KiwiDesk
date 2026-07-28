import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #599 at the ENGINE layer — where the reported symptom actually
/// lived. `FrameAnimation` settling is one thing; the engine
/// returning to idle and emitting `onAllAnimationsEnded` is the
/// property three subsystems depend on, and the one that broke.
/// The pure-integrator suite is `SpringStabilityTests`.
@Suite("Animation engine stability")
@MainActor
struct AnimationEngineStabilityTests {
    /// The engine's own mapping (`AnimationEngine.spring`).
    private func spring(durationMS: Int) -> Spring {
        Spring(
            response: Double(durationMS) / 1000 * 1.4,
            dampingFraction: 0.85
        )
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
            #expect(engine.activeCount == 0, "\(durationMS)ms")
            #expect(ended, "\(durationMS)ms never settled")
            // The load-bearing assertion, and deliberately a
            // TICK CEILING rather than "which duration hangs".
            // Healthy is 10-15 ticks here; regressed is 589 /
            // 889 / 1710 / never. Keying on the hang alone would
            // rest on 80 ms sitting 1.1% below the instability
            // threshold — nudge the engine's `× 1.4` mapping to
            // 1.42 and every duration becomes stable or
            // net-rescued, silently disarming the whole test.
            // This bound knows nothing about that constant.
            #expect(steps < 100, "\(durationMS)ms took \(steps)")
        }
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
