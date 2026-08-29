import Foundation
import Testing

@testable import KiwiDeskCore

/// The GLIDE half of the hold ladder (#1082), on the shared
/// `HoldGlideHarness`: what a running glide does frame by frame —
/// the ramp it rides, the age it accumulates, and the two ways it
/// stops that are not a release. Arming, eligibility and teardown
/// are `HoldGlideTests`; the ramp's own arithmetic is
/// `HoldGlideRampTests`; the production wiring is
/// `HoldGlideWiringTests`.
@MainActor
@Suite("Hold-glide run (#1082)")
struct HoldGlideRunTests {
    @Test("The first frame moves at the ramp's start speed")
    func firstFrameRidesTheRampStart() throws {
        // The ramp is read BEFORE the frame is banked, so frame
        // one moves at `glideStartSteps` rather than one frame
        // into the ramp. Derived from the constants, never
        // restated, so a retune reds nothing (rule-authoring.md).
        //
        // `dt` is deliberately NOT 1/60 (guard-prover, #1082).
        // At 1/60 this assertion is blind to the one mutation it
        // most needs to catch: replacing `× dt` with a hardcoded
        // `/ 60` — reintroducing exactly the refresh-rate
        // dependence #1082 exists to remove — makes both sides
        // equal and the whole suite stays green. Any frame time
        // other than the masking constant separates them.
        let h = HoldGlideHarness()
        let dt = 1.0 / 90
        h.press(id: 1)
        try h.beginGlide()
        try h.frame(dt)
        #expect(
            h.steps[0].scale
                == HoldGlide.glideStartSteps * dt
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
        #expect(h.glideEngine.isGliding)
        h.applySucceeds = false
        try h.frame()
        #expect(h.glideEngine.heldID == nil)
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
        while h.glideEngine.heldID != nil {
            try h.frame(dt)
            frames += 1
            try #require(frames < 1_000_000)
        }
        #expect(h.overruns == 1)
        #expect(h.frameStops == 1)
        #expect(Double(frames) * dt >= HoldGlide.maxRunSeconds)
        // The rescue is one recovery shape: a fresh press arms a
        // fresh run.
        h.press(id: 9)
        #expect(h.glideEngine.heldID == 9)
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

    @Test("The same hold travels the same distance at any rate")
    func travelIsRefreshRateIndependent() throws {
        // The claim #1082 rests on, asserted against the CONSUMER
        // rather than against the ramp function. `HoldGlideRamp
        // Tests` used to carry a test of this name that compared
        // two Riemann sums of `glideSteps` with each other — true
        // by construction, and blind to `glideFrame`, which is
        // where `× dt` actually lives (guard-prover, #1082).
        //
        // One second of hold at 60 Hz and at 120 Hz must cover
        // the same distance, with the faster panel spending its
        // extra frames on finer motion rather than going quicker.
        // A fixed per-frame delta doubles the 120 Hz travel.
        func travel(frames: Int, dt: TimeInterval) throws -> Double {
            let h = HoldGlideHarness()
            h.press(id: 1)
            try h.beginGlide()
            for _ in 0..<frames { try h.frame(dt) }
            return h.steps.reduce(0) { $0 + $1.scale }
        }
        let at60 = try travel(frames: 60, dt: 1.0 / 60)
        let at120 = try travel(frames: 120, dt: 1.0 / 120)
        #expect(at60 > 0)
        // Equal to within the ramp's own discretisation — the
        // two rates sample a rising ramp at different points.
        #expect(abs(at60 - at120) < 0.05 * at60)
        // And the faster panel really did take smaller steps, so
        // "same distance" is not being bought by identical
        // per-frame deltas.
        let h60 = HoldGlideHarness()
        h60.press(id: 1)
        try h60.beginGlide()
        try h60.frame(1.0 / 60)
        let h120 = HoldGlideHarness()
        h120.press(id: 1)
        try h120.beginGlide()
        try h120.frame(1.0 / 120)
        #expect(h120.steps[0].scale < h60.steps[0].scale)
    }

    @Test("The stood-down work is paid once, at the hold's end")
    func glideEndFiresOncePerGlide() throws {
        // The #674 z-order arm is stood down per glide frame and
        // paid here (`KiwiCore+HoldGlide`). Two properties, both
        // load-bearing and neither visible from the arm's own
        // site: it fires ONCE however many frames ran — the
        // coalescing the settle used to provide, and whose loss
        // was this change's blocker (architect + code review,
        // 2026-08-29) — and it does not fire for a hold that
        // never began gliding, which would arm a restore for a
        // single tap.
        let h = HoldGlideHarness()
        h.press(id: 1)
        try h.beginGlide()
        for _ in 0..<20 { try h.frame() }
        #expect(h.glideEnds == 0)
        h.glideEngine.released(id: 1)
        #expect(h.glideEnds == 1)

        // A tap that armed but never glided pays nothing.
        let tap = HoldGlideHarness()
        tap.press(id: 2)
        tap.glideEngine.released(id: 2)
        #expect(tap.glideEnds == 0)

        // And every other way a glide ends pays it exactly once:
        // a refusal, and a failing step.
        let refused = HoldGlideHarness()
        refused.press(id: 3)
        try refused.beginGlide()
        try refused.frame()
        refused.glideEngine.noteRefusal()
        #expect(refused.glideEnds == 1)

        let failing = HoldGlideHarness()
        failing.press(id: 4)
        try failing.beginGlide()
        failing.applySucceeds = false
        try failing.frame()
        #expect(failing.glideEnds == 1)
    }

    @Test("A frozen frame clock still ends the hold")
    func wallClockBackstopEndsAFrozenGlide() throws {
        // The run bound is spent in SIMULATED frame time, which
        // is right — a starved queue must not age a glide it
        // never ticked — but that clock can STOP: the driver is
        // bound to one screen, and display sleep or a disconnect
        // mid-hold freezes it (architect review, 2026-08-29).
        // Without a second net the run stays armed for the
        // session. The backstop rides the already-injected
        // `schedule` seam, so it is reachable with no timers.
        let h = HoldGlideHarness()
        h.press(id: 1)
        try h.beginGlide()
        try h.frame()
        // The clock dies here: no further frames ever arrive.
        // The pending scheduled work is the backstop.
        let backstop = h.ticks.popLast()
        try #require(backstop).work()
        #expect(h.glideEngine.heldID == nil)
        #expect(h.glideEngine.isGliding == false)
        #expect(h.overruns == 1)
        #expect(h.glideEnds == 1)
    }
}
