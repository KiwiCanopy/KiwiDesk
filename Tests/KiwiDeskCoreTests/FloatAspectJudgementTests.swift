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
    let id = WindowID(1)
    let start = CGRect(x: 400, y: 200, width: 800, height: 450)
    let ratio: CGFloat = 800.0 / 450.0

    func makeCore(floating: Bool = true) -> KiwiCore {
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

    func ask(
        _ axis: String,
        _ delta: Double,
        to asked: CGSize
    ) -> KiwiCore.FloatAspectAsk {
        KiwiCore.FloatAspectAsk(
            window: id,
            axis: axis,
            delta: delta,
            base: start,
            target: CGRect(origin: start.origin, size: asked)
        )
    }

    func answer(_ core: KiwiCore, _ size: CGSize) {
        let frame = CGRect(origin: start.origin, size: size)
        core.windowServer.readWindowBounds = { _ in frame }
    }

    func press(_ core: KiwiCore, _ delta: Double) {
        #expect(
            core.execute("resize", args: [.string("x"), .number(delta)])
                .isSuccess
        )
    }

    let grow = CGSize(width: 850, height: 450)
    let probed = CGSize(width: 788, height: 450)

    @Test("A refused grow proved by a fitted shrink locks and takes its step")
    func refusedGrowLocks() {
        let core = makeCore()
        let press = ask("x", 50, to: grow)
        answer(core, start.size)
        core.judgeFloatAspect(press)
        // The verdict is the probe's: a refused grow may be fixed size.
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id)?.size == probed)

        answer(core, CGSize(width: 788, height: 443))
        core.judgeFloatAspectProbe(press, live: start)
        let held = core.state.floatAspects[id]?.ratio ?? 0
        #expect(abs(held - ratio) < 0.001)
        // The step lands whole, measured from where the probe left it.
        let landed = core.tiler.recentInstantTarget(id)
        #expect(abs((landed?.width ?? 0) - 850) < 0.5)
        #expect(abs((landed?.height ?? 0) - 850 / ratio) < 0.5)
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

    @Test("A refused shrink proves nothing and takes no probe")
    func refusedShrinkIsUnjudged() {
        let core = makeCore()
        answer(core, start.size)
        core.judgeFloatAspect(
            ask("x", -50, to: CGSize(width: 750, height: 450))
        )
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("A locked press scales both axes from where the window is")
    func lockedPressScales() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        answer(core, start.size)
        // The echo-fed frame is stale: the seam is where the window is.
        core.state.windows.updateFrame(
            id,
            frame: CGRect(x: 0, y: 0, width: 500, height: 500)
        )
        press(core, 80)
        #expect(
            core.tiler.recentInstantTarget(id)?.size
                == CGSize(width: 880, height: 495)
        )
    }

    @Test("A locked press is instant whatever the animation toggle says")
    func lockedPressIsInstant() {
        let core = makeCore()
        core.tiler.settings.animations.onWindowResize = true
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        answer(core, start.size)
        press(core, 80)
        #expect(core.tiler.recentInstantTarget(id) != nil)
        #expect(core.tiler.animation.targetFrame(window: id) == nil)
    }

    @Test("A free window keeps its one-axis resize and is judged once")
    func compliedIsFree() {
        let core = makeCore()
        answer(core, grow)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspects[id] == .init(pid: 900_001, ratio: nil))
        #expect(core.tiler.recentInstantTarget(id) == nil)

        press(core, 50)
        #expect(core.tiler.recentInstantTarget(id)?.height == 450)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A window refusing the probe too is fixed, and goes back")
    func fixedSizeIsRecorded() {
        let core = makeCore()
        // The press walked it half a step before the probe.
        let walked = start.offsetBy(dx: -25, dy: 0)
        core.windowServer.readWindowBounds = { _ in walked }
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: walked)
        #expect(core.state.floatAspects[id]?.fixedSize == start.size)
        #expect(core.state.floatAspects[id]?.ratio == nil)
        #expect(core.tiler.recentInstantTarget(id) == start)
    }

    @Test("A fixed window's press writes nothing, either way")
    func fixedPressWritesNothing() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(
            pid: 900_001,
            ratio: nil,
            fixedSize: start.size
        )
        answer(core, start.size)
        press(core, 50)
        press(core, -50)
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(core.state.floatAspects[id]?.fixedSize == start.size)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A fixed window that changed size by itself is judged anew")
    func fixedWindowResizedIsRejudged() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(
            pid: 900_001,
            ratio: nil,
            fixedSize: CGSize(width: 230, height: 408)
        )
        answer(core, start.size)
        press(core, 50)
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id)?.width == 850)
        #expect(core.deferred.isScheduled(.floatAspect))
        core.deferred.cancel(.floatAspect)
    }

    @Test("A slow app that took the probe gets its press, and is not locked")
    func slowAppIsNotLocked() {
        let core = makeCore()
        // One axis moved: its late grow, or the probe, never a lock. The
        // press's own split frame lands, not its size at the old origin.
        answer(core, probed)
        let split = CGRect(x: 375, y: 200, width: 850, height: 450)
        let press = KiwiCore.FloatAspectAsk(
            window: id,
            axis: "x",
            delta: 50,
            base: start,
            target: split
        )
        core.judgeFloatAspectProbe(press, live: start)
        #expect(core.state.floatAspects[id] == .init(pid: 900_001, ratio: nil))
        #expect(core.tiler.recentInstantTarget(id) == split)
    }

    @Test("A probe with no answer goes back and stays unjudged")
    func probeWithNoAnswerRestores() {
        let core = makeCore()
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == start)
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

    @Test("A window that left the focus or went full screen is not judged")
    func routingStandsDown() {
        let core = makeCore()
        answer(core, CGSize(width: 749, height: 421))
        let shrink = ask("x", -50, to: CGSize(width: 750, height: 450))
        core.state.windows.setFullscreen(id, true)
        core.judgeFloatAspect(shrink)
        #expect(core.state.floatAspects[id] == nil)

        core.state.windows.setFullscreen(id, false)
        let space = core.state.workspaces.space(of: id)!
        core.state.workspaces.withSpace(space) { $0.focused = nil }
        core.judgeFloatAspect(shrink)
        #expect(core.state.floatAspects[id] == nil)
    }

    @Test("No answer from the seam judges nothing")
    func noReadJudgesNothing() {
        let core = makeCore()
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("A close ends the record, and a minimize keeps it")
    func closeEnds() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        core.handle(.windowDestroyed(id, wasMinimized: true))
        #expect(core.state.floatAspects[id] != nil)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: id,
                    pid: 900_001,
                    appName: "Player",
                    title: "W2"
                )
            )
        )
        core.handle(.windowDestroyed(id, wasMinimized: false))
        #expect(core.state.floatAspects[id] == nil)
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
