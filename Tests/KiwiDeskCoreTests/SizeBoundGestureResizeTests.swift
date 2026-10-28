import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A user's resize gesture unlearns only what its size contradicts
/// (#2706): the floor that caps a Grid survives the drag that grows
/// its window, so the press and the render keep one shape. An app
/// re-bounding itself still forgets outright
/// (`SizeBoundAnswerChannelTests` ▸ `genuineResizeForgets`).
@Suite("Size bounds survive a resize gesture (#2706)", .serialized)
@MainActor
struct SizeBoundGestureResizeTests {
    private let w = WindowID(2)

    /// A ledger whose width carries a 500-pt floor and whose height
    /// carries a 600-pt ceiling, each confirmed on two asks.
    private func learned() -> SizeBoundLearner {
        var learner = SizeBoundLearner()
        for asked in [CGFloat(400), CGFloat(350)] {
            for _ in 0..<2 {
                learner.recordAsk(
                    w,
                    size: CGSize(width: asked, height: asked + 400)
                )
                learner.observe(
                    w,
                    currentSize: CGSize(width: 500, height: 600),
                    settledRead: true
                )
            }
        }
        return learner
    }

    @Test("A larger size keeps the floor and drops the ceiling")
    func growKeepsTheFloor() {
        var learner = learned()
        #expect(learner.bound(for: w)?.minWidth == 500)
        #expect(learner.bound(for: w)?.maxHeight == 600)
        learner.recordAsk(w, size: CGSize(width: 300, height: 600))
        var candidate = SizeBoundLearner.Ledger()
        candidate.width = [
            EffectiveSizeBound.Axis(asked: 300, answered: 500)
        ]
        learner.candidates[w] = candidate
        let dropped = learner.gestureResized(
            w,
            to: CGSize(width: 700, height: 700)
        )
        #expect(dropped)
        #expect(learner.bound(for: w)?.minWidth == 500)
        #expect(learner.bound(for: w)?.maxHeight == nil)
        #expect(learner.lastAsks[w] == nil)
        #expect(learner.candidates[w] == nil)
    }

    @Test("A size inside every entry drops nothing")
    func insideDropsNothing() {
        var learner = learned()
        let dropped = learner.gestureResized(
            w,
            to: CGSize(width: 600, height: 500)
        )
        #expect(!dropped)
        #expect(learner.bound(for: w)?.minWidth == 500)
        #expect(learner.bound(for: w)?.maxHeight == 600)
    }

    @Test("A size inside the match tolerance keeps the floor")
    func toleranceKeepsTheFloor() {
        var learner = learned()
        let width = 500 - EffectiveSizeBound.matchTolerance / 2
        learner.gestureResized(w, to: CGSize(width: width, height: 600))
        #expect(learner.bound(for: w)?.minWidth == 500)
    }

    @Test("A pending probe goes back unissued and untrusted")
    func probeIsRetired() {
        var learner = learned()
        let anchor = EffectiveSizeBound.Axis(asked: 400, answered: 500)
        var ledger = SizeBoundLearner.ProbeLedger()
        ledger.width.pending = SizeBoundLearner.CorroborationProbe(
            anchor: anchor,
            asked: 387,
            issues: 1,
            baselineTrusted: true
        )
        learner.probes[w] = ledger
        learner.recordAsk(w, size: CGSize(width: 387, height: 800))
        learner.probes[w]?.width.pending?.baselineTrusted = true
        learner.gestureResized(w, to: CGSize(width: 700, height: 600))
        let pending = learner.probes[w]?.width.pending
        #expect(pending?.issues == 0)
        #expect(pending?.baselineTrusted == false)
    }

    @Test("A size under the floor drops it")
    func undercutDropsTheFloor() {
        var learner = learned()
        learner.gestureResized(w, to: CGSize(width: 420, height: 600))
        #expect(learner.bound(for: w)?.minWidth == nil)
        #expect(learner.bound(for: w)?.maxHeight == 600)
    }

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-gesture-heal-\(UUID().uuidString)"
                )
        )
        // 1220 × 820 less 10-pt outer gaps leaves a 1200 × 800 grid
        // with 20-pt inner gaps: three 300-pt columns fit.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1220, height: 820)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(top: 10, bottom: 10, left: 10, right: 10),
            inner: Gaps.Inner(horizontal: 20, vertical: 20)
        )
        core.tiler.animation.isEnabled = false
        core.tiler.echoGraceOverride = { _ in false }
        return core
    }

    /// Two windows in a rigid 3 × 1 grid; the second's corroborated
    /// 500-pt floor heals the cap to two columns.
    private func healedGrid(_ core: KiwiCore) {
        core.execute("grid.set_type", args: [.string("rigid")])
        core.execute(
            "grid.set_dimensions",
            args: [.number(3), .number(1)]
        )
        for id in UInt32(1)...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(910_000 + Int32(id)),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("grid")]
        )
        for asked in [CGFloat(400), CGFloat(350)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    w,
                    size: CGSize(width: asked, height: 800)
                )
                core.tiler.boundLearner.observe(
                    w,
                    currentSize: CGSize(width: 500, height: 800),
                    settledRead: true
                )
            }
        }
        core.retile()
    }

    private func width(_ core: KiwiCore, _ id: UInt32) -> CGFloat {
        core.tiler.calculatedFrames(state: core.state)[WindowID(id)]?
            .width ?? 0
    }

    @Test("A drag growing the capping window keeps Grid's cap")
    func dragKeepsTheCap() throws {
        let core = makeCore()
        healedGrid(core)
        let half: CGFloat = (1200 - 20) / 2
        #expect(abs(width(core, 2) - half) < 0.5)
        let slot = try #require(
            core.tiler.calculatedFrames(state: core.state)[w]
        )
        core.mouse.pressedButtons = { 1 }
        core.handle(
            .windowResized(
                w,
                CGRect(
                    origin: slot.origin,
                    size: CGSize(width: half + 80, height: slot.height)
                )
            )
        )
        #expect(core.tiler.sizeBound(for: w)?.minWidth == 500)
        // Three 386-pt columns would be the forgotten floor's shape.
        #expect(abs(width(core, 1) - half) < 0.5)
    }
}
