import Foundation
import Testing

@testable import KiwiDeskCore

/// #1840: the first press of Open or Focus lands on the app's
/// most recently focused tracked window, switching to its Space
/// by command. It used to activate the app and wait for its
/// focus report, which the #1161 placement distrust refused for
/// a window the Space switch had just parked.
@MainActor
@Suite("Open or Focus pulls the most recent window (#1840)", .serialized)
struct OpenOrFocusPullTests {

    private static let bundle = "app.test.100"

    private final class Recorder { var activated: [pid_t] = [] }

    private func makeCore() -> (KiwiCore, Recorder) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        let recorder = Recorder()
        core.openOrFocus.runningAppPID = { _ in 100 }
        core.openOrFocus.activate = { recorder.activated.append($0) }
        // Another app is frontmost: the press is a pull, not a cycle.
        core.frontmostPIDProvider = { 300 }
        core.eventLoop.shadows.focusedWindow = { _ in nil }
        for space: SpaceID in ["1", "2", "3"] {
            core.state.workspaces.ensureSpace(space)
        }
        core.state.workspaces.activate("1")
        addWindow(core, 30, pid: 300, space: "1")
        return (core, recorder)
    }

    private func addWindow(
        _ core: KiwiCore,
        _ id: UInt32,
        pid: pid_t = 100,
        space: SpaceID
    ) {
        core.state.windows.upsert(
            ManagedWindow(
                id: WindowID(id),
                pid: pid,
                appName: "App\(pid)",
                appBundleID: pid == 100
                    ? Self.bundle : "app.test.\(pid)"
            )
        )
        core.state.workspaces.add(WindowID(id), to: space)
    }

    private func press(_ core: KiwiCore) -> CommandResponse {
        core.execute("pull_or_spawn", args: [.string(Self.bundle)])
    }

    @Test("A window in another Space is reached by a switch")
    func switchesToTheWindowsSpace() {
        let (core, recorder) = makeCore()
        addWindow(core, 20, space: "2")
        core.state.apply(.windowFocused(WindowID(30)))
        #expect(press(core).isSuccess)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.state.workspaces.lastFocused == WindowID(20))
        #expect(recorder.activated.isEmpty)
    }

    @Test("The most recently focused window wins over ring order")
    func mostRecentWins() {
        let (core, _) = makeCore()
        addWindow(core, 20, space: "2")
        addWindow(core, 21, space: "3")
        core.state.apply(.windowFocused(WindowID(21)))
        core.state.apply(.windowFocused(WindowID(20)))
        core.state.apply(.windowFocused(WindowID(21)))
        core.state.apply(.windowFocused(WindowID(30)))
        _ = press(core)
        #expect(core.state.workspaces.activeSpace == "3")
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }

    @Test("With no answer either, the first in ring order wins")
    func ringOrderFallback() {
        let (core, _) = makeCore()
        addWindow(core, 20, space: "2")
        addWindow(core, 21, space: "3")
        _ = press(core)
        #expect(core.state.workspaces.lastFocused == WindowID(20))
    }

    /// A fresh KiwiDesk has stamped nothing: the app's own
    /// focused window is its most recent one.
    @Test("With no recency, the app's own focused window wins")
    func appFocusFallback() {
        let (core, _) = makeCore()
        addWindow(core, 20, space: "2")
        addWindow(core, 21, space: "3")
        core.eventLoop.shadows.focusedWindow = { _ in WindowID(21) }
        _ = press(core)
        #expect(core.state.workspaces.lastFocused == WindowID(21))
    }

    @Test("Recency outranks the app's own focused window")
    func recencyOutranksAppFocus() {
        let (core, _) = makeCore()
        addWindow(core, 20, space: "2")
        addWindow(core, 21, space: "3")
        core.state.apply(.windowFocused(WindowID(20)))
        core.eventLoop.shadows.focusedWindow = { _ in WindowID(21) }
        _ = press(core)
        #expect(core.state.workspaces.lastFocused == WindowID(20))
    }

    @Test("A closed window's recency ends with it")
    func destroyEndsRecency() {
        let (core, _) = makeCore()
        addWindow(core, 20, space: "2")
        core.state.apply(.windowFocused(WindowID(20)))
        #expect(core.state.focusRecencyRank(of: WindowID(20)) > 0)
        core.state.apply(
            .windowDestroyed(WindowID(20), wasMinimized: false)
        )
        #expect(core.state.focusRecency[WindowID(20)] == nil)
    }

    @Test("With no tracked window the app is activated as before")
    func untrackedAppActivates() {
        let (core, recorder) = makeCore()
        core.openOrFocus.census = { _ in
            KiwiCore.AppWindowCensus(visible: 1, minimized: [])
        }
        _ = press(core)
        #expect(recorder.activated == [100])
    }
}
