import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// How presses and the hand meet a judgement in flight (#2973): its one
/// slot, the waits, and what a press reads.
extension FloatAspectJudgementTests {
    @Test("A press arms one judgement, from where the window stood")
    func pressArms() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        let armed = core.deferred.task(for: .floatAspect)
        #expect(armed != nil)
        // A press in flight replaces nothing: a probe already written
        // must get its answer.
        press(core, 50)
        #expect(core.deferred.task(for: .floatAspect) == armed)
        core.deferred.cancel(.floatAspect)
    }

    @Test("A judged window, or an ask too small to read, arms nothing")
    func armsNothing() {
        let core = makeCore()
        answer(core, start.size)
        // 4 pt of width carries 2.25 of height: inside the tolerance, so
        // a lock's answer would read as a free window.
        press(core, -4)
        #expect(!core.deferred.isScheduled(.floatAspect))
        core.state.floatAspects[id] = .init(
            pid: 900_001,
            ratio: nil,
            freeAxes: ["x"]
        )
        press(core, 50)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test(
        "Each ending of a judgement frees its slot for the next",
        arguments: [
            // complied, fitted, a refused shrink, a broken ratio
            (CGSize(width: 850, height: 450), 50.0),
            (CGSize(width: 749, height: 421), -50.0),
            (CGSize(width: 800, height: 450), -50.0),
            (CGSize(width: 860, height: 400), 50.0),
        ]
    )
    func endsFreeTheSlot(answered: CGSize, delta: Double) {
        let core = makeCore()
        answer(core, start.size)
        press(core, delta)
        #expect(core.deferred.isScheduled(.floatAspect))
        answer(core, answered)
        core.judgeFloatAspect(ask("x", delta, to: grow))
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A read with no answer, or a window gone, frees the slot")
    func abandonFreesTheSlot() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        core.windowServer.readWindowBounds = { _ in nil }
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(!core.deferred.isScheduled(.floatAspect))

        answer(core, start.size)
        press(core, 50)
        core.state.windows.setFullscreen(id, true)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A probe's answer frees the slot once it has one")
    func probeAnswerFreesTheSlot() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A window moved during the wait is left where the hand put it")
    func movedDuringAsk() {
        let core = makeCore()
        core.windowServer.readWindowBounds = { [start] _ in
            start.offsetBy(dx: 300, dy: 120)
        }
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A press on the other axis voids an ask not yet probed")
    func otherAxisVoids() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        #expect(core.deferred.isScheduled(.floatAspect))
        #expect(
            core.execute("resize", args: [.string("y"), .number(50)])
                .isSuccess
        )
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A press during a probe writes nothing and keeps the answer")
    func pressDuringProbeWaits() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        let probing = core.deferred.task(for: .floatAspect)
        let written = core.tiler.recentInstantTarget(id)
        #expect(written?.size == probed)
        press(core, 50)
        #expect(core.tiler.recentInstantTarget(id) == written)
        #expect(core.deferred.task(for: .floatAspect) == probing)
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }

    @Test("The end of a probe lets presses through again")
    func probeEndReleasesPresses() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspectFlight == .probing(id))
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspectFlight == nil)
    }

    @Test("A press on the other axis leaves a written probe its answer")
    func otherAxisKeepsAProbe() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        let probing = core.deferred.task(for: .floatAspect)
        #expect(probing != nil)
        #expect(
            core.execute("resize", args: [.string("y"), .number(50)])
                .isSuccess
        )
        #expect(core.deferred.task(for: .floatAspect) == probing)
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }

    @Test("A core stopped mid-probe leaves no press dead")
    func stoppedProbeIsInert() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspectFlight == .probing(id))
        core.deferred.cancelAll()
        press(core, 50)
        #expect(core.tiler.recentInstantTarget(id)?.width == 850)
        core.deferred.cancel(.floatAspect)
    }

    @Test("A button down during the probe's wait leaves the window alone")
    func buttonDuringProbe() {
        let core = makeCore()
        core.tiler.motionGate.quiescence.buttonsDown = { true }
        answer(core, CGSize(width: 900, height: 450))
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A moving pointer delays the judgement and the probe's answer")
    func movingPointerWaits() {
        let core = makeCore()
        let gate = core.tiler.motionGate
        gate.quiescence.sinceMouseMoved = { 0 }
        answer(core, start.size)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(core.deferred.isScheduled(.floatAspect))

        // A probe keeps its wait: no verdict, no write.
        answer(core, CGSize(width: 788, height: 443))
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(core.deferred.isScheduled(.floatAspect))
        core.deferred.cancel(.floatAspect)
    }

    @Test("A window moved during the probe stays unjudged")
    func movedDuringProbe() {
        let core = makeCore()
        core.windowServer.readWindowBounds = { [start] _ in
            start.offsetBy(dx: 40, dy: 0)
        }
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("The press judges from where the window stood, not its echo")
    func judgedFromTheShownFrame() async {
        let core = makeCore()
        core.deferred.sleep = { _ in }
        answer(core, start.size)
        core.state.windows.updateFrame(
            id,
            frame: CGRect(x: 0, y: 0, width: 500, height: 500)
        )
        press(core, -50)
        answer(core, CGSize(width: 749, height: 421))
        await core.deferred.task(for: .floatAspect)?.value
        let held = core.state.floatAspects[id]?.ratio ?? 0
        #expect(abs(held - ratio) < 0.001)
    }

    @Test("A window judged free costs no read; a locked one takes one")
    func readsOnlyWhatItNeeds() {
        let core = makeCore()
        var reads = 0
        let frame = start
        core.windowServer.readWindowBounds = { _ in
            reads += 1
            return frame
        }
        core.state.floatAspects[id] = .init(
            pid: 900_001,
            ratio: nil,
            freeAxes: ["x"]
        )
        press(core, 50)
        #expect(reads == 0)
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        press(core, 50)
        #expect(reads == 1)
    }

    @Test("A held key waits: no verdict, no probe, the slot kept")
    func glideWaits() {
        let core = makeCore()
        core.keys.holdGlide.isGliding = true
        answer(core, start.size)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(core.deferred.isScheduled(.floatAspect))
        core.keys.holdGlide.isGliding = false
        core.deferred.cancel(.floatAspect)
    }

    @Test("A glide step arms nothing")
    func glideStepArmsNothing() {
        let core = makeCore()
        answer(core, start.size)
        core.keys.holdGlide.isApplyingGlideStep = true
        press(core, 50)
        core.keys.holdGlide.isApplyingGlideStep = false
        #expect(!core.deferred.isScheduled(.floatAspect))
    }
}
