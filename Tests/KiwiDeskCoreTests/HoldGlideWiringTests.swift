import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The production half of hold-to-glide (#1056, retimed #1082):
/// a real chord driving a real binding body through
/// `KiwiCore.execute`'s command tally, the glide's own command
/// re-issue, the refusal-cue sites, and the teardown cancels.
/// This is what reds if the tally call, a cue's
/// `noteResizeRefusal()` or the release wiring is deleted — the
/// machine ladder (`HoldGlideTests`) cannot see any of those.
@MainActor
@Suite("Hold-to-glide wiring (#1056/#1082)")
struct HoldGlideWiringTests {
    @Test("A held chord glides a lone resize until release")
    func chordArmsGlidesAndReleases() throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedBspPair()
        let idle = f.ratio

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        let afterPress = f.ratio
        #expect(afterPress > idle)
        #expect(f.heldID != nil)
        #expect(f.ticks.map(\.delay) == [0.5])

        // The wait starts the frame clock and nothing else: the
        // `#require`s are load-bearing (guard-prover, #1056) —
        // an arming regression must fail HERE, not trap the
        // runner on an empty array.
        try f.beginGlide()
        #expect(f.ratio == afterPress)

        // A frame moves the ratio further WITHOUT re-running the
        // Lua body — `hits` is the whole point: the glide
        // re-issues the captured `resize`, so an implementation
        // that went back to re-firing the binding reads 2 here.
        try f.frame()
        #expect(f.hits == .number(1))
        #expect(f.ratio > afterPress)
        let afterFrame = f.ratio

        // And it keeps travelling frame by frame.
        try f.frame()
        #expect(f.ratio > afterFrame)

        // The physical release ends it; no further frame is
        // delivered, and the glide state is clear.
        f.registrar.release(keyCode: f.combo.keyCode)
        #expect(f.heldID == nil)
        #expect(f.core.keys.isGliding == false)
        #expect(f.frameTick == nil)
        #expect(f.hits == .number(1))
    }

    @Test("A glide step writes instantly, never springing")
    func glideStepsWriteInstantly() throws {
        // #1082's ruling: the glide IS the motion, so its own
        // writes do not animate — springing an already-smooth
        // signal adds trailing AND generates the #611 retarget
        // storm deliberately.
        //
        // Asserted on the ENGINE rather than on the predicate
        // (code review, 2026-08-29). The bit is per-WRITE now, so
        // it is false everywhere except inside the frame's own
        // execute — reading `resizeWritesAnimated` between frames
        // would assert the opposite of what it used to. What is
        // observable from outside is the consequence: a glide
        // frame leaves no residency behind, with the configured
        // policy left ON so the expectation is about the glide
        // rather than about the config.
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedBspPair()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(true)]
        )
        // The configured policy is intact outside a glide write.
        #expect(f.core.resizeWritesAnimated)

        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        let before = f.ratio
        try f.frame()
        // The frame moved the ratio...
        #expect(f.ratio > before)
        // ...and animated nothing: an animated pass would leave
        // the resized windows resident in the engine.
        #expect(f.core.tiler.animation.activeCount == 0)

        // And the policy is untouched once the hold ends — the
        // scope cannot outlive the write it describes.
        f.registrar.release(keyCode: f.combo.keyCode)
        #expect(f.core.resizeWritesAnimated)
    }

    @Test("A body that is not exactly one resize never arms")
    func ineligibleBodiesNeverArm() throws {
        // Two commands: repeating the rest was never asked for.
        let two = try HoldGlideFixture(
            body: """
                KiwiDesk.resize("x", 50)
                KiwiDesk.focus("left")
                """
        )
        two.seedBspPair()
        two.registrar.press(keyCode: two.combo.keyCode)
        #expect(two.hits == .number(1))
        #expect(two.heldID == nil)
        #expect(two.ticks.isEmpty)

        // One command, but not resize.
        let focus = try HoldGlideFixture(
            body: #"KiwiDesk.focus("left")"#
        )
        focus.seedBspPair()
        focus.registrar.press(keyCode: focus.combo.keyCode)
        #expect(focus.heldID == nil)
        #expect(focus.ticks.isEmpty)
    }

    @Test("A body that rebuilds the bindings never arms")
    func rebindingBodyNeverArms() throws {
        // `bind` inside the body re-registers everything,
        // minting fresh ids for the same ref+combo — so the
        // physical release will arrive (if at all) for an id that
        // no longer exists, and a glide with no stop channel runs
        // to `maxRunSeconds`. The arm therefore refuses when the
        // press's OWN registration did not survive its fire.
        //
        // #1082 re-homed this guard (`KeybindingManager
        // .pressFire`): the repeat ladder caught it one layer
        // down, because a tick looked its registration up in
        // order to re-fire the binding, and the glide re-issues
        // the captured command instead and never looks anything
        // up. So the arm is what must refuse now — dropping the
        // `activeBindings[id] != nil` term leaves every other
        // test in this suite green.
        //
        // The rebind is ONCE-ONLY, deliberately: a body that
        // rebinds on every fire re-enters `deactivate`'s cancel
        // on the glide's own steps, which rescued the pre-fix
        // shape and left this guard inert (guard-prover round 2,
        // #1056).
        let f = try HoldGlideFixture(
            body: """
                if not rebound then
                    rebound = true
                    KiwiDesk.bind("ctrl+alt+k", function() end)
                end
                KiwiDesk.resize("x", 50)
                """
        )
        f.seedBspPair()
        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.hits == .number(1))
        #expect(f.heldID == nil)
        #expect(f.ticks.isEmpty)
        #expect(f.frameTick == nil)
    }

    @Test("An overrun rescue reaches the log seam")
    func overrunReportsThroughTheLogSeam() throws {
        // The run bound is a rescue for a LOST stop signal, so
        // its report must not itself be a seam nobody wired —
        // `HoldGlide.onOverrun` defaults to silent, and every
        // machine harness assigns it by hand (re-review,
        // #1056; the `engineLogReachesTheCore` shape). This
        // reds if `wireHoldGlideChannels` stops assigning it; the
        // manager-to-core log hop is the log-seam suites' job.
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        var logs: [String] = []
        f.core.keys.onLog = { logs.append($0) }
        f.core.keys.holdGlide.onOverrun()
        #expect(logs.contains { $0.contains("hold-glide") })
    }

    @Test("Suspend and a layer switch cancel a live run")
    func teardownPathsCancel() throws {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedBspPair()

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.heldID != nil)
        f.core.keys.suspend()
        #expect(f.heldID == nil)
        f.core.keys.resume()
        f.ticks = []

        f.registrar.press(keyCode: f.combo.keyCode)
        #expect(f.heldID != nil)
        f.core.keys.switchLayer("r")
        #expect(f.heldID == nil)
    }
}
