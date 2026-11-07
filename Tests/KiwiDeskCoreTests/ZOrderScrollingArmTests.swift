import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #2985: which focus moves owe a scrolling restore now that a restore
/// no longer keeps the buried order. A 460 pt slot shows three windows
/// beside a sliver in 1440 pt, so "another window shows" holds on every
/// case here and only the move and the row's two ends decide. Same
/// suite shape as `ZOrderFocusJumpTests`.
@Suite(
    "Scrolling focus moves arm a restore (#2985)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ZOrderScrollingArmTests {
    /// Six tiles and a float (7), 460 pt slots, focus seated on tile 4
    /// so a step back to 3 moves nothing and a step to 5 pans.
    private func makeCore(tiles: Int = 6) throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-scroll-arm-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        for id in Array(1...tiles) + [7] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)",
                        isFloating: id == 7
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
                args: [.number(460)]
            ).isSuccess
        )
        core.focusWindow(WindowID(UInt32(min(4, tiles))), warp: false)
        core.tiler.animation.cancelAll(snapToTargets: true)
        core.pendingZOrderRestore = false
        // The seat's restore stamps what it raised and its pass what
        // it placed, and the frozen clocks would read a report of any
        // of them as an echo or a placement bounce.
        core.zOrderRaiseEchoes = [:]
        core.selfRaiseStamps = [:]
        for id in 1...7 {
            core.tiler.placements.forget(WindowID(UInt32(id)))
        }
        // The premise the overflowing cases read: another window shows.
        #expect(
            tiles < 6 || core.scrollingRowShowsOthers(leaving: WindowID(4))
        )
        return core
    }

    /// Holds a scheduled restore pending instead of firing it.
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

    private func offset(_ core: KiwiCore) -> CGFloat? {
        core.activeSpace?.scrollRest?.offset
    }

    /// A report the handler took, so no silence below is a net ahead
    /// of the arm answering for it.
    private func report(_ core: KiwiCore, _ raw: UInt32) {
        core.handle(.windowFocused(WindowID(raw)))
        expectEqual(core.activeSpace?.focused, WindowID(raw))
    }

    // MARK: - A commanded move

    @Test("A step that pans arms")
    func panningStepArms() throws {
        let core = try makeCore()
        let before = offset(core)
        try startDummyPan(core)
        core.focusWindow(WindowID(5), warp: false)
        #expect(offset(core) != before)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A step that moves nothing arms nothing")
    func stillStepArmsNothing() throws {
        let core = try makeCore()
        let before = offset(core)
        try startDummyPan(core)
        core.focusWindow(WindowID(3), warp: false)
        expectEqual(offset(core), before)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The running drain was planned for the old focus.
    @Test("A still step during a drain arms")
    func stillStepDuringDrainArms() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.floatRaiseDebt.restoresInFlight = 1
        core.focusWindow(WindowID(3), warp: false)
        #expect(core.pendingZOrderRestore)
        core.floatRaiseDebt.restoresInFlight = 0
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// No evidence of a move along the row, and a spurious restack
    /// lifts tiles over the floats (#418).
    @Test("A move with an end off the row asks nothing")
    func floatEndsAskNothing() throws {
        let core = try makeCore()
        let moved = offset(core).map { $0 + 100 }
        #expect(
            !core.scrollFocusMoveOwesRestore(
                to: WindowID(7),
                from: WindowID(4),
                offsetBefore: moved
            )
        )
        #expect(
            !core.scrollFocusMoveOwesRestore(
                to: WindowID(4),
                from: WindowID(7),
                offsetBefore: moved
            )
        )
        // The control: the same stale offset between two tiles asks.
        #expect(
            core.scrollFocusMoveOwesRestore(
                to: WindowID(3),
                from: WindowID(4),
                offsetBefore: moved
            )
        )
    }

    // MARK: - What the row shows

    /// 700 pt slots: the focus, and past it the one window it left,
    /// with only slivers beside them.
    private func seatTwoUp(_ core: KiwiCore) {
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(700)]
            ).isSuccess
        )
        core.tiler.animation.cancelAll(snapToTargets: true)
    }

    @Test("The window the focus left does not count as another")
    func leftWindowIsNoOther() throws {
        let core = try makeCore()
        seatTwoUp(core)
        #expect(core.scrollingRowShowsOthers(leaving: nil))
        #expect(!core.scrollingRowShowsOthers(leaving: WindowID(3)))
    }

    /// A focused float has no slot, and under a fixed anchor the
    /// remembered one is seated: the plan splits on it, never on the
    /// row's first window, which would call the seated window shown.
    @Test("A focused float's plan reads the seated slot")
    func floatPlanReadsTheSeat() throws {
        let core = try makeCore()
        #expect(
            core.execute(
                "scroll.set_anchor",
                args: [.string("end")]
            ).isSuccess
        )
        seatTwoUp(core)
        let space = try #require(core.activeSpace)
        core.state.workspaces.focus(WindowID(7), in: space.id)
        #expect(core.scrollingRowShowsOthers(leaving: nil))
        #expect(!core.scrollingRowShowsOthers(leaving: WindowID(3)))
    }

    // MARK: - A focus report

    @Test("A report that pans arms")
    func panningReportArms() throws {
        let core = try makeCore()
        try startDummyPan(core)
        report(core, 5)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A report that moves nothing arms nothing")
    func stillReportArmsNothing() throws {
        let core = try makeCore()
        try startDummyPan(core)
        report(core, 3)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The closing re-assert's echo reports the focus it already holds.
    /// A running drain, so "the row moved" answers yes and only the
    /// refusal of a move onto itself is left.
    @Test("Our own raise's echo arms nothing")
    func selfEchoArmsNothing() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.floatRaiseDebt.restoresInFlight = 1
        core.selfRaiseStamps[WindowID(4)] = core.wallClock()
        report(core, 4)
        #expect(!core.pendingZOrderRestore)
        core.floatRaiseDebt.restoresInFlight = 0
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A click inside a raise's echo window is the user's own move:
    /// it arms, and owes the floats the raise the handler skips for
    /// an echo.
    @Test("A click on a stamped window arms and owes the floats")
    func clickedEchoArms() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.deferred.cancel(.floatRaise)
        core.selfRaiseStamps[WindowID(5)] = core.wallClock()
        core.lastLeftClick = (core.wallClock(), .zero, WindowID(5))
        report(core, 5)
        #expect(core.pendingZOrderRestore)
        #expect(core.deferred.isScheduled(.floatRaise))
        core.deferred.cancel(.floatRaise)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A report inside a Desktop switch arms nothing")
    func switchGraceArmsNothing() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.eventLoop.lastDesktopChange = core.wallClock()
        report(core, 5)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    // MARK: - A close

    /// The fold moved the focus, so no focus raise lifts the floats
    /// back over the restore.
    @Test("A close that arms owes the floats a raise")
    func closeOwesFloats() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.deferred.cancel(.floatRaise)
        core.armCloseReturnRestack(
            to: WindowID(4),
            fromRemovedSlot: 4
        )
        #expect(core.pendingZOrderRestore)
        #expect(core.deferred.isScheduled(.floatRaise))
        core.deferred.cancel(.floatRaise)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A row that fits has no restore for the raise to answer.
    @Test("A close in a row that fits owes the floats nothing")
    func fittingCloseOwesNothing() throws {
        let core = try makeCore(tiles: 3)
        try startDummyPan(core)
        core.deferred.cancel(.floatRaise)
        core.armCloseReturnRestack(
            to: WindowID(3),
            fromRemovedSlot: 0
        )
        #expect(!core.pendingZOrderRestore)
        #expect(!core.deferred.isScheduled(.floatRaise))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A close that arms nothing lifted nothing.
    @Test("A close that arms nothing owes the floats nothing")
    func stillCloseOwesNothing() throws {
        let core = try makeCore()
        try startDummyPan(core)
        core.deferred.cancel(.floatRaise)
        core.armCloseReturnRestack(
            to: WindowID(4),
            fromRemovedSlot: nil
        )
        #expect(!core.pendingZOrderRestore)
        #expect(!core.deferred.isScheduled(.floatRaise))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
