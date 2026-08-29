import Foundation
import Testing

@testable import KiwiDeskCore

/// The GLIDE half of the hold ladder (#1082), on the shared
/// `HoldGlideHarness`: what a running glide does frame by frame —
/// the ramp it rides, the age it accumulates, and the two ways it
/// stops that are not a release. Arming, eligibility and teardown
/// are `HoldRepeatTests`; the ramp's own arithmetic is
/// `HoldGlideRampTests`; the production wiring is
/// `HoldRepeatWiringTests`.
@MainActor
@Suite("Hold-glide run (#1082)")
struct HoldGlideRunTests {
    @Test("The first frame moves at the ramp's start speed")
    func firstFrameRidesTheRampStart() throws {
        // The ramp is read BEFORE the frame is banked, so frame
        // one moves at `glideStartSteps` rather than one frame
        // into the ramp. Derived from the constants, never
        // restated, so a retune reds nothing (rule-authoring.md).
        let h = HoldGlideHarness()
        let dt = 1.0 / 60
        h.press(id: 1)
        try h.beginGlide()
        try h.frame(dt)
        #expect(
            h.steps[0].scale
                == HoldRepeat.glideStartSteps * dt
        )
        // And it accelerates: a later frame moves further for the
        // same elapsed frame time.
        for _ in 0..<30 { try h.frame(dt) }
        #expect(h.steps.last!.scale > h.steps[0].scale)
    }

    @Test("A step that stops succeeding ends the glide")
    func failingStepEndsTheGlide() throws {
        // A resize that starts failing mid-hold — a mode change,
        // a focus loss — must stop rather than hammer the
        // dispatcher sixty to a hundred and twenty times a
        // second for the rest of the hold.
        let h = HoldGlideHarness()
        h.press(id: 3)
        try h.beginGlide()
        try h.frame()
        #expect(h.repeatEngine.isGliding)
        h.applySucceeds = false
        try h.frame()
        #expect(h.repeatEngine.heldID == nil)
        #expect(h.frameStops == 1)
        #expect(h.isTicking == false)
    }

    @Test("A glide that outlives its bound is force-ended")
    func overrunForceEndsTheGlide() throws {
        // The stop signal is one Carbon release event; a lost one
        // must cost a bounded hold, never the session (#611's
        // force-settle shape). The bound is derived from the
        // constant, never restated. Age is simulated from the
        // frames actually delivered, so this walks real `dt`s.
        let h = HoldGlideHarness()
        let dt = 1.0 / 60
        h.press(id: 8)
        try h.beginGlide()
        var frames = 0
        while h.repeatEngine.heldID != nil {
            try h.frame(dt)
            frames += 1
            try #require(frames < 1_000_000)
        }
        #expect(h.overruns == 1)
        #expect(h.frameStops == 1)
        #expect(Double(frames) * dt >= HoldRepeat.maxRunSeconds)
        // The rescue is one recovery shape: a fresh press arms a
        // fresh run.
        h.press(id: 9)
        #expect(h.repeatEngine.heldID == 9)
    }

    @Test("A stalled clock ages the glide by what it moved")
    func ageIsSimulatedFromDeliveredFrames() throws {
        // The #611 idiom, one subsystem over: a starved main
        // queue must not age a glide it never ticked. Two frames
        // of the same `dt` age the run identically however long
        // the wall clock took between them, so the bound is
        // spent by MOVEMENT — which is also what keeps the ramp
        // from jumping a stall's worth of speed in one step.
        let h = HoldGlideHarness()
        h.press(id: 1)
        try h.beginGlide()
        try h.frame(1.0 / 60)
        let firstScale = h.steps[0].scale
        let second = HoldGlideHarness()
        second.press(id: 1)
        try second.beginGlide()
        try second.frame(1.0 / 60)
        #expect(second.steps[0].scale == firstScale)
        // And a clamped long frame simply moves further for that
        // one frame rather than being discounted.
        try h.frame(1.0 / 30)
        #expect(h.steps[1].scale > h.steps[0].scale)
    }

    @Test("The glide carries the press's own arguments")
    func glideCarriesThePressArguments() throws {
        // The captured arguments must be the REPEATABLE
        // command's, not whatever ran last in the fire, and they
        // must survive the save/restore pair — a glide re-issuing
        // an empty or foreign argument list resizes the wrong
        // axis, or nothing at all, with every behavioural suite
        // still green.
        let h = HoldGlideHarness()
        h.press(
            id: 1,
            args: [.string("y"), .number(-25)]
        )
        try h.beginGlide()
        try h.frame()
        #expect(
            h.steps[0].args == [.string("y"), .number(-25)]
        )
    }
}
