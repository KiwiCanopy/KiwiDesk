import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// Boots `count` windows into the active space, switches it to
/// scrolling, and focuses `focus`. Returns the space id.
@MainActor
@discardableResult
private func makeScrollingSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: WindowID
) -> SpaceID {
    for id in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)"
                )
            )
        )
    }
    let space = core.state.workspaces.space(of: WindowID(1))!
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.state.workspaces.focus(focus, in: space)
    return space
}

/// Walls the leading (left) edge (#878), so a backward focus
/// move reveals a stationary wall-pinned target and defers its
/// raise — the suite's deferring regime. Callers settle frames
/// after this: the reveal predicate reads state frames.
@MainActor
private func wallLeftEdge(_ core: KiwiCore) {
    let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    core.tiler.visibleBounds = { _ in bounds }
    core.tiler.allScreenBounds = {
        [
            bounds,
            CGRect(x: -1920, y: 0, width: 1920, height: 1080),
        ]
    }
}

/// Settles every window at its layout target and mirrors the
/// frames into state, as the AX echoes of a finished pan would.
/// The reveal predicate compares state frames against the next
/// layout's, so fixtures settle before stepping.
@MainActor
private func settleFrames(_ core: KiwiCore) {
    core.retile(animated: false)
    for (id, frame) in core.tiler.calculatedFrames(
        state: core.state
    ) {
        core.state.apply(.windowMoved(id, frame))
    }
}

/// Puts the animation engine mid-flight deterministically: a
/// dummy animation on an unmanaged window (its frames apply to
/// no element). Returns false when no display is available —
/// callers skip, matching the screen-guard convention.
@MainActor
private func startDummyPan(_ core: KiwiCore) -> Bool {
    guard let screen = NSScreen.main else { return false }
    core.tiler.animation.animate(
        window: WindowID(999),
        on: screen,
        from: CGRect(x: 0, y: 0, width: 100, height: 100),
        to: CGRect(x: 800, y: 0, width: 100, height: 100)
    )
    return core.tiler.animation.activeCount > 0
}

/// The deferred-raise MACHINERY (#143/#878): state focus is
/// immediate, rapid commands supersede, real echoes cancel,
/// and pan-free paths raise at once. Which topology arms the
/// deferral at all is `ScrollingWallRaiseTests`.
@Suite("Scrolling deferred raise", .serialized)
@MainActor
struct ScrollingDeferredRaiseTests {
    @Test("Key-repeat keeps one pending raise: the last target")
    func keyRepeatSupersedes() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        wallLeftEdge(core)
        settleFrames(core)
        guard startDummyPan(core) else { return }
        // Backward (left) reveals targets pinned stationary at
        // the walled leading edge: each step toward an earlier
        // slot arms a raise.
        for _ in 1...3 {
            #expect(
                core.execute("focus", args: [.string("left")])
                    .isSuccess
            )
        }
        // State focus moved each step; only one raise is
        // pending, for the last target.
        #expect(core.activeSpace?.focused == WindowID(2))
        #expect(core.pendingFocusRaise == WindowID(2))
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("A real focus echo mid-pan cancels the pending raise")
    func echoCancelsPendingRaise() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        wallLeftEdge(core)
        settleFrames(core)
        guard startDummyPan(core) else { return }
        core.execute("focus", args: [.string("left")])
        #expect(core.pendingFocusRaise == WindowID(4))
        // The user clicks window 1 mid-pan: the OS raised it
        // itself; a stale raise must not steal focus back.
        core.eventLoop.onEvent(.windowFocused(WindowID(1)))
        #expect(core.pendingFocusRaise == nil)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("A stale self-echo keeps a newer pending raise (#152)")
    func selfEchoKeepsPendingRaise() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(1)
        )
        guard startDummyPan(core) else { return }
        // A newer focus step is live: state focus on 3, its raise
        // pending behind the pan.
        core.state.workspaces.focus(WindowID(3), in: space)
        core.pendingFocusRaise = WindowID(3)
        // The immediate raise of 2 from the previous step now
        // echoes back mid-pan (its AX focus notification lands).
        // The stamp rides along as `raiseWindow` writes it: the
        // echo classification is age-bounded (#687 device QA),
        // so an unstamped entry would model a raise that never
        // echoed, not this fresh one.
        core.outstandingSelfRaises = [WindowID(2)]
        core.selfRaiseStamps[WindowID(2)] = Date()
        core.eventLoop.onEvent(.windowFocused(WindowID(2)))
        // The stale self-echo neither clears the pending raise nor
        // snaps state focus back to 2.
        #expect(core.pendingFocusRaise == WindowID(3))
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(!core.outstandingSelfRaises.contains(WindowID(2)))
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("A stale echo can't revert a later forward step (#158)")
    func staleEchoAfterForwardStep() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(3)
        )
        guard startDummyPan(core) else { return }
        // A backward raise to 2 already fired (echo still in
        // flight), then a forward-immediate raise to 4 overwrote
        // focus: two self-raises outstanding at once. The single
        // slot (#152) only remembered the last, so 2's stale echo
        // was misread as a user click and stole focus back.
        core.outstandingSelfRaises = [WindowID(2), WindowID(4)]
        // Stamps as `raiseWindow` writes them — the echo
        // classification is age-bounded (#687 device QA).
        core.selfRaiseStamps[WindowID(2)] = Date()
        core.selfRaiseStamps[WindowID(4)] = Date()
        core.state.workspaces.focus(WindowID(4), in: space)
        core.eventLoop.onEvent(.windowFocused(WindowID(2)))
        #expect(core.activeSpace?.focused == WindowID(4))
        #expect(!core.outstandingSelfRaises.contains(WindowID(2)))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A real echo (not self-raised) still supersedes (#152)")
    func realEchoStillSupersedes() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(1)
        )
        guard startDummyPan(core) else { return }
        core.state.workspaces.focus(WindowID(3), in: space)
        core.pendingFocusRaise = WindowID(3)
        // No self-raise outstanding: a genuine user click on 2
        // mid-pan must still supersede the pending raise (the
        // misclassification guard — never suppress a real focus
        // change the user asked for).
        core.outstandingSelfRaises = []
        core.eventLoop.onEvent(.windowFocused(WindowID(2)))
        #expect(core.pendingFocusRaise == nil)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.activeSpace?.focused == WindowID(2))
    }

    @Test("A non-animated focus move raises immediately")
    func nonAnimatedRaisesImmediately() {
        let core = makeCore()
        core.tiler.settings.animations.onScrolling = false
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        wallLeftEdge(core)
        settleFrames(core)
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        // No pan to wait on: nothing stays pending after the
        // command returns.
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(4))
    }

    @Test("The deferred raise's own echo re-triggers nothing")
    func ownEchoIsInert() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        wallLeftEdge(core)
        settleFrames(core)
        guard startDummyPan(core) else { return }
        core.execute("focus", args: [.string("left")])
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.pendingFocusRaise == nil)
        var focusEmits = 0
        core.bus.addSink { event, _ in
            if event == .focusChange { focusEmits += 1 }
        }
        // A settled pan leaves every window at its layout
        // target (the AX echoes updated state frames); mirror
        // that so the tolerance check sees a placed row.
        for (id, frame) in core.tiler.calculatedFrames(
            state: core.state
        ) {
            core.state.apply(.windowMoved(id, frame))
        }
        // The raise's AX echo lands after the pan: it must not
        // schedule another raise or start a new pan.
        core.eventLoop.onEvent(.windowFocused(WindowID(4)))
        #expect(core.pendingFocusRaise == nil)
        #expect(core.tiler.animation.activeCount == 0)
        #expect(core.activeSpace?.focused == WindowID(4))
        #expect(focusEmits == 1)
    }

    @Test("Animated but pan-free focus raises immediately")
    func visibleTargetRaisesImmediately() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        wallLeftEdge(core)
        guard NSScreen.main != nil else { return }
        // Narrow slots so the neighbor is fully visible (the
        // 95%-width auto column would force a pan on any screen).
        core.execute("scroll.set_slot_size", args: [.number(200)])
        // Settle the row at its layout targets so the next
        // focus step needs no pan: the neighbor is already
        // fully visible, every frame is within tolerance.
        core.retile(animated: false)
        for (id, frame) in core.tiler.calculatedFrames(
            state: core.state
        ) {
            core.state.apply(.windowMoved(id, frame))
        }
        // Backward (left) toward the wall is a deferring
        // direction, but the target is already visible — no
        // pan, so the raise must fire immediately rather than
        // stay pending.
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.tiler.animation.activeCount == 0)
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(4))
    }

    @Test("Closing the focused window focuses the neighbor")
    func closeFocusedFocusesNeighbor() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 5,
            focus: WindowID(3)
        )
        // Pin the close-return history at the neighbor: which
        // window the close picks is `CloseFocusReturnTests`'
        // subject; this suite pins the raise mechanics of the
        // handoff.
        core.state.workspaces.focus(WindowID(4), in: space)
        core.state.workspaces.focus(WindowID(3), in: space)
        guard startDummyPan(core) else { return }
        // Close the focused middle window: focus lands on the
        // close-return pick — never `windows.last` (no yank to
        // the far end of the row) — and the handoff raises
        // immediately (previous == target), nothing pends.
        core.eventLoop.onEvent(
            .windowDestroyed(WindowID(3), wasMinimized: false)
        )
        #expect(core.activeSpace?.focused == WindowID(4))
        #expect(core.pendingFocusRaise == nil)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("Fire-time re-validation drops a stale target")
    func staleTargetDropsSilently() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(3))
        // A pending raise whose target no longer matches the
        // focused window (state moved on) is dropped, not
        // raised.
        core.pendingFocusRaise = WindowID(2)
        core.tiler.animation.onAllAnimationsEnded()
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(3))
    }
}
