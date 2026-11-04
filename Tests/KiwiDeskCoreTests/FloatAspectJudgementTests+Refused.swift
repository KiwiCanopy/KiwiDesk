import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A float's refused asks (#2973): where a press leaves the window, and
/// how a refusal ends.
extension FloatAspectJudgementTests {
    private func refusedOnX(_ core: KiwiCore) {
        core.state.floatAspects[id] = .init(
            pid: 900_001,
            ratio: nil,
            refusedAsks: ["x+", "x-"],
            refusedSize: start.size
        )
        answer(core, start.size)
    }

    @Test("A refused press keeps its place, keeps asking, leaves the ring")
    func refusedPressKeepsItsPlace() {
        let core = makeCore()
        refusedOnX(core)
        press(core, 50)
        #expect(
            core.tiler.placements.recent(id)
                == CGRect(origin: start.origin, size: grow)
        )
        #expect(core.tiler.recentInstantTarget(id) == nil)
        press(core, -50)
        #expect(core.tiler.placements.recent(id)?.origin == start.origin)
        #expect(core.state.floatAspects[id]?.refusedAsks == ["x+", "x-"])
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A refused press asks within the region and the floor")
    func refusedPressIsBounded() {
        let core = makeCore()
        refusedOnX(core)
        press(core, 5000)
        #expect(
            core.tiler.placements.recent(id)?.width
                == core.floatGrowBounds(of: id)?.width
        )
        press(core, -5000)
        let floor = core.plannedMinSize(of: id, axis: "x")
        #expect(core.tiler.placements.recent(id)?.width == CGFloat(floor))
    }

    @Test("The other axis of a refused window resizes and is judged")
    func otherAxisStillResizes() {
        let core = makeCore()
        refusedOnX(core)
        #expect(
            core.execute("resize", args: [.string("y"), .number(50)])
                .isSuccess
        )
        #expect(core.tiler.recentInstantTarget(id)?.height == 500)
        #expect(core.deferred.isScheduled(.floatAspect))
        core.deferred.cancel(.floatAspect)
    }

    @Test("Free on the other axis keeps the refusal, at its new size")
    func freeKeepsTheRefusedAxis() {
        let core = makeCore()
        refusedOnX(core)
        let taller = CGSize(width: 800, height: 500)
        answer(core, taller)
        core.judgeFloatAspect(ask("y", 50, to: taller))
        #expect(core.state.floatAspects[id]?.refusedAsks == ["x+", "x-"])
        #expect(core.state.floatAspects[id]?.refusedSize == taller)
        #expect(core.state.floatAspects[id]?.freeAxes == ["y"])
    }

    @Test("A window that left the refused size is judged anew, axes kept")
    func complyingEndsTheRefusal() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(
            pid: 900_001,
            ratio: nil,
            freeAxes: ["y"],
            refusedAsks: ["x+", "x-"],
            refusedSize: CGSize(width: 230, height: 408)
        )
        answer(core, start.size)
        press(core, 50)
        #expect(core.state.floatAspects[id]?.refusedAsks == [])
        #expect(core.state.floatAspects[id]?.freeAxes == ["y"])
        #expect(core.tiler.recentInstantTarget(id)?.width == 850)
        #expect(core.deferred.isScheduled(.floatAspect))
        core.deferred.cancel(.floatAspect)
    }

    @Test("A glide step on a refused ask takes no write")
    func refusedGlideStepWritesNothing() {
        let core = makeCore()
        refusedOnX(core)
        core.keys.holdGlide.isApplyingGlideStep = true
        press(core, 50)
        core.keys.holdGlide.isApplyingGlideStep = false
        #expect(core.tiler.placements.recent(id) == nil)
    }
}
