import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The sticky mark rides the ring's WindowServer stream (#414 QA):
/// a re-click on an ALREADY-focused window raises it above its own
/// mark but fires no AX focus event, so the mark's only re-assert is
/// the WS `.reorder` tee — which must reach a sticky window even when
/// it wears no ring. These pin that plumbing at the manager boundary.
@Suite("Sticky mark WindowServer tee")
@MainActor
struct StickyChipWindowServerTeeTests {
    private func reorder(
        _ border: BorderManager,
        _ raw: UInt32
    ) {
        border.handleSkyLightEvent(.reorder, window: WindowID(raw))
    }

    @Test("A reorder event tees even for an unbordered window")
    func reorderTeeFiresWithoutOverlay() {
        let border = BorderManager()
        var reasserted: [WindowID] = []
        border.onWindowReordered = { reasserted.append($0) }
        // Window 7 wears a mark but no ring — sticky-tracked only.
        // The old top-level overlay guard dropped this event,
        // burying the mark on a re-click; the scoped guard admits it.
        border.setStickyTracked([WindowID(7)])
        reorder(border, 7)
        #expect(reasserted == [WindowID(7)])
    }

    @Test("Unhide (followAndReorder) also tees the mark re-assert")
    func unhideTeesReassert() {
        let border = BorderManager()
        var reasserted: [WindowID] = []
        border.onWindowReordered = { reasserted.append($0) }
        border.setStickyTracked([WindowID(3)])
        border.handleSkyLightEvent(.unhide, window: WindowID(3))
        #expect(reasserted == [WindowID(3)])
    }

    @Test("A stale delivery we watch neither way is dropped")
    func staleDeliveryDropped() {
        let border = BorderManager()
        var reasserted: [WindowID] = []
        border.onWindowReordered = { reasserted.append($0) }
        // No ring, not sticky-tracked: an additive stale delivery.
        // The scoped guard must drop it — no stray tee fan-out.
        reorder(border, 7)
        #expect(reasserted.isEmpty)
    }

    @Test("markUsesWindowServerTracking follows the watch set")
    func markTrackingReflectsStickySet() {
        let border = BorderManager()
        border.setStickyTracked([WindowID(7)])
        #expect(border.stickyTracked == [WindowID(7)])
        // The predicate gates on a live stream; force it on AFTER
        // the mutation (`setStickyTracked` runs the subscription,
        // which resets `skyLightActive` while the runtime is not
        // started in unit tests).
        border.skyLightActive = true
        #expect(border.markUsesWindowServerTracking(WindowID(7)))
        // A window we do not track stays on the AX-echo path.
        #expect(!border.markUsesWindowServerTracking(WindowID(9)))
    }

    @Test("A dead stream never claims WS tracking")
    func noTrackingWhenStreamDown() {
        let border = BorderManager()
        border.setStickyTracked([WindowID(7)])
        // `skyLightActive` false — the mark must keep following AX
        // echoes, never stand down waiting on a stream that is off.
        #expect(!border.markUsesWindowServerTracking(WindowID(7)))
    }
}

/// The mark manager's WS-driven entry points are no-ops for a window
/// wearing no mark — the tee fires for every watched window (rings
/// included), so a re-assert / reposition of an unmarked id must not
/// crash or conjure a mark.
@Suite("Sticky mark manager WS entry points")
@MainActor
struct StickyChipManagerEntryPointTests {
    private func spec(_ id: UInt32) -> StickyMarkManager.Spec {
        StickyMarkManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    @Test("reassert / reposition on an unmarked window are no-ops")
    func unmarkedEntryPointsAreNoOps() {
        let manager = StickyMarkManager()
        manager.reassert(WindowID(1))
        manager.reposition(
            WindowID(1),
            windowFrame: CGRect(x: 1, y: 2, width: 3, height: 4)
        )
        #expect(manager.markedWindows.isEmpty)
    }

    @Test("follow stands down while the WindowServer tracks it")
    func followSuppressedWhenTracked() {
        let manager = StickyMarkManager()
        let moved = CGRect(x: 9, y: 9, width: 9, height: 9)
        manager.sync([spec(1)])
        manager.isWindowServerTracked = { $0 == WindowID(1) }
        // WS-tracked: the laggy AX-echo `follow` must NOT move the
        // mark (the WS `reposition` owns the frame). Without the
        // guard this call would advance `lastFrame` to `moved`.
        manager.follow(
            WindowID(1),
            windowFrame: moved,
            source: .axEcho,
            pin: nil
        )
        #expect(manager.lastFrame(WindowID(1)) != moved)
        // The unguarded WS path always advances it.
        manager.reposition(WindowID(1), windowFrame: moved)
        #expect(manager.lastFrame(WindowID(1)) == moved)
        // And untracked, the AX echo is free to move it again.
        manager.isWindowServerTracked = { _ in false }
        let axFrame = CGRect(x: 5, y: 5, width: 5, height: 5)
        manager.follow(
            WindowID(1),
            windowFrame: axFrame,
            source: .axEcho,
            pin: nil
        )
        #expect(manager.lastFrame(WindowID(1)) == axFrame)
    }

    @Test("Animation tick drives the mark even under WS tracking")
    func animationTickAppliesUnderTracking() {
        let manager = StickyMarkManager()
        let tick = CGRect(x: 40, y: 40, width: 400, height: 300)
        manager.sync([spec(1)])
        manager.isWindowServerTracked = { _ in true }
        manager.isAnimating = { _ in true }
        // Mid-animation the commanded per-tick frame leads the
        // WS bounds on slow-AX apps (#594) — it must move the
        // mark even while the stream claims the window.
        manager.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick,
            pin: nil
        )
        #expect(manager.lastFrame(WindowID(1)) == tick)
        // And with both suppressors down: the tick still
        // applies — pins the unconditional branch of `applies`.
        manager.isWindowServerTracked = { _ in false }
        manager.isAnimating = { _ in false }
        let snap = CGRect(x: 60, y: 60, width: 400, height: 300)
        manager.follow(
            WindowID(1),
            windowFrame: snap,
            source: .animationTick,
            pin: nil
        )
        #expect(manager.lastFrame(WindowID(1)) == snap)
    }

    @Test("AX echo stands down while our animation drives it")
    func axEchoSuppressedWhileAnimating() {
        let manager = StickyMarkManager()
        let echo = CGRect(x: 7, y: 7, width: 7, height: 7)
        manager.sync([spec(1)])
        // Stream down (AX fallback), but our animation owns the
        // window: the trailing echo must not rewind the mark
        // behind the per-tick frames (#594).
        manager.isWindowServerTracked = { _ in false }
        manager.isAnimating = { $0 == WindowID(1) }
        manager.follow(
            WindowID(1),
            windowFrame: echo,
            source: .axEcho,
            pin: nil
        )
        #expect(manager.lastFrame(WindowID(1)) != echo)
        // Settled: the echo path resumes.
        manager.isAnimating = { _ in false }
        manager.follow(
            WindowID(1),
            windowFrame: echo,
            source: .axEcho,
            pin: nil
        )
        #expect(manager.lastFrame(WindowID(1)) == echo)
    }
}
