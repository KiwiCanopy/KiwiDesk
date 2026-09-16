import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

private let w1 = WindowID(1)
private let w2 = WindowID(2)
private let w3 = WindowID(3)

/// The commanded-focus door through a real core (#1391): a
/// Monocle `focus` step owes its `focusWindow` to the flip's
/// midpoint as `pendingMonocleFocus`, a focused-window command
/// lands it first, a query leaves it, an honored report for
/// another window drops it, and every stand-down focuses at
/// once. Every read follows a synchronous land or end, so no
/// assertion waits on the scheduled midpoint.
@Suite("Monocle flip door (#1391)", .serialized)
@MainActor
struct MonocleFlipDoorTests {
    /// Three tiled windows in a Monocle Space, w1 focused, the
    /// display pinned (#531) and the flip's own Reduce Motion
    /// read OFF — `makeTestCore` pins it on.
    private func makeMonocleCore(flip: Bool = true) -> KiwiCore {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1440, height: 900)
        }
        core.monocleFlip.reduceMotion = { !flip }
        core.monocleFlip.present = { _ in }
        core.execute(
            "set_mode",
            args: [.string("1"), .string("monocle")]
        )
        for id in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: 1,
                        appName: "App\(id)"
                    )
                )
            )
        }
        core.state.workspaces.focus(w1, in: SpaceID(1))
        core.retile()
        return core
    }

    @Test("A Monocle step owes the focus to the midpoint")
    func stepOwesTheFocus() {
        let core = makeMonocleCore()
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.monocleFlip.isPlaying)
        #expect(core.pendingMonocleFocus?.to == w2)
        #expect(core.activeSpace?.focused == w1)
        core.runPendingMonocleFocus()
        #expect(core.pendingMonocleFocus == nil)
        #expect(core.activeSpace?.focused == w2)
    }

    @Test("A focused-window command lands the pending focus first")
    func focusedCommandLandsFirst() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        // Read from the LANDED anchor: two presses reach w3,
        // never w2 twice.
        core.execute("focus", args: [.string("right")])
        core.endMonocleFlip()
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("A query lands nothing and the play continues")
    func queryLeavesThePlay() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        #expect(core.execute("get_state").isSuccess)
        #expect(core.monocleFlip.isPlaying)
        #expect(core.pendingMonocleFocus?.to == w2)
        #expect(core.activeSpace?.focused == w1)
    }

    @Test("The door ends a play and lands its focus before it plans")
    func doorEndsThePlayFirst() throws {
        let core = makeMonocleCore()
        core.focusWithMonocleFlip(w2, step: 1)
        // The App Bar's route, which passes no `execute`: the
        // second plan reads w2 as the front, not w1.
        core.focusWithMonocleFlip(w3, step: nil)
        #expect(core.pendingMonocleFocus?.from == w2)
        #expect(core.pendingMonocleFocus?.to == w3)
        core.endMonocleFlip()
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("An honored report for another window drops the debt")
    func honoredReportDrops() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        core.handle(.windowFocused(w3))
        #expect(core.pendingMonocleFocus == nil)
        core.endMonocleFlip()
        #expect(core.activeSpace?.focused == w3)
    }

    @Test("The leaving window's own duplicate echo keeps the debt")
    func leavingWindowEchoKeeps() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        core.handle(.windowFocused(w1))
        #expect(core.pendingMonocleFocus?.to == w2)
        core.endMonocleFlip()
        #expect(core.activeSpace?.focused == w2)
    }

    @Test("A gone target lands nothing; a rekey carries the debt")
    func goneAndRekey() {
        let gone = makeMonocleCore()
        gone.execute("focus", args: [.string("right")])
        gone.handle(.windowDestroyed(w2, wasMinimized: false))
        gone.runPendingMonocleFocus()
        #expect(gone.activeSpace?.focused != w2)

        let rekeyed = makeMonocleCore()
        rekeyed.execute("focus", args: [.string("right")])
        let w9 = WindowID(9)
        rekeyed.handle(.windowRekeyed(w2, w9))
        #expect(rekeyed.pendingMonocleFocus?.to == w9)
        rekeyed.endMonocleFlip()
        #expect(rekeyed.activeSpace?.focused == w9)
    }

    @Test("Off, or under Reduce Motion, the focus lands at once")
    func standsDownToTheInstantSwap() {
        let off = makeMonocleCore()
        off.execute(
            "animations.set_on_monocle_focus",
            args: [.bool(false)]
        )
        off.execute("focus", args: [.string("right")])
        #expect(!off.monocleFlip.isPlaying)
        #expect(off.activeSpace?.focused == w2)

        let reduced = makeMonocleCore(flip: false)
        reduced.execute("focus", args: [.string("right")])
        #expect(!reduced.monocleFlip.isPlaying)
        #expect(reduced.activeSpace?.focused == w2)
    }

    @Test("A non-Monocle Space never flips")
    func otherLayoutsNeverFlip() {
        let core = makeMonocleCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        core.retile()
        core.execute("focus", args: [.string("right")])
        #expect(!core.monocleFlip.isPlaying)
        #expect(core.activeSpace?.focused == w2)
    }

    @Test("The plan carries the step's sign and the issued frames")
    func planReadsTheCore() throws {
        let core = makeMonocleCore()
        let (plan, current) = try #require(
            core.monocleFlipPlan(to: w2, step: 1)
        )
        #expect(current == w1)
        #expect(plan.sign == 1)
        #expect(plan.axis == .vertical)
        let frames = core.tiler.placedFrames(state: core.state)
        #expect(plan.from == frames[w1])
        #expect(plan.to.size == frames[w2]?.size)
        #expect(plan.duration == 0.45)
    }

    @Test("A named target's sign is array order")
    func namedTargetSign() throws {
        let core = makeMonocleCore()
        core.state.workspaces.focus(w3, in: SpaceID(1))
        let (plan, _) = try #require(
            core.monocleFlipPlan(to: w1, step: nil)
        )
        #expect(plan.sign == -1)
    }
}
