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
        core.swapHere(.window(WindowID(2)))
        expectEqual(core.state.workspaces.space(of: WindowID(2)), "1")
        expectEqual(core.state.workspaces.space(of: WindowID(1)), "2")
        expectEqual(core.state.workspaces.activeSpace, "1")
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
        core.swapHere(.window(WindowID(2)))
        expectEqual(core.state.workspaces.space(of: WindowID(2)), "2")
        #expect(recorder.logs.contains { $0.contains("denied swap_here") })
    }

    @Test("a floating side is cued as the plain fact")
    func floatingIsCued() {
        let (core, recorder) = makeCore()
        pair(core)
        track(core, 3, in: "2", floating: true)
        core.swapHere(.window(WindowID(3)))
        expectEqual(core.state.workspaces.space(of: WindowID(3)), "2")
        #expect(cued(recorder, .cannotSwapFloating))
    }

    @Test("a full-screen side is cued")
    func fullScreenIsCued() {
        let (core, recorder) = makeCore()
        pair(core)
        track(core, 3, in: "2", fullscreen: true)
        core.swapHere(.window(WindowID(3)))
        expectEqual(core.state.workspaces.space(of: WindowID(3)), "2")
        #expect(cued(recorder, .cannotSwapFullScreen(window: "")))
    }

    @Test("your own window and an empty here are cued")
    func selfAndNothingHereAreCued() {
        let (core, recorder) = makeCore()
        pair(core)
        core.swapHere(.window(WindowID(1)))
        #expect(cued(recorder, .swapWithSelf(window: "")))
        let (empty, emptyLog) = makeCore()
        track(empty, 2, in: "2")
        empty.swapHere(.window(WindowID(2)))
        expectEqual(empty.state.workspaces.space(of: WindowID(2)), "2")
        #expect(cued(emptyLog, .nothingHereToSwap))
    }

    /// Slice 1 trades tracked rows only (Ruling 5).
    @Test("a minimized or hidden-app row is cued before any verb")
    func unreachableRowsAreCued() {
        let (core, recorder) = makeCore()
        pair(core)
        core.swapHere(.window(WindowID(9)))
        #expect(cued(recorder, .cannotSwapGone))
        recorder.logs = []
        core.swapHere(.hiddenApp(900_009))
        #expect(cued(recorder, .cannotSwapHiddenApp))
        expectEqual(core.state.workspaces.space(of: WindowID(1)), "1")
    }

    /// A pocketed window is the verb's own refusal, CLI included.
    @Test("a pocketed window is cued by the verb")
    func pocketedIsCued() {
        let (core, recorder) = makeCore()
        pair(core)
        track(core, 3, in: "1")
        core.state.apply(.windowFocused(WindowID(3)))
        #expect(core.execute("pocket").isSuccess)
        #expect(core.state.isPocketed(WindowID(3)))
        core.state.workspaces.focus(WindowID(1), in: "1")
        recorder.logs = []
        let response = core.execute("swap_here", args: [.number(3)])
        expectEqual(response.error, "pocketed window 3 cannot be swapped")
        #expect(cued(recorder, .cannotSwapPocketed))
    }

    /// In no Space and not pocketed: the verb's other unfiled side.
    @Test("a window in no Space is cued as unfiled")
    func unfiledIsCued() {
        let (core, recorder) = makeCore()
        pair(core)
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(3),
                pid: getpid(),
                appName: "App",
                title: "W3"
            )
        )
        recorder.logs = []
        let response = core.execute("swap_here", args: [.number(3)])
        expectEqual(response.error, "window 3 is in no Space")
        #expect(cued(recorder, .cannotSwapUnfiled))
        #expect(!cued(recorder, .cannotSwapPocketed))
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

    /// The reason names the side that blocks (refusals ▸ 1).
    @Test("a row names whose window blocks the swap")
    func rowNamesTheSide() {
        let (core, _) = makeCore()
        pair(core)
        track(core, 3, in: "2", floating: true)
        track(core, 4, in: "2", fullscreen: true)
        func blocks() -> [JumpEntry.Target: JumpSwapBlock?] {
            Dictionary(
                uniqueKeysWithValues: core.jumpSnapshot().entries.map {
                    ($0.target, $0.swapBlock)
                }
            )
        }
        var seen = blocks()
        expectEqual(seen[.window(WindowID(3))], .floating)
        expectEqual(seen[.window(WindowID(4))], .fullScreen)
        #expect(seen[.window(WindowID(2))] == .some(nil))
        // Your own window floats: every row names yours.
        var mine = core.state.windows[WindowID(1)]
        mine?.isFloating = true
        if let mine { core.state.windows.upsert(mine) }
        seen = blocks()
        expectEqual(seen[.window(WindowID(2))], .yoursFloating)
        let moves = core.jumpSnapshot().entries.first {
            $0.target == .window(WindowID(4))
        }
        expectEqual(moves?.moveBlock, .fullScreen)
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
        expectEqual(swaps[.window(WindowID(2))], true)
        expectEqual(swaps[.window(WindowID(3))], false)
    }
}
