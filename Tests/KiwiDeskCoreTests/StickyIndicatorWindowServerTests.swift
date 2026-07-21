import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The sticky chip rides the ring's WindowServer stream (#414 QA):
/// a re-click on an ALREADY-focused window raises it above its own
/// chip but fires no AX focus event, so the chip's only re-assert is
/// the WS `.reorder` tee — which must reach a sticky window even when
/// it wears no ring. These pin that plumbing at the manager boundary.
@Suite("Sticky chip WindowServer tee")
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
        // Window 7 wears a chip but no ring — sticky-tracked only.
        // The old top-level overlay guard dropped this event,
        // burying the chip on a re-click; the scoped guard admits it.
        border.setStickyTracked([WindowID(7)])
        reorder(border, 7)
        #expect(reasserted == [WindowID(7)])
    }

    @Test("Unhide (followAndReorder) also tees the chip re-assert")
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

    @Test("chipUsesWindowServerTracking follows the watch set")
    func chipTrackingReflectsStickySet() {
        let border = BorderManager()
        border.setStickyTracked([WindowID(7)])
        #expect(border.stickyTracked == [WindowID(7)])
        // The predicate gates on a live stream; force it on AFTER
        // the mutation (`setStickyTracked` runs the subscription,
        // which resets `skyLightActive` while the runtime is not
        // started in unit tests).
        border.skyLightActive = true
        #expect(border.chipUsesWindowServerTracking(WindowID(7)))
        // A window we do not track stays on the AX-echo path.
        #expect(!border.chipUsesWindowServerTracking(WindowID(9)))
    }

    @Test("A dead stream never claims WS tracking")
    func noTrackingWhenStreamDown() {
        let border = BorderManager()
        border.setStickyTracked([WindowID(7)])
        // `skyLightActive` false — the chip must keep following AX
        // echoes, never stand down waiting on a stream that is off.
        #expect(!border.chipUsesWindowServerTracking(WindowID(7)))
    }
}

/// The chip manager's WS-driven entry points are no-ops for a window
/// wearing no mark — the tee fires for every watched window (rings
/// included), so a re-assert / reposition of an unmarked id must not
/// crash or conjure a chip.
@Suite("Sticky chip manager WS entry points")
@MainActor
struct StickyChipManagerEntryPointTests {
    private func spec(_ id: UInt32) -> StickyIndicatorManager.Spec {
        StickyIndicatorManager.Spec(
            window: WindowID(id),
            frame: CGRect(x: 0, y: 0, width: 400, height: 300)
        )
    }

    @Test("reassert / reposition on an unmarked window are no-ops")
    func unmarkedEntryPointsAreNoOps() {
        let manager = StickyIndicatorManager()
        manager.reassert(WindowID(1))
        manager.reposition(
            WindowID(1),
            windowFrame: CGRect(x: 1, y: 2, width: 3, height: 4)
        )
        #expect(manager.markedWindows.isEmpty)
    }

    @Test("follow stands down while the WindowServer tracks it")
    func followSuppressedWhenTracked() {
        let manager = StickyIndicatorManager()
        let moved = CGRect(x: 9, y: 9, width: 9, height: 9)
        manager.sync([spec(1)])
        manager.isWindowServerTracked = { $0 == WindowID(1) }
        // WS-tracked: the laggy AX-echo `follow` must NOT move the
        // chip (the WS `reposition` owns the frame). Without the
        // guard this call would advance `lastFrame` to `moved`.
        manager.follow(WindowID(1), windowFrame: moved)
        #expect(manager.lastFrame(WindowID(1)) != moved)
        // The unguarded WS path always advances it.
        manager.reposition(WindowID(1), windowFrame: moved)
        #expect(manager.lastFrame(WindowID(1)) == moved)
        // And untracked, the AX echo is free to move it again.
        manager.isWindowServerTracked = { _ in false }
        let axFrame = CGRect(x: 5, y: 5, width: 5, height: 5)
        manager.follow(WindowID(1), windowFrame: axFrame)
        #expect(manager.lastFrame(WindowID(1)) == axFrame)
    }
}
