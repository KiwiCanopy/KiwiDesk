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
/// landing as `pendingMonocleFocus`, a focused-window command
/// lands it first, a query leaves it, an honored report for
/// another window drops it, and every stand-down focuses at
/// once. Every read follows a synchronous land or end, so no
/// assertion waits on the scheduled landing.
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

    @Test("A Monocle step owes the focus to the landing")
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

    @Test("A press during a play lands at once and retargets it")
    func burstIsInstant() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        #expect(core.monocleFlip.isPlaying)
        core.execute("focus", args: [.string("right")])
        // The second press is navigation: its focus is on w3
        // now, no debt behind it, and the one play goes on.
        #expect(core.activeSpace?.focused == w3)
        #expect(core.monocleFlip.isPlaying)
        #expect(core.pendingMonocleFocus == nil)
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

    @Test("The door lands a play's focus before it acts")
    func doorLandsFirst() throws {
        let core = makeMonocleCore()
        core.focusWithMonocleFlip(w2, step: 1)
        // The App Bar's route, which passes no `execute`: the
        // first press's focus lands, then the click's, in order.
        core.focusWithMonocleFlip(w3, step: nil)
        #expect(core.pendingMonocleFocus == nil)
        #expect(core.activeSpace?.focused == w3)
        #expect(
            core.tiler.placements.recentDisplacement(w2)
        )
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
        // `focusWindow` was never reached: it notes the window
        // it moves focus OFF in the placement ledger (#1161),
        // and the anchor carries no such note.
        #expect(gone.pendingMonocleFocus == nil)
        #expect(
            !gone.tiler.placements.recentDisplacement(
                gone.activeSpace?.focused ?? w1
            )
        )

        let rekeyed = makeMonocleCore()
        rekeyed.execute("focus", args: [.string("right")])
        let w9 = WindowID(9)
        rekeyed.handle(.windowRekeyed(w2, w9))
        #expect(rekeyed.pendingMonocleFocus?.to == w9)
        rekeyed.endMonocleFlip()
        #expect(rekeyed.activeSpace?.focused == w9)
    }

    @Test("A Space switch drops the debt and the play")
    func spaceSwitchDrops() {
        let core = makeMonocleCore()
        core.execute("focus", args: [.string("right")])
        #expect(core.execute("focus_space", args: [.string("2")]).isSuccess)
        #expect(core.pendingMonocleFocus == nil)
        #expect(!core.monocleFlip.isPlaying)
        core.runPendingMonocleFocus()
        #expect(core.activeSpace?.id == SpaceID(2))
        // And a debt whose Space is no longer active is dropped
        // at the landing, never raised across Spaces.
        let stale = makeMonocleCore()
        stale.execute("focus", args: [.string("right")])
        stale.state.workspaces.activate(SpaceID(2))
        stale.runPendingMonocleFocus()
        #expect(stale.pendingMonocleFocus == nil)
        #expect(stale.activeSpace?.id == SpaceID(2))
        // The refusal is read on the Space the debt was minted
        // for: its focus never moved to w2. (The displacement
        // ledger cannot see this — `focusWindow` notes the
        // ACTIVE Space's anchor, nil in an empty Space 2.)
        #expect(
            stale.state.workspaces[SpaceID(1)]?.focused == w1
        )
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
