import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The ring's `follow` guards, by source (#285/#594): mid-flight
/// of OUR OWN animation the commanded per-tick frame is the
/// leading truth — the WindowServer stream and the AX echo both
/// trail it on slow-AX apps — so the tick always applies while
/// the echo stands down. Steady-state, the WS stream owns the
/// frame and the echo stands down behind it.
@Suite("Border follow animation guards")
@MainActor
struct BorderFollowAnimationTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    @Test("Animation tick drives the ring even under WS tracking")
    func animationTickAppliesUnderTracking() {
        let border = BorderManager()
        border.sync([spec(1)])
        // Force the stream live AFTER sync (`sync` re-runs the
        // subscription, which resets `skyLightActive` while the
        // private runtime is not started in unit tests).
        border.skyLightActive = true
        border.isAnimating = { _ in true }
        let tick = CGRect(x: 40, y: 40, width: 400, height: 300)
        // Pre-#594, `usesWindowServerTracking` swallowed this
        // frame and the ring trailed the motion on the laggy
        // WS/echo path, snapping only at settle.
        border.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick,
            pin: nil
        )
        #expect(border.lastFrame(WindowID(1)) == tick)
        // And with both suppressors down (a teardown snap, the
        // no-display fallback): the tick still applies — pins
        // the unconditional branch of `applies`.
        border.skyLightActive = false
        border.isAnimating = { _ in false }
        let snap = CGRect(x: 60, y: 60, width: 400, height: 300)
        border.follow(
            WindowID(1),
            windowFrame: snap,
            source: .animationTick,
            pin: nil
        )
        #expect(border.lastFrame(WindowID(1)) == snap)
    }

    @Test("AX echo stands down while our animation drives it")
    func axEchoSuppressedWhileAnimating() {
        let border = BorderManager()
        border.sync([spec(1)])
        // Stream down (AX fallback path) — the WS guard alone
        // would let this echo through; the animation guard must
        // hold it back so it can't rewind the per-tick frames.
        border.skyLightActive = false
        border.isAnimating = { $0 == WindowID(1) }
        let echo = CGRect(x: 7, y: 7, width: 7, height: 7)
        border.follow(
            WindowID(1),
            windowFrame: echo,
            source: .axEcho,
            pin: nil
        )
        #expect(border.lastFrame(WindowID(1)) != echo)
        // Settled: the echo path resumes.
        border.isAnimating = { _ in false }
        border.follow(
            WindowID(1),
            windowFrame: echo,
            source: .axEcho,
            pin: nil
        )
        #expect(border.lastFrame(WindowID(1)) == echo)
    }

    @Test("AX echo stands down while the WindowServer tracks it")
    func axEchoSuppressedWhenTracked() {
        let border = BorderManager()
        border.sync([spec(1)])
        border.skyLightActive = true
        let echo = CGRect(x: 9, y: 9, width: 9, height: 9)
        // Idle but WS-tracked: the #285 guard — a coalesced late
        // echo must not rewind the ring behind the live bounds.
        border.follow(
            WindowID(1),
            windowFrame: echo,
            source: .axEcho,
            pin: nil
        )
        #expect(border.lastFrame(WindowID(1)) != echo)
    }
}

/// The WS bounds re-read (`reconcile`) stands down mid-animation
/// (#594): the real bounds trail the commanded per-tick frame on
/// slow-AX apps, so reconciling every WS event would rewind the
/// ring behind the motion the tick just applied.
@Suite("Border reconcile animation guard")
@MainActor
struct BorderReconcileAnimationTests {
    private func spec(_ id: UInt32) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
    }

    @Test("reconcile stands down mid-animation, resumes settled")
    func reconcileGatedOnAnimation() {
        let border = BorderManager()
        border.sync([spec(1)])
        let real = CGRect(x: 20, y: 20, width: 400, height: 300)
        border.readWindowBounds = { _ in real }
        var teed: [CGRect] = []
        border.onFrameReconciled = { _, frame in
            teed.append(frame)
        }
        border.isAnimating = { _ in true }
        // Mid-animation: no bounds re-read, no sticky tee, and
        // the ring keeps the frame the tick last applied.
        #expect(border.reconcile(WindowID(1)) == false)
        #expect(border.lastFrame(WindowID(1)) != real)
        #expect(teed.isEmpty)
        // Settled: the WS bounds own the ring again.
        border.isAnimating = { _ in false }
        #expect(border.reconcile(WindowID(1)) == true)
        #expect(border.lastFrame(WindowID(1)) == real)
        #expect(teed == [real])
    }
}
