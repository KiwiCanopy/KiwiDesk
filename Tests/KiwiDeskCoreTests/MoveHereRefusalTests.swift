import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// What `move_here` answers when nothing moves (#1513 ▸ Ruling): a
/// window drawn here counts as here before anything is judged
/// movable, an app whose every other window cannot move says so
/// through Move here's own cue, and "no window matches" is owed
/// only to a text.
@MainActor
@Suite("move_here's refusals (#1513)", .serialized)
struct MoveHereRefusalTests {
    private static let bundle = "app.test.100"

    private final class Recorder {
        var logs: [String] = []
    }

    private func makeCore() -> (KiwiCore, Recorder) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let recorder = Recorder()
        core.openOrFocus.runningAppPID = { _ in 100 }
        core.openOrFocus.activate = { _ in }
        core.openOrFocus.openApp = { _, _ in true }
        core.frontmostPIDProvider = { 300 }
        core.eventLoop.shadows.focusedWindow = { _ in nil }
        core.onLog = { recorder.logs.append($0) }
        for space: SpaceID in ["1", "2", "3"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        return (core, recorder)
    }

    private func addWindow(
        _ core: KiwiCore,
        _ id: UInt32,
        space: SpaceID,
        fullscreen: Bool = false,
        sticky: StickyScope = .none
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "Notes",
            appBundleID: Self.bundle
        )
        window.isFullscreen = fullscreen
        window.stickyScope = sticky
        core.state.windows.upsert(window)
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func pick(
        _ core: KiwiCore,
        text: String? = nil
    ) -> KiwiCore.MoveHerePick {
        core.moveHerePick(bundleID: Self.bundle, into: "1", text: text)
    }

    private func refused(
        _ recorder: Recorder,
        _ refusal: WindowActionRefusal
    ) -> Bool {
        recorder.logs.contains { $0.contains(refusal.logReason) }
    }

    @Test("an app whose every window is full screen says it cannot move")
    func allFullscreenCannotMove() {
        let (core, recorder) = makeCore()
        addWindow(core, 1, space: "2", fullscreen: true)
        addWindow(core, 2, space: "3", fullscreen: true)
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(2))
        #expect(pick(core) == .unmovable(WindowID(2)))
        let response = core.execute(
            "move_here",
            args: [.string(Self.bundle)]
        )
        #expect(!response.isSuccess)
        #expect(refused(recorder, .cannotMoveHere(window: "")))
        #expect(!refused(recorder, .noTitleMatch(app: "", text: "")))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "3")
    }

    @Test("a sticky window drawn here counts as here")
    func stickyDrawnHereIsHere() {
        let (core, recorder) = makeCore()
        addWindow(core, 1, space: "2", sticky: .display)
        #expect(core.stickyMoveBlock(WindowID(1), to: "1") == .global)
        #expect(pick(core) == .allHere)
        _ = core.execute("move_here", args: [.string(Self.bundle)])
        #expect(refused(recorder, .allHere(app: "")))
    }

    @Test("one window here and one that cannot move: it cannot move")
    func hereBesideUnmovable() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "1")
        addWindow(core, 2, space: "2", fullscreen: true)
        #expect(pick(core) == .unmovable(WindowID(2)))
    }

    @Test("a movable window outranks a more recent unmovable one")
    func movableOutranksUnmovable() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2")
        addWindow(core, 2, space: "3", fullscreen: true)
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(2))
        #expect(pick(core) == .window(WindowID(1)))
    }

    @Test("no match is answered only to a text")
    func noMatchNeedsText() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2", fullscreen: true)
        #expect(pick(core, text: "inbox") == .noMatch(text: "inbox"))
        #expect(pick(core) == .unmovable(WindowID(1)))
    }
}
