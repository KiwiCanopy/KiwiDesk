import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The border re-sync's timing (#596 item 2). The old heal fired
/// at `durationMS + 50`, but a spring's visual settle is ~2× its
/// response, so it landed mid-flight — too early to heal anything
/// and, being an `updateBorders()`, itself the backward snap of
/// item 3. It now rides the settle signal the animation engine
/// already emits.
@Suite("Border re-sync scheduling")
@MainActor
struct BorderResyncSchedulingTests {
    /// Puts one animation in flight without a display link, so
    /// `activeCount` is non-zero for the guards under test.
    private func startAnimation(_ core: KiwiCore) {
        core.tiler.animation.animations[DisplayID(1)] = [
            WindowID(1): FrameAnimation(
                from: CGRect(x: 0, y: 0, width: 10, height: 10),
                to: CGRect(x: 100, y: 0, width: 10, height: 10),
                spring: Spring(
                    response: 0.35,
                    dampingFraction: 0.85
                )
            )
        ]
    }

    @Test("The drop reconcile stands down while animating")
    func dropReconcileStandsDownWhileAnimating() {
        let core = makeTestCore()
        startAnimation(core)
        #expect(core.tiler.animation.activeCount == 1)
        core.scheduleBorderDropReconcile()
        // Nothing scheduled: the settle signal owns this case now.
        // Pre-#596 this armed a `durationMS + 50` timer that fired
        // mid-flight.
        #expect(core.deferred.task(for: .borderDropSettle) == nil)
    }

    @Test("An unanimated drop still gets its short event turn")
    func dropReconcileSchedulesWhenIdle() {
        let core = makeTestCore()
        #expect(core.tiler.animation.activeCount == 0)
        core.scheduleBorderDropReconcile()
        #expect(core.deferred.task(for: .borderDropSettle) != nil)
        core.deferred.cancelAll()
    }

    @Test("Settling schedules the re-sync")
    func settleSchedulesResync() {
        let core = makeTestCore()
        core.animationsDidSettle()
        #expect(core.deferred.task(for: .borderDropSettle) != nil)
        core.deferred.cancelAll()
    }

    @Test("The re-sync drops itself if a new animation started")
    func resyncDropsWhenAnimationRestarted() async {
        let core = makeTestCore()
        core.animationsDidSettle()
        // A new animation begins inside the grace: reading a
        // moving window is the mistake the grace exists to avoid.
        // Dropping loses nothing — that animation ends with its
        // own settle, which schedules this again. Proven by the
        // slot being clear afterwards: a re-arm would leave a
        // fresh pending task and poll the grace away.
        startAnimation(core)
        let pending = core.deferred.task(for: .borderDropSettle)
        await pending?.value
        #expect(core.tiler.animation.activeCount == 1)
        #expect(core.deferred.task(for: .borderDropSettle) == pending)
    }

    @Test("The grace outlasts a slow app's post-settle catch-up")
    func resyncDelayCoversTheCatchUpWindow() {
        // 100–300 ms on Electron/WebKit; 213 ms measured on device
        // for a frozen-then-resumed app. Reading sooner reads
        // bounds the app has not caught up to — the backward snap.
        #expect(KiwiCore.borderResyncDelayMS >= 300)
    }
}
