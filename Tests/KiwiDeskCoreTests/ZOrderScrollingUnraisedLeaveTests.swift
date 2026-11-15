import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2985, the fast-step half: a step that lands inside the last
/// step's pan replaces that step's deferred raise, so the window it
/// leaves was never raised and is no front window the step can pass
/// over. Two-up rows, where a step that pans shows only the window
/// left beside the focus, so the window left alone decides the arm.
/// Same fixture shape as `ZOrderScrollingArmTests`.
@Suite(
    "A step past an unraised window arms a restore (#2985)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ZOrderScrollingUnraisedLeaveTests {
    /// Six tiles in 700 pt slots under `follow`, focus seated on
    /// tile 4 at the right, so 3 and 4 show and a step to 5 pans.
    private func makeCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-scroll-unraised-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for id in 1...6 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = try #require(
            core.state.workspaces.space(of: WindowID(1))
        )
        #expect(
            core.execute(
                "set_mode",
                args: [.string(space.raw), .string("scrolling")]
            ).isSuccess
        )
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(700)]
            ).isSuccess
        )
        #expect(
            core.execute(
                "scroll.set_anchor",
                args: [.string("follow")]
            ).isSuccess
        )
        // From the row's start, so `follow` seats 4 at the right.
        for id in [1, 4] {
            core.focusWindow(WindowID(UInt32(id)), warp: false)
            core.tiler.animation.cancelAll(snapToTargets: true)
        }
        core.pendingZOrderRestore = false
        core.pendingFocusRaise = nil
        core.zOrderRaiseEchoes = [:]
        core.selfRaiseStamps = [:]
        for id in 1...6 {
            core.tiler.placements.forget(WindowID(UInt32(id)))
        }
        return core
    }

    /// Holds the step's pan, its raise and its restore pending.
    private func startDummyPan(_ core: KiwiCore) throws {
        let screen = try #require(NSScreen.main)
        core.tiler.animation.animate(
            window: WindowID(999),
            on: screen,
            from: CGRect(x: 0, y: 0, width: 100, height: 100),
            to: CGRect(x: 800, y: 0, width: 100, height: 100)
        )
        #expect(core.tiler.animation.activeCount > 0)
    }

    private func stepTo5(_ core: KiwiCore, leftUnraised: Bool) throws {
        try startDummyPan(core)
        core.pendingFocusRaise = leftUnraised ? WindowID(4) : nil
        let before = core.activeSpace?.scrollRest?.offset
        core.focusWindow(WindowID(5), warp: false)
        #expect(core.activeSpace?.scrollRest?.offset != before)
    }

    @Test("A step past a window whose raise landed arms nothing")
    func raisedLeaveArmsNothing() throws {
        let core = try makeCore()
        try stepTo5(core, leftUnraised: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A step past a window still owed its raise arms")
    func unraisedLeaveArms() throws {
        let core = try makeCore()
        try stepTo5(core, leftUnraised: true)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A step back onto the window left whose frame moves raises it
    /// at once with the floats, which pays the debt the step left.
    @Test("A step back that raises the window pays its debt")
    func raisePaysTheDebt() throws {
        let core = try makeCore()
        let space = try #require(core.activeSpace)
        core.state.workspaces.focus(WindowID(3), in: space.id)
        try startDummyPan(core)
        core.pendingFocusRaise = WindowID(4)
        core.focusWindow(WindowID(4), warp: false)
        #expect(core.pendingFocusRaise == nil)
        core.focusWindow(WindowID(5), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A re-assert of the same window lifts no floats, so the debt
    /// stands for the settle to pay with them (#2284).
    @Test("A re-assert of the window keeps its debt")
    func reassertKeepsTheDebt() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.pendingFocusRaise = WindowID(4)
        core.focusWindow(WindowID(4), warp: false)
        #expect(core.pendingFocusRaise == WindowID(4))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The device sequence: the second step lands inside the first
    /// one's pan, so the first step's raise never ran. Echoes landed,
    /// so 3, which stays where it is, takes the deferred raise.
    @Test("Two steps inside one pan arm")
    func chainedStepsArm() throws {
        let core = try makeCore()
        for (id, frame) in core.tiler.placedFrames(state: core.state) {
            core.state.apply(.windowResized(id, frame))
        }
        try startDummyPan(core)
        core.focusWindow(WindowID(3), warp: false)
        #expect(core.pendingFocusRaise == WindowID(3))
        #expect(!core.pendingZOrderRestore)
        core.focusWindow(WindowID(2), warp: false)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// Where `target` lands when the chain steps 4 → 3 → `target`,
    /// read off a probe core of the same shape.
    private func landing(of target: UInt32) throws -> CGRect {
        let probe = try makeCore()
        probe.focusWindow(WindowID(3), warp: false)
        probe.focusWindow(WindowID(target), warp: false)
        probe.tiler.animation.cancelAll(snapToTargets: true)
        return try #require(
            probe.tiler.placedFrames(state: probe.state)[WindowID(target)]
        )
    }

    /// The wall-pinned shape: 2 already stands at its landing, so the
    /// second step defers too, and its own debt replaces the first
    /// one's before the arm asks.
    @Test("A deferring step past an unraised window arms")
    func deferringSecondStepArms() throws {
        let landing = try landing(of: 2)
        let core = try makeCore()
        for (id, frame) in core.tiler.placedFrames(state: core.state) {
            core.state.apply(.windowResized(id, frame))
        }
        core.state.apply(.windowResized(WindowID(2), landing))
        try startDummyPan(core)
        core.focusWindow(WindowID(3), warp: false)
        #expect(core.pendingFocusRaise == WindowID(3))
        core.focusWindow(WindowID(2), warp: false)
        #expect(core.pendingFocusRaise == WindowID(2))
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A click mid-pan: the OS raised what was clicked, never the
    /// window the last step left owing its raise.
    @Test("A report past a window still owed its raise arms")
    func unraisedLeaveReportArms() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.pendingFocusRaise = WindowID(4)
        core.handle(.windowFocused(WindowID(5)))
        #expect(core.activeSpace?.focused == WindowID(5))
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A report past a window whose raise landed arms nothing")
    func raisedLeaveReportArmsNothing() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.handle(.windowFocused(WindowID(5)))
        #expect(core.activeSpace?.focused == WindowID(5))
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
