import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The judgement on the y axis, on a second window, and against answers
/// that prove nothing; and a locked press's own reads (#2973). Each case
/// closes a mutation that survived the first proof of this suite.
extension FloatAspectJudgementTests {
    private func addSecondFloat(_ core: KiwiCore) -> WindowID {
        let other = WindowID(2)
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: other,
                    pid: 900_002,
                    appName: "Other",
                    frame: CGRect(x: 0, y: 0, width: 600, height: 400),
                    isFloating: true
                )
            )
        )
        return other
    }

    private func focus(_ core: KiwiCore, _ window: WindowID) {
        let space = core.state.workspaces.space(of: window)!
        core.state.workspaces.focus(window, in: space)
    }

    private func pressY(_ core: KiwiCore, _ delta: Double) {
        #expect(
            core.execute("resize", args: [.string("y"), .number(delta)])
                .isSuccess
        )
    }

    private var broken: CGSize { CGSize(width: 860, height: 400) }

    /// The floor leaves the frame as it stands, so the writer's own
    /// truncation arm is what cues (#3018).
    @Test("A locked float at its floor cues on either axis")
    func floorCuesOnBothAxes() {
        for axis in ["x", "y"] {
            let core = makeCore()
            core.execute(
                "set_min_window_size",
                args: [.number(Double(start.width))]
            )
            core.state.floatAspects[id] = .init(
                pid: 900_001,
                ratio: start.width / start.height
            )
            var refusals: [ResizeRefusal] = []
            core.borders.onResizeRefusal = { refusals.append($0) }
            #expect(
                core.execute("resize", args: [.string(axis), .number(-50)])
                    .isSuccess
            )
            #expect(refusals.count == 1)
            guard case .ownMinimum = refusals.first else {
                Issue.record("expected the window's own minimum")
                continue
            }
        }
    }

    @Test("A broken ratio answer files nothing")
    func otherIsUnjudged() {
        let core = makeCore()
        answer(core, broken)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspects[id] == nil)
    }

    @Test("A broken ratio answer to the probe holds no lock, takes the ask")
    func probeOtherIsFree() {
        let core = makeCore()
        answer(core, broken)
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspects[id] == .init(pid: 900_001, ratio: nil))
        #expect(
            core.tiler.recentInstantTarget(id)
                == CGRect(origin: start.origin, size: grow)
        )
    }

    /// The press's size-led write held the origin, so the split
    /// is still owed with the size (#2981).
    @Test("A slow app's asked size takes the press's split too")
    func probeOtherTakesTheSplit() {
        let core = makeCore()
        answer(core, broken)
        let split = CGRect(x: 375, y: 200, width: 850, height: 450)
        core.judgeFloatAspectProbe(
            KiwiCore.FloatAspectAsk(
                window: id,
                axis: "x",
                delta: 50,
                base: start,
                target: split
            ),
            live: start
        )
        #expect(core.tiler.recentInstantTarget(id) == split)
    }

    /// A cell grid answers short of the ask, and the write put its
    /// origin that far along the line; no hand moved it (#2981).
    @Test("A partial answer at its own origin is judged, not a hand's")
    func partialAnswerIsJudged() {
        let core = makeCore()
        let target = CGRect(x: 375, y: 200, width: 850, height: 450)
        let partial = CGRect(x: 390, y: 200, width: 820, height: 450)
        core.windowServer.readWindowBounds = { _ in partial }
        core.judgeFloatAspect(
            KiwiCore.FloatAspectAsk(
                window: id,
                axis: "x",
                delta: 50,
                base: start,
                target: target
            )
        )
        #expect(core.state.floatAspects[id] == .init(pid: 900_001, ratio: nil))
    }

    @Test("A window sent to the press's own split origin is judged")
    func targetOriginIsNotMoved() {
        let core = makeCore()
        let split = CGRect(x: 375, y: 200, width: 850, height: 450)
        core.windowServer.readWindowBounds = { _ in split }
        core.judgeFloatAspect(
            KiwiCore.FloatAspectAsk(
                window: id,
                axis: "x",
                delta: 50,
                base: start,
                target: split
            )
        )
        #expect(core.state.floatAspects[id] == .init(pid: 900_001, ratio: nil))
    }

    @Test("A probe on y shrinks the height alone")
    func probeOnY() {
        let core = makeCore()
        answer(core, start.size)
        core.judgeFloatAspect(
            ask("y", 50, to: CGSize(width: 800, height: 500))
        )
        #expect(
            core.tiler.recentInstantTarget(id)?.size
                == CGSize(width: 800, height: 438)
        )
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }

    @Test("A lock proved on y takes its step whole, from where the probe left")
    func lockOnYTakesItsStep() {
        let core = makeCore()
        answer(core, CGSize(width: 779, height: 438))
        core.judgeFloatAspectProbe(
            ask("y", 45, to: CGSize(width: 800, height: 495)),
            live: start
        )
        let landed = core.tiler.recentInstantTarget(id)
        #expect(abs((landed?.height ?? 0) - 495) < 0.5)
        #expect(abs((landed?.width ?? 0) - 880) < 0.5)
    }

    @Test("A window gone full screen in the probe's wait is left unjudged")
    func probeRouteStandsDown() {
        let core = makeCore()
        core.state.windows.setFullscreen(id, true)
        answer(core, probed)
        core.judgeFloatAspectProbe(ask("x", 50, to: grow), live: start)
        #expect(core.state.floatAspects[id] == nil)
        #expect(core.tiler.recentInstantTarget(id) == nil)
    }

    @Test("A probe waits only the window it is on")
    func probeLetsOtherWindowsResize() {
        let core = makeCore()
        let other = addSecondFloat(core)
        focus(core, id)
        answer(core, start.size)
        press(core, 50)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.state.floatAspectFlight == .probing(id))
        focus(core, other)
        press(core, 50)
        #expect(core.tiler.recentInstantTarget(other) != nil)
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }

    @Test("Another window's press on the other axis leaves the ask alone")
    func voidReadsTheWindow() {
        let core = makeCore()
        let other = addSecondFloat(core)
        focus(core, id)
        answer(core, start.size)
        press(core, 50)
        let armed = core.deferred.task(for: .floatAspect)
        #expect(armed != nil)
        focus(core, other)
        pressY(core, 50)
        #expect(core.deferred.task(for: .floatAspect) == armed)
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }

    @Test("A press the other way voids an ask it has undone")
    func oppositePressVoids() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        #expect(core.deferred.isScheduled(.floatAspect))
        press(core, -50)
        #expect(!core.deferred.isScheduled(.floatAspect))
        #expect(core.state.floatAspectFlight == nil)
    }

    @Test("A press the same way keeps the ask")
    func samePressKeeps() {
        let core = makeCore()
        answer(core, start.size)
        press(core, 50)
        let armed = core.deferred.task(for: .floatAspect)
        press(core, 50)
        #expect(core.deferred.task(for: .floatAspect) == armed)
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }

    @Test("A locked window's press arms nothing")
    func lockedArmsNothing() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        answer(core, start.size)
        press(core, 80)
        #expect(!core.deferred.isScheduled(.floatAspect))
    }

    @Test("A locked press takes a new video's ratio, and keeps it")
    func lockedTakesANewRatio() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        let wide = CGSize(width: 800, height: 333)
        answer(core, wide)
        press(core, 80)
        let held = core.state.floatAspects[id]?.ratio ?? 0
        #expect(abs(held - 800.0 / 333.0) < 0.001)
        let landed = core.tiler.recentInstantTarget(id)
        #expect(abs((landed?.height ?? 0) - 880 / held) < 0.5)
    }

    @Test("A locked press on y scales both axes too")
    func lockedPressOnY() {
        let core = makeCore()
        core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
        answer(core, start.size)
        pressY(core, 45)
        let landed = core.tiler.recentInstantTarget(id)
        #expect(abs((landed?.width ?? 0) - 880) < 0.5)
        #expect(abs((landed?.height ?? 0) - 495) < 0.5)
    }

    @Test("A locked shrink stops at each axis's own floor")
    func lockedFloors() {
        for (width, height, expected) in [
            (600.0, 100.0, 600.0),
            (100.0, 300.0, 300.0 * 800.0 / 450.0),
        ] {
            let core = makeCore()
            #expect(
                core.execute(
                    "set_min_window_size",
                    args: [
                        .number(width), .number(height), .string("floating"),
                    ]
                ).isSuccess
            )
            core.state.floatAspects[id] = .init(pid: 900_001, ratio: ratio)
            answer(core, start.size)
            press(core, -700)
            let landed = core.tiler.recentInstantTarget(id)?.width ?? 0
            #expect(abs(landed - expected) < 0.5)
        }
    }

    @Test("A key held before its glide starts delays the judgement")
    func heldKeyWaits() {
        let core = makeCore()
        let glide = core.keys.holdGlide
        glide.releaseCapable = true
        glide.schedule = { _, _ in {} }
        _ = glide.beginFire()
        glide.noteCommand(
            "resize",
            args: [.string("x"), .number(50)],
            succeeded: true
        )
        glide.endFire(id: 1)
        #expect(glide.heldID == 1)
        #expect(!glide.isGliding)
        answer(core, start.size)
        core.judgeFloatAspect(ask("x", 50, to: grow))
        #expect(core.tiler.recentInstantTarget(id) == nil)
        #expect(core.deferred.isScheduled(.floatAspect))
        core.deferred.cancel(.floatAspect)
        core.state.floatAspectFlight = nil
    }
}
