import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The sticky mark hears WindowServer through the one watch
/// (#414 QA, #2275): a re-click on an ALREADY-focused window raises
/// it above its own mark but fires no AX focus event, so the mark's
/// only re-assert is the `.reorder` restack — which must reach a
/// marked window even when it wears no ring. These pin that
/// plumbing at the watch boundary.
@Suite("Sticky mark WindowServer tee")
@MainActor
struct StickyChipWindowServerTeeTests {
    /// A watch whose mark consumer records its restacks.
    private func markWatch() -> (WindowServerWatch, () -> [WindowID]) {
        let watch = WindowServerWatch()
        watch.atTurnEnd = { $0() }
        var reasserted: [WindowID] = []
        watch.connect(
            .mark,
            WindowServerWatch.Hooks(restack: { reasserted.append($0) })
        )
        return (watch, { reasserted })
    }

    @Test("A reorder event reaches a marked, unbordered window")
    func reorderTeeFiresWithoutOverlay() {
        let (watch, reasserted) = markWatch()
        // Window 7 wears a mark but no ring — mark-tracked only.
        watch.request([WindowID(7)], for: .mark)
        watch.handle(.reorder, window: WindowID(7))
        #expect(reasserted() == [WindowID(7)])
    }

    @Test("Unhide (followAndReorder) also re-asserts the mark")
    func unhideTeesReassert() {
        let (watch, reasserted) = markWatch()
        watch.readWindowBounds = { _ in nil }
        watch.request([WindowID(3)], for: .mark)
        watch.handle(.unhide, window: WindowID(3))
        #expect(reasserted() == [WindowID(3)])
    }

    @Test("A stale delivery no consumer hears is dropped")
    func staleDeliveryDropped() {
        let (watch, reasserted) = markWatch()
        // Not requested by anyone: an additive stale delivery.
        watch.handle(.reorder, window: WindowID(7))
        #expect(reasserted().isEmpty)
    }

    @Test("The mark hears only its own windows, on a live stream")
    func markTrackingReflectsItsRequest() {
        let watch = WindowServerWatch()
        watch.atTurnEnd = { $0() }
        watch.override = { _ in true }
        watch.request([WindowID(7)], for: .mark)
        #expect(watch.requested(by: .mark) == [WindowID(7)])
        #expect(watch.hears(WindowID(7), as: .mark))
        // A window the mark did not ask for stays on the AX echo,
        // even one the ring hears.
        watch.request([WindowID(9)], for: .ring)
        #expect(!watch.hears(WindowID(9), as: .mark))
    }

    @Test("A dead stream never claims WS tracking")
    func noTrackingWhenStreamDown() {
        let watch = WindowServerWatch()
        watch.atTurnEnd = { $0() }
        watch.request([WindowID(7)], for: .mark)
        // Not started: the mark keeps following AX echoes, never
        // stands down waiting on a stream that is off.
        #expect(!watch.hears(WindowID(7), as: .mark))
    }
}

/// The core's own wiring of the mark to the watch (#2275): a
/// marked, unringed window hears the stream as the mark, and the
/// watch's frame and restack phases reach the core's mark.
@Suite("Sticky mark core wiring")
@MainActor
struct StickyMarkCoreWiringTests {
    @Test("the core's mark hears its own window through the watch")
    func coreMarkHearsTheWatch() {
        let core = makeTestCore()
        let window = WindowID(7)
        let frame = CGRect(x: 30, y: 40, width: 400, height: 300)
        core.windowServer.override = { _ in true }
        core.windowServer.readWindowBounds = { _ in frame }
        core.stickyMarks.sync([
            StickyMarkManager.Spec(
                window: window,
                frame: CGRect(x: 0, y: 0, width: 400, height: 300),
                glass: false
            )
        ])
        defer { core.stickyMarks.clear() }
        #expect(!core.stickyMarks.isWindowServerTracked(window))
        core.windowServer.request([window], for: .mark)
        #expect(core.stickyMarks.isWindowServerTracked(window))
        // The ring's request does not make the mark hear.
        core.windowServer.request([], for: .mark)
        core.windowServer.request([window], for: .ring)
        #expect(!core.stickyMarks.isWindowServerTracked(window))
        core.windowServer.request([], for: .ring)
        core.windowServer.request([window], for: .mark)
        core.windowServer.handle(.move, window: window)
        #expect(core.stickyMarks.lastFrame(window) == frame)
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
            frame: CGRect(x: 0, y: 0, width: 400, height: 300),
            glass: false
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
