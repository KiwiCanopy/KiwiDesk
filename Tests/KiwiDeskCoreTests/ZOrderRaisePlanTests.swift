import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure half of the z-order drain (#684): which windows a
/// restore actually has to re-raise. Split from `ZOrderDrainTests`
/// — which owns the loop, its budget and the fake WindowServer —
/// per the early-split convention, not grown.
///
/// Stacking is by distance from focus, so most restores find most
/// pairs already correct; a needless raise is not free, since it
/// steals focus for an echo and drags a slow app back to the front
/// of the pile.
@Suite("Z-order raise plan (#684)")
struct ZOrderRaisePlanTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map(WindowID.init)
    }

    /// The float raise's floor is the tiled plane MINUS the window
    /// being focused. Keeping the focused window in it would be a
    /// condition no raise can satisfy — a quiet raise never gets
    /// above the frontmost app's key window, which after
    /// `focusWindow` is exactly that one — so every poll would
    /// fail and the drain would spend its whole budget on every
    /// focus change.
    @Test("The float floor is the tiled plane minus the focus")
    func floatFloorExcludesTheFocusedWindow() {
        let tiled = ids([1, 2, 3])
        #expect(
            KiwiCore.floatRaiseFloor(
                tiled: tiled,
                focused: WindowID(2)
            ) == ids([1, 3])
        )
        // Nothing focused (a traveler holds it, or the space is
        // empty of local focus): the whole plane stands.
        #expect(
            KiwiCore.floatRaiseFloor(tiled: tiled, focused: nil)
                == tiled
        )
    }

    @Test("A pile already in order raises nothing")
    func correctOrderPlansNothing() {
        // Raise order is deepest-first, so the desired
        // front-to-back is its reverse.
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([1, 2, 3, 4]),
                above: []
            ).isEmpty
        )
    }

    /// A reversed pile needs every raise but ONE: the window that
    /// belongs at the very back is already there, and a raise can
    /// only move a window to the front. That is the pathological
    /// case head-on — the deepest window used to be raised first
    /// every time, so a slow app in that slot always surfaced.
    @Test("A reversed pile leaves the deepest window alone")
    func reversedOrderLeavesTheDeepestWindow() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([4, 3, 2, 1]),
                above: []
            ) == ids([3, 2, 1])
        )
    }

    @Test("A single misplaced window is the only raise")
    func oneSwappedPairPlansOneRaise() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([2, 1, 3, 4]),
                above: []
            ) == ids([1])
        )
    }

    /// The measured failure: one window too far forward, the rest
    /// already right. Stacking is by distance from focus, so a
    /// short jump leaves most pairs correct — and a needless raise
    /// is not free, it steals focus for an echo and drags a slow
    /// app back to the front of the pile.
    @Test("Only the windows out of place are raised")
    func oneMisplacedWindowPlansTheStretchAboveIt() {
        // Desired front-to-back 1 > 2 > 3 > 4; window 4 already
        // stands correctly at the back, 3 does not.
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([4, 3, 2, 1]),
                observed: ids([1, 2, 4, 3]),
                above: []
            ) == ids([3, 2, 1])
        )
    }

    /// A target the WindowServer does not list on screen —
    /// minimized, or on another space — has no stacking to fix and
    /// no landing that could ever be verified.
    @Test("An off-screen target is dropped from the plan")
    func offScreenTargetIsDropped() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([9, 3, 2, 1]),
                observed: ids([3, 1, 2]),
                above: []
            ) == ids([2, 1])
        )
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([9]),
                observed: ids([1, 2]),
                above: []
            ).isEmpty
        )
    }

    // MARK: - The floor

    /// The float raise (#418) exists to lift the float layer back
    /// over the tiled window `focusWindow` just raised — and
    /// nothing ever reorders floats relative to each other, so
    /// diffing them against each other alone finds them "already
    /// correct" and raises nothing, leaving them buried. The floor
    /// is what makes that visible to the plan.
    @Test("A target under the floor is out of place")
    func floorForcesARaise() {
        let floats = ids([1, 2])
        // Floats in the right order among themselves, but the
        // tiled window (9) sits above both.
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([2, 1]),
                observed: ids([9, 1, 2]),
                above: ids([9])
            ) == ids([2, 1])
        )
        // Same floats, already clear of the tiled plane: nothing
        // to do, so the common case still costs one read.
        #expect(
            ZOrderDrain.plan(
                raiseOrder: floats.reversed(),
                observed: ids([1, 2, 9]),
                above: ids([9])
            ).isEmpty
        )
    }

    /// One float left under the floor drags the whole layer with
    /// it, and that is minimal rather than lazy: a raise can only
    /// move a window to the FRONT, so lifting the buried float
    /// clear of the tile puts it above its own layer-mates, and
    /// they have to go back over it in order.
    @Test("A float under the floor drags the layer above it")
    func floorRaisesTheStretchAboveTheBuriedTarget() {
        #expect(
            ZOrderDrain.plan(
                raiseOrder: ids([3, 2, 1]),
                observed: ids([1, 2, 9, 3]),
                above: ids([9])
            ) == ids([3, 2, 1])
        )
    }
}
