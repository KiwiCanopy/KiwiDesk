import Foundation
import Testing

@testable import KiwiDeskCore

/// The hold-to-glide ladder (#1056, retimed #1082), machine-only:
/// every seam injected, no timers, no `CADisplayLink`, no Carbon,
/// no Lua. The production wiring — a real chord driving a real
/// `resize` through `KiwiCore.execute`'s tally — is
/// `HoldRepeatWiringTests`, which is what reds if the tally call
/// is deleted; this suite cannot see that and does not claim to.
/// The ramp's own shape is `HoldGlideRampTests`.
@MainActor
@Suite("Hold-to-glide ladder (#1056/#1082)")
struct HoldRepeatTests {
    @Test("A lone resize arms, waits, then glides on frames")
    func armsWaitsAndGlides() throws {
        let h = HoldGlideHarness()
        h.press(id: 7)
        #expect(h.repeatEngine.heldID == 7)
        // Exactly one scheduled wait, at the system delay — the
        // glide itself never rides the scheduler.
        #expect(h.ticks.map(\.delay) == [0.5])
        #expect(h.repeatEngine.isGliding == false)
        #expect(h.steps.isEmpty)

        try h.beginGlide()
        #expect(h.repeatEngine.isGliding)
        // The only thing left on the scheduler is the wall-clock
        // backstop, at the run bound — the glide itself rides
        // frames and never the scheduler.
        #expect(
            h.ticks.map(\.delay) == [HoldRepeat.maxRunSeconds]
        )
        // Still nothing applied: a glide moves on FRAMES, so an
        // engine that applied on the wait itself would double the
        // press's own step.
        #expect(h.steps.isEmpty)

        try h.frame()
        #expect(h.steps.count == 1)
        // The press's own arguments are re-issued verbatim — the
        // glide scales the delta, it does not invent one.
        #expect(h.steps[0].args == [.string("x"), .number(50)])
    }

    @Test("Ineligible presses never arm")
    func ineligiblePressesNeverArm() {
        // A verb outside the repeatable set (overshooting focus
        // is worse than pressing again).
        let focus = HoldGlideHarness()
        focus.press(id: 1, commands: [("focus", true)])
        #expect(focus.repeatEngine.heldID == nil)
        #expect(focus.ticks.isEmpty)

        // A body running MORE than the one command: the glide
        // re-issues only the resize, so a body doing more would
        // silently lose the rest of itself on every frame.
        let two = HoldGlideHarness()
        two.press(
            id: 1,
            commands: [("resize", true), ("focus", true)]
        )
        #expect(two.repeatEngine.heldID == nil)

        // A failed resize (unsupported layout) would beep per
        // frame.
        let failed = HoldGlideHarness()
        failed.press(id: 1, commands: [("resize", false)])
        #expect(failed.repeatEngine.heldID == nil)

        // No release channel: a glide could never stop.
        let deaf = HoldGlideHarness(releaseCapable: false)
        deaf.press(id: 1)
        #expect(deaf.repeatEngine.heldID == nil)
    }

    @Test("A refusal cues once and ends the run")
    func refusalEndsTheRun() throws {
        // At the wall on the FIRST press: the pill flashed once,
        // and holding must not flash it per frame.
        let atWall = HoldGlideHarness()
        _ = atWall.repeatEngine.beginFire()
        atWall.repeatEngine.noteCommand(
            "resize",
            args: [.string("x"), .number(50)],
            succeeded: true
        )
        atWall.repeatEngine.noteRefusal()
        atWall.repeatEngine.endFire(id: 1)
        #expect(atWall.repeatEngine.heldID == nil)
        #expect(atWall.ticks.isEmpty)

        // Reaching the wall MID-GLIDE: the frame that hit it is
        // the last, and the frame clock is torn down with it —
        // the run must not keep being ticked after it ends.
        let run = HoldGlideHarness()
        run.press(id: 2)
        try run.beginGlide()
        try run.frame()
        run.repeatEngine.noteRefusal()
        #expect(run.repeatEngine.heldID == nil)
        #expect(run.repeatEngine.isGliding == false)
        #expect(run.frameStops == 1)
        #expect(run.isTicking == false)
    }

    @Test("Release ends the run; a stale release is ignored")
    func releaseStopsTheRun() throws {
        let h = HoldGlideHarness()
        h.press(id: 3)
        try h.beginGlide()
        // A release for some OTHER id (a run already replaced)
        // must not touch this one.
        h.repeatEngine.released(id: 99)
        #expect(h.repeatEngine.heldID == 3)
        #expect(h.isTicking)
        h.repeatEngine.released(id: 3)
        #expect(h.repeatEngine.heldID == nil)
        #expect(h.frameStops == 1)
    }

    @Test("A new press replaces the previous run")
    func newPressReplacesTheRun() throws {
        let h = HoldGlideHarness()
        h.press(id: 4)
        try h.beginGlide()
        h.press(id: 5)
        #expect(h.repeatEngine.heldID == 5)
        // The first run's frame clock was torn down — one active
        // hold at a time, and two live clocks would double every
        // step.
        #expect(h.frameStops == 1)
        #expect(h.repeatEngine.isGliding == false)
        // The old release arriving later is stale and ignored.
        h.repeatEngine.released(id: 4)
        #expect(h.repeatEngine.heldID == 5)
    }

    @Test("Teardown cancels — no release can arrive")
    func teardownCancels() throws {
        let h = HoldGlideHarness()
        h.press(id: 6)
        h.repeatEngine.cancelRun()
        #expect(h.repeatEngine.heldID == nil)
        #expect(h.cancels == 1)
        // A cancelled run's wait firing late is inert: it must
        // not start a frame clock nobody can stop.
        let lateTick = h.ticks.popLast()
        try #require(lateTick).work()
        #expect(h.repeatEngine.isGliding == false)
        #expect(h.isTicking == false)
        #expect(h.steps.isEmpty)
    }

    @Test("A nested fire's tally never leaks into the outer's")
    func nestedFireTallyIsIsolated() {
        // A Lua body that pumps a run loop can deliver a second
        // press mid-fire (the case `KeybindingManager.fire`'s
        // `wasFiring` exists for). The inner fire judges its own
        // tally; the outer fire's counts come back via the
        // snapshot and are judged on their own. The OUTER fire is
        // a lone `focus` — deliberately different from the
        // inner's lone `resize`, so a broken save/restore
        // (re-review, #1056) leaves the inner's arming tally
        // behind and the outer press wrongly arms below.
        let h = HoldGlideHarness()
        _ = h.repeatEngine.beginFire()
        h.repeatEngine.noteCommand(
            "focus",
            args: [.string("left")],
            succeeded: true
        )

        // Nested press: one successful resize — arms id 2.
        let saved = h.repeatEngine.beginFire()
        h.repeatEngine.noteCommand(
            "resize",
            args: [.string("x"), .number(50)],
            succeeded: true
        )
        h.repeatEngine.endFire(id: 2)
        #expect(h.repeatEngine.heldID == 2)
        h.repeatEngine.restoreTally(saved)

        // The outer press closes on its own tally — one focus,
        // never repeatable — so it replaces the inner hold and
        // arms nothing. A leaked inner tally reads as one
        // successful resize here and arms id 1 instead.
        h.repeatEngine.endFire(id: 1)
        #expect(h.repeatEngine.heldID == nil)
    }

}
