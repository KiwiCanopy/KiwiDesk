import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The gone-window tombstone (#1049): a slow AX app flaps — the
/// same window is dropped and re-added under the same id seconds
/// apart — and the destroy-forgets rule (#152/#158) made every
/// re-add re-run the whole learn dance. The believed ledger
/// parks on the gone path and revives on the matching re-add;
/// the end-to-end half proves the KiwiCore wiring, because
/// deleting either the stash or the revive call leaves the pure
/// tests green while the flap dances again.
@Suite("Size-bound revive across a flap (#1049)", .serialized)
@MainActor
struct SizeBoundReviveTests {
    private let w = WindowID(7)
    private let asked = CGSize(width: 1626, height: 1005)
    private let snapped = CGSize(width: 439, height: 1005)

    private func learned() -> SizeBoundLearner {
        var learner = SizeBoundLearner()
        for _ in 0..<2 {
            learner.recordAsk(w, size: asked)
            learner.observe(
                w,
                currentSize: snapped,
                settledRead: true
            )
        }
        return learner
    }

    @Test("A same-pid re-add within the grace revives")
    func samePidReAddRevives() {
        var learner = learned()
        let gone = Date()
        learner.stashOnGone(w, pid: 9, now: gone)
        #expect(learner.bound(for: w) == nil)
        let revived = learner.revive(
            w,
            pid: 9,
            now: gone.addingTimeInterval(5)
        )
        #expect(revived)
        #expect(
            learner.bound(for: w)?
                .consumedWidth(asking: 1626) == 439
        )
    }

    @Test("Another pid's reused id revives nothing")
    func otherPidDoesNotRevive() {
        var learner = learned()
        let gone = Date()
        learner.stashOnGone(w, pid: 9, now: gone)
        let revived = learner.revive(
            w,
            pid: 10,
            now: gone.addingTimeInterval(5)
        )
        #expect(!revived)
        #expect(learner.bound(for: w) == nil)
    }

    @Test("A stale tombstone revives nothing")
    func staleTombstoneDoesNotRevive() {
        var learner = learned()
        let gone = Date()
        learner.stashOnGone(w, pid: 9, now: gone)
        let revived = learner.revive(
            w,
            pid: 9,
            now: gone.addingTimeInterval(
                SizeBoundLearner.reviveGraceSeconds + 1
            )
        )
        #expect(!revived)
        #expect(learner.bound(for: w) == nil)
    }

    @Test("A genuine-resize forget parks nothing")
    func genuineResizeForgetParksNothing() {
        // The resize path's ledger is STALE, not orphaned — a
        // revive there would restore exactly the dead answer
        // the forget exists to drop.
        var learner = learned()
        learner.forget(w)
        let revived = learner.revive(
            w,
            pid: 9,
            now: Date()
        )
        #expect(!revived)
    }

    @Test("The flap re-add keeps its bound end to end")
    func flapReAddKeepsItsBound() {
        // The wiring half: destroy parks (with the pre-fold
        // pid), the re-add revives before the arrival retile.
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { _, _, _ in }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w, pid: 9, appName: "App")
            )
        )
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(w, size: asked)
            core.tiler.boundLearner.observe(
                w,
                currentSize: snapped,
                settledRead: true
            )
        }
        #expect(core.tiler.sizeBound(for: w) != nil)
        core.handle(.windowDestroyed(w, wasMinimized: false))
        #expect(core.tiler.sizeBound(for: w) == nil)
        core.handle(
            .windowCreated(
                ManagedWindow(id: w, pid: 9, appName: "App")
            )
        )
        #expect(
            core.tiler.sizeBound(for: w)?
                .consumedWidth(asking: 1626) == 439
        )
    }

    @Test("The unhide re-add keeps its bound end to end")
    func unhideReAddKeepsItsBound() {
        // The hidden arm's twin wiring (guard-prover round 2
        // named it unpinned): a hide removal parks with the
        // pre-fold pid exactly like a destroy, or the unhide —
        // the #1049 comeback case — re-runs the dance.
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1000, height: 800)
        }
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { _, _, _ in }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: w, pid: 9, appName: "App")
            )
        )
        for _ in 0..<2 {
            core.tiler.boundLearner.recordAsk(w, size: asked)
            core.tiler.boundLearner.observe(
                w,
                currentSize: snapped,
                settledRead: true
            )
        }
        core.handle(.windowHidden(w))
        #expect(core.tiler.sizeBound(for: w) == nil)
        core.handle(
            .windowCreated(
                ManagedWindow(id: w, pid: 9, appName: "App")
            )
        )
        #expect(
            core.tiler.sizeBound(for: w)?
                .consumedWidth(asking: 1626) == 439
        )
    }
}
