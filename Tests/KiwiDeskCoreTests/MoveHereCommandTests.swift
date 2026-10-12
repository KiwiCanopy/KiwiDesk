import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_here <app>` (#1513): one window of an app — its most
/// recently focused — moved into the Space the user is on and
/// focused, through Jump to window's `moveHere(_:)`; an app with
/// no window takes Open or Focus's path.
@MainActor
@Suite("move_here moves one window here (#1513)", .serialized)
struct MoveHereCommandTests {
    private static let bundle = "app.test.100"

    private final class Recorder {
        var opened: [String] = []
        var activated: [pid_t] = []
        var restored: [UInt32] = []
    }

    private func makeCore(running: Bool = true) -> (KiwiCore, Recorder) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let recorder = Recorder()
        core.openOrFocus.runningAppPID = { _ in running ? 100 : nil }
        core.openOrFocus.activate = { recorder.activated.append($0) }
        core.openOrFocus.deminiaturize = { recorder.restored.append($1.raw) }
        core.openOrFocus.openApp = { id, _ in
            recorder.opened.append(id)
            return true
        }
        core.frontmostPIDProvider = { 300 }
        core.eventLoop.shadows.focusedWindow = { _ in nil }
        for space: SpaceID in ["1", "2", "3"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        return (core, recorder)
    }

    private func addWindow(
        _ core: KiwiCore,
        _ id: UInt32,
        pid: pid_t = 100,
        space: SpaceID,
        fullscreen: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "App\(pid)",
            appBundleID: pid == 100
                ? Self.bundle : "app.test.\(pid)"
        )
        window.isFullscreen = fullscreen
        core.state.windows.upsert(window)
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func run(_ core: KiwiCore) -> CommandResponse {
        core.execute("move_here", args: [.string(Self.bundle)])
    }

    @Test("the most recently focused window moves here, alone")
    func movesTheRecentOne() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2")
        addWindow(core, 2, space: "3")
        addWindow(core, 3, space: "2")
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(2))
        #expect(run(core).isSuccess)
        #expect(core.state.workspaces.space(of: WindowID(2)) == "1")
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
        #expect(core.state.workspaces.space(of: WindowID(3)) == "2")
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }

    @Test("another app's window is never chosen")
    func onlyTheNamedApp() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2")
        addWindow(core, 9, pid: 300, space: "3")
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(9))
        #expect(core.moveHereWindow(bundleID: Self.bundle) == WindowID(1))
    }

    @Test("a minimized window more recent than the rest is restored")
    func recentMinimizedIsRestored() {
        let (core, recorder) = makeCore()
        addWindow(core, 1, space: "2")
        addWindow(core, 4, space: "1")
        core.state.stampFocusRecency(WindowID(1))
        core.state.stampFocusRecency(WindowID(4))
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(4),
            wasMinimized: true,
            effects: &effects
        )
        #expect(core.moveHereWindow(bundleID: Self.bundle) == WindowID(4))
        #expect(run(core).isSuccess)
        #expect(recorder.restored == [4])
    }

    @Test("with no focus on record, the first in Space order moves")
    func freshKiwiDeskTakesTheFirst() {
        let (core, _) = makeCore()
        addWindow(core, 5, space: "3")
        addWindow(core, 6, space: "2")
        #expect(core.moveHereWindow(bundleID: Self.bundle) == WindowID(6))
    }

    @Test("an app with no window takes Open or Focus's path")
    func noWindowOpens() {
        let (core, recorder) = makeCore(running: false)
        #expect(run(core).isSuccess)
        #expect(recorder.opened == [Self.bundle])
        #expect(core.launchFollow.owed() == Self.bundle)
    }

    @Test("a refused move fails and moves nothing")
    func refusedMoveFails() {
        let (core, _) = makeCore()
        addWindow(core, 1, space: "2", fullscreen: true)
        core.state.stampFocusRecency(WindowID(1))
        #expect(!run(core).isSuccess)
        #expect(core.state.workspaces.space(of: WindowID(1)) == "2")
    }

    @Test("no bundle id is refused")
    func needsAnApp() {
        let (core, _) = makeCore()
        #expect(!core.execute("move_here", args: []).isSuccess)
    }
}
