import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// KiwiHub's Swap here (#2885 ▸ Ruling 3, 5): the pick runs the
/// public `swap_here` verb, so the #292 preflight vets it and a
/// refusal is the verb's own, cued; a row this slice reaches no
/// slot for is cued before any verb runs. Windows carry the test
/// process's pid, the one app a real AX observer can watch here.
@Suite("KiwiHub Swap here (#2885)", .serialized)
@MainActor
struct JumpSwapHereTests {
    private final class Recorder {
        var logs: [String] = []
    }

    private func makeCore() -> (KiwiCore, Recorder) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let recorder = Recorder()
        core.onLog = { recorder.logs.append($0) }
        for space: SpaceID in ["1", "2"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        return (core, recorder)
    }

    private func track(
        _ core: KiwiCore,
        _ id: UInt32,
        in space: SpaceID,
        floating: Bool = false,
        fullscreen: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: getpid(),
            appName: "App",
            title: "W\(id)"
        )
        window.isFloating = floating
        window.isFullscreen = fullscreen
        core.state.windows.upsert(window)
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func entry(
        _ id: UInt32,
        status: JumpEntry.Status = .shown
    ) -> JumpEntry {
        JumpEntry(
            target: .window(WindowID(id)),
            pid: getpid(),
            app: "App",
            title: "W\(id)",
            space: nil,
            spaceIcon: nil,
            status: status
        )
    }

    private func cued(
        _ recorder: Recorder,
        _ refusal: WindowActionRefusal
    ) -> Bool {
        recorder.logs.contains { $0.contains(refusal.logReason) }
    }

    /// Mine is 1 in Space 1, focused; theirs is 2 in Space 2.
    private func pair(_ core: KiwiCore) {
        track(core, 1, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        track(core, 2, in: "2")
    }

    @Test("the pick trades slots through the preflight")
    func tradesThroughThePreflight() throws {
        let (core, _) = makeCore()
        pair(core)
        let observer = try #require(AXApplicationObserver(pid: getpid()))
        core.eventLoop.observers[getpid()] = observer
        core.frontmostPIDProvider = { getpid() }
        core.swapHere(entry(2))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "1")
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
        #expect(core.state.workspaces.activeSpace == "1")
    }

    /// The control: the preflight refuses another app in front, so
    /// the pick reached the verb and nothing beside it.
    @Test("a foreground the preflight refuses trades nothing")
    func preflightRefusalTradesNothing() throws {
        let (core, recorder) = makeCore()
        pair(core)
        let observer = try #require(AXApplicationObserver(pid: getpid()))
        core.eventLoop.observers[getpid()] = observer
        core.frontmostPIDProvider = { 1 }
        core.swapHere(entry(2))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "2")
        #expect(recorder.logs.contains { $0.contains("denied swap_here") })
    }

    @Test("a floating side is cued as the plain fact")
    func floatingIsCued() {
        let (core, recorder) = makeCore()
        pair(core)
        track(core, 3, in: "2", floating: true)
        core.swapHere(entry(3))
        #expect(core.state.workspaces.space(of: WindowID(3)) == "2")
        #expect(cued(recorder, .cannotSwapFloating))
    }

    @Test("a full-screen side is cued")
    func fullScreenIsCued() {
        let (core, recorder) = makeCore()
        pair(core)
        track(core, 3, in: "2", fullscreen: true)
        core.swapHere(entry(3))
        #expect(core.state.workspaces.space(of: WindowID(3)) == "2")
        #expect(cued(recorder, .cannotSwapFullScreen(window: "")))
    }

    @Test("your own window and an empty here are cued")
    func selfAndNothingHereAreCued() {
        let (core, recorder) = makeCore()
        pair(core)
        core.swapHere(entry(1))
        #expect(cued(recorder, .swapWithSelf(window: "")))
        let (empty, emptyLog) = makeCore()
        track(empty, 2, in: "2")
        empty.swapHere(entry(2))
        #expect(empty.state.workspaces.space(of: WindowID(2)) == "2")
        #expect(cued(emptyLog, .nothingHereToSwap))
    }

    /// Slice 1 trades tracked rows only (Ruling 5).
    @Test("a pocketed, hidden-app or untracked row is cued")
    func unreachableRowsAreCued() {
        let (core, recorder) = makeCore()
        pair(core)
        core.swapHere(entry(9, status: .minimized))
        #expect(cued(recorder, .cannotSwapHere(window: "")))
        recorder.logs = []
        core.swapHere(
            JumpEntry(
                target: .hiddenApp(900_009),
                pid: 900_009,
                app: "Hidden",
                title: "",
                space: nil,
                spaceIcon: nil,
                status: .shown
            )
        )
        #expect(cued(recorder, .cannotSwapHere(window: "")))
        #expect(core.state.workspaces.space(of: WindowID(1)) == "1")
    }

    /// The CLI draws the same cues (Ruling 5).
    @Test("the verb itself cues a float")
    func verbCues() {
        let (core, recorder) = makeCore()
        pair(core)
        track(core, 3, in: "2", floating: true)
        #expect(!core.execute("swap_here", args: [.number(3)]).isSuccess)
        #expect(cued(recorder, .cannotSwapFloating))
    }

    @Test("the row says whether it swaps")
    func rowSwapsHere() {
        let (core, _) = makeCore()
        pair(core)
        track(core, 3, in: "2", floating: true)
        let swaps = Dictionary(
            uniqueKeysWithValues: core.jumpSnapshot().entries.map {
                ($0.target, $0.swapsHere)
            }
        )
        #expect(swaps[.window(WindowID(2))] == true)
        #expect(swaps[.window(WindowID(3))] == false)
    }
}
