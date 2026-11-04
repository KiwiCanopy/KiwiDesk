import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Judging a float's aspect lock from its answers (#2973), through
/// the real `resize` and the judgement's two named bodies, each
/// driven with the frame the WindowServer seam answers.
@MainActor
@Suite("Float aspect judgement (#2973)")
struct FloatAspectJudgementTests {
    private let id = WindowID(1)
    private let start = CGRect(x: 400, y: 200, width: 800, height: 450)

    private func makeCore(floating: Bool = true) -> KiwiCore {
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent("kiwi-aspect-\(UUID().uuidString)")
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.tiler.settings.animations.onWindowResize = false
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 900_001,
                    appName: "Player",
                    frame: start,
                    isFloating: floating
                )
            )
        )
        let space = core.state.workspaces.space(of: id)!
        core.state.workspaces.focus(id, in: space)
        return core
    }

    private func ask(_ axis: String, _ delta: Double, to asked: CGSize)
        -> KiwiCore.FloatAspectAsk
    {
        KiwiCore.FloatAspectAsk(
            window: id,
            axis: axis,
            delta: delta,
            base: start,
            asked: asked
        )
    }

    private func answer(_ core: KiwiCore, _ size: CGSize) {
        let frame = CGRect(origin: start.origin, size: size)
        core.windowServer.readWindowBounds = { _ in frame }
    }

    @Test("A refused grow proved by a fitted shrink locks and takes its step")
    func refusedGrowLocks() {
        let core = makeCore()
        let press = ask("x", 50, to: CGSize(width: 850, height: 450))
        answer(core, start.size)
        core.judgeFloatAspect(press)
        // The verdict is the probe's: a refused grow may be fixed size.
        #expect(core.state.floatAspects[id] == nil)
        let probe = core.tiler.recentInstantTarget(id)
        #expect(probe?.size == CGSize(width: 788, height: 450))

        answer(core, CGSize(width: 788, height: 443))
        core.judgeFloatAspectProbe(press, live: start, probe: probe!)
        let held = core.state.floatAspects[id]?.ratio ?? 0
        #expect(abs(held - 800.0 / 450.0) < 0.001)
        // The step lands whole, measured from where the probe left it.
        let landed = core.tiler.recentInstantTarget(id)
        #expect(landed?.size == CGSize(width: 850, height: 478))
    }

    @Test("A shrink fitted inside its box locks with no probe")
    func fittedShrinkLocks() {
        let core = makeCore()
        answer(core, CGSize(width: 749, height: 421))
        core.judgeFloatAspect(
            ask("x", -50, to: CGSize(width: 750, height: 450))
        )
        #expect(core.state.floatAspects[id]?.ratio != nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("A locked window's press scales both axes from its real frame")
    func lockedPressScales() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: 800.0 / 450.0)
        answer(core, start.size)
        // The echo-fed frame is stale: the seam is where the window is.
        core.state.windows.updateFrame(
            id,
            frame: CGRect(x: 0, y: 0, width: 500, height: 500)
        )
        #expect(
            core.execute("resize", args: [.string("x"), .number(80)]).isSuccess
        )
        #expect(
            core.tiler.recentInstantTarget(id)?.size
                == CGSize(width: 880, height: 495)
        )
    }

    @Test("A free window keeps its one-axis resize and is judged once")
    func compliedIsFree() {
        let core = makeCore()
        let target = CGSize(width: 850, height: 450)
        answer(core, target)
        core.judgeFloatAspect(ask("x", 50, to: target))
        #expect(core.state.floatAspects[id] == .init(pid: 900_001, ratio: nil))
        #expect(core.tiler.recentInstantTarget(id) == nil)

        #expect(
            core.execute("resize", args: [.string("x"), .number(50)]).isSuccess
        )
        #expect(core.tiler.recentInstantTarget(id)?.height == 450)
        #expect(core.deferred.task(for: .floatAspect) == nil)
    }

    @Test("A fixed-size window fails the probe and is left free")
    func fixedSizeIsFree() {
        let core = makeCore()
        let press = ask("x", 50, to: CGSize(width: 850, height: 450))
        let probe = CGRect(
            origin: start.origin,
            size: CGSize(width: 788, height: 450)
        )
        answer(core, start.size)
        core.judgeFloatAspectProbe(press, live: start, probe: probe)
        #expect(core.state.floatAspects[id]?.ratio == nil)
        #expect(core.state.floatAspects[id] != nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("A window that took the probe goes back and is never locked")
    func slowAppIsNotLocked() {
        let core = makeCore()
        let press = ask("x", 50, to: CGSize(width: 850, height: 450))
        let probe = CGRect(
            origin: start.origin,
            size: CGSize(width: 788, height: 450)
        )
        // The late grow of a slow app, not a lock: one axis moved.
        answer(core, probe.size)
        core.judgeFloatAspectProbe(press, live: start, probe: probe)
        #expect(core.state.floatAspects[id]?.ratio == nil)
        #expect(core.tiler.recentInstantTarget(id) == start)
    }

    @Test("A press arms the judgement once; a judged window arms none")
    func pressArms() {
        let core = makeCore()
        _ = core.execute("resize", args: [.string("x"), .number(50)])
        #expect(core.deferred.task(for: .floatAspect) != nil)
        core.deferred.cancel(.floatAspect)
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: nil)
        _ = core.execute("resize", args: [.string("x"), .number(50)])
        #expect(core.deferred.task(for: .floatAspect) == nil)
    }

    @Test("A window no longer floating is not judged")
    func tiledIsNotJudged() {
        let core = makeCore(floating: false)
        answer(core, CGSize(width: 749, height: 421))
        core.judgeFloatAspect(
            ask("x", -50, to: CGSize(width: 750, height: 450))
        )
        #expect(core.state.floatAspects[id] == nil)
    }

    @Test("No answer from the seam judges nothing")
    func noReadJudgesNothing() {
        let core = makeCore()
        core.judgeFloatAspect(
            ask("x", 50, to: CGSize(width: 850, height: 450))
        )
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("The record ends with the app and follows a re-key")
    func recordLifetime() {
        var state = StateCoordinator()
        let other = WindowID(2)
        state.floatAspects[id] = .init(pid: 7, ratio: 1.5)
        state.rekey(id, to: other)
        #expect(state.floatAspects[id] == nil)
        #expect(state.floatAspects[other]?.ratio == 1.5)
        state.apply(.appTerminated(pid: 7))
        #expect(state.floatAspects[other] == nil)
    }

    @Test("Retiring an away window ends the record")
    func awayRetires() {
        var state = StateCoordinator()
        state.floatAspects[id] = .init(pid: 7, ratio: 1.5)
        state.forgetAway(id)
        #expect(state.floatAspects[id] == nil)
    }
}
