import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []
}

private final class FakePlistArrayResult: NSObject {
    @objc let propertyListArray: [[String: Any]]
    init(propertyListArray: [[String: Any]]) {
        self.propertyListArray = propertyListArray
    }
}

private final class FakeCopyManagedDisplaySpaces: NSObject {
    @objc override init() {}
    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        FakePlistArrayResult(propertyListArray: [["Spaces": []]])
    }
}

private final class FakeMoveWindows: NSObject {
    private let windows: [NSNumber]
    private let space: UInt64

    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {
        self.windows = windows
        space = spaceID
    }

    @objc func performWithWMBridgeDelegate() {
        Bridge.moves.append((windows, space))
    }
}

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self,
    "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self,
]

// MARK: - Suite

/// Jump to window's Jump and Move here (#1875), over the doors
/// they reuse: the Space Bar pick, the away reach, the restore,
/// `move_to_space` and gather's hop. Topology: the #888 fixture.
@Suite("Jump to window actions (#1875)", .serialized)
@MainActor
struct JumpActionsTests {
    private let pid: pid_t = 100
    private let bundle = "app.test.notes"

    private func makeCore(bridge: Bool = true) -> KiwiCore {
        Bridge.moves = []
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { name in
            bridge ? bridgeClasses[name] : nil
        }
        let core = makeTestCore()
        for space in ["1", "2"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func track(
        _ core: KiwiCore,
        _ id: UInt32,
        in space: String,
        fullscreen: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle
        )
        window.isFullscreen = fullscreen
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: SpaceID(space))
    }

    private func park(_ core: KiwiCore) {
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle,
            nativeSpace: 11
        )
        core.state.rememberedSpaces[WindowID(7)] = .departed("2")
        let host = DesktopCensus.Host(space: 11, pid: pid, isUp: true)
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: [WindowID(7): host],
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
    }

    @Test("a window here takes the focus")
    func jumpHere() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 2, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.jump(to: .window(WindowID(2)))
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }

    @Test("a window on another Space switches there")
    func jumpSwitches() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        core.jump(to: .window(WindowID(2)))
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.state.workspaces["2"]?.focused == WindowID(2))
    }

    @Test("a minimized window is restored, then its app brought forward")
    func jumpRestores() {
        let core = makeCore()
        defer { teardown() }
        track(core, 4, in: "1")
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(4),
            wasMinimized: true,
            effects: &effects
        )
        var calls: [String] = []
        core.openOrFocus.deminiaturize = { calls.append("restore \($1.raw)") }
        core.openOrFocus.activate = { calls.append("activate \($0)") }
        core.jump(to: .window(WindowID(4)))
        #expect(calls == ["restore 4", "activate \(pid)"])
        // An un-minimize is an open: the launch follow is owed.
        #expect(core.launchFollow.owed() == bundle)
    }

    @Test("a hidden app is brought forward")
    func jumpUnhides() {
        let core = makeCore()
        defer { teardown() }
        var activated: [pid_t] = []
        core.openOrFocus.activate = { activated.append($0) }
        core.jump(to: .hiddenApp(300))
        #expect(activated == [300])
    }

    @Test("Move here moves a window into this Space and focuses it")
    func bringTracked() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        #expect(core.moveHere(.window(WindowID(2))))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }

    @Test("Move here refuses a full-screen window and moves nothing")
    func bringRefusesFullscreen() {
        let core = makeCore()
        defer { teardown() }
        track(core, 2, in: "2", fullscreen: true)
        #expect(!core.moveHere(.window(WindowID(2))))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "2")
    }

    /// Up on Desktop 2: hopped onto the shown Desktop 1, filed
    /// into the active Space and owed the focus at its arrival.
    @Test("Move here hops an away window over and owes it the focus")
    func bringAway() {
        let core = makeCore()
        defer { teardown() }
        park(core)
        #expect(core.moveHere(.window(WindowID(7))))
        #expect(Bridge.moves.map(\.1) == [10])
        #expect(Bridge.moves.first?.0 == [NSNumber(value: 7)])
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("1"))
        #expect(core.jump.owed?.window == WindowID(7))
        #expect(core.followFocus.owed() == nil)
    }

    @Test("without the bridge Move here refuses an away window")
    func bringAwayNoBridge() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        park(core)
        #expect(!core.moveHere(.window(WindowID(7))))
        #expect(Bridge.moves.isEmpty)
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("2"))
    }

    private func minimize(_ core: KiwiCore, _ id: UInt32) {
        var effects = AppliedEffects()
        core.state.applyWindowDestroyed(
            WindowID(id),
            wasMinimized: true,
            effects: &effects
        )
    }

    private func arrive(_ core: KiwiCore, _ id: UInt32) {
        core.handle(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid,
                    appName: "Notes",
                    appBundleID: bundle
                )
            )
        )
    }

    @Test("a full-screen window's app is brought forward")
    func jumpFullscreenActivates() {
        let core = makeCore()
        defer { teardown() }
        track(core, 3, in: "2", fullscreen: true)
        var activated: [pid_t] = []
        core.openOrFocus.activate = { activated.append($0) }
        core.jump(to: .window(WindowID(3)))
        #expect(activated == [pid])
        #expect(core.state.workspaces.activeSpace == "1")
    }

    /// No bridge to reach the Desktop: the app comes forward
    /// rather than the pick doing nothing.
    @Test("an away window that cannot be reached activates its app")
    func jumpAwayFallsBack() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        park(core)
        var activated: [pid_t] = []
        core.openOrFocus.activate = { activated.append($0) }
        core.jump(to: .window(WindowID(7)))
        #expect(activated == [pid])
    }

    @Test("Move here on a hidden app brings it forward")
    func moveHereHiddenApp() {
        let core = makeCore()
        defer { teardown() }
        var activated: [pid_t] = []
        core.openOrFocus.activate = { activated.append($0) }
        #expect(core.moveHere(.hiddenApp(300)))
        #expect(activated == [300])
    }

    /// Filed for here, restored, and focused at its arrival —
    /// through the real fold and the arrival arm.
    @Test("Move here restores a minimized window here, focused")
    func moveHereMinimized() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 4, in: "2")
        minimize(core, 4)
        var restored: [WindowID] = []
        core.openOrFocus.deminiaturize = { restored.append($1) }
        #expect(core.moveHere(.window(WindowID(4))))
        #expect(restored == [WindowID(4)])
        arrive(core, 4)
        #expect(core.state.workspaces.space(of: WindowID(4)) == "1")
        #expect(core.state.workspaces.lastFocused == WindowID(4))
        #expect(core.jump.owed == nil)
    }

    /// The user went on to another Space before the window came:
    /// the arrival pays nothing and pulls nobody back.
    @Test("a Space switch before the arrival stands the focus down")
    func moveHereFocusStandsDown() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        track(core, 4, in: "1")
        minimize(core, 4)
        core.openOrFocus.deminiaturize = { _, _ in }
        #expect(core.moveHere(.window(WindowID(4))))
        core.state.workspaces.activate("2")
        core.state.workspaces.focus(WindowID(2), in: "2")
        arrive(core, 4)
        #expect(core.state.workspaces.activeSpace == "2")
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        #expect(core.jump.owed == nil)
    }

    /// The hop's arrival pays the focus, with no Space switch.
    @Test("an away window moved here is focused when it arrives")
    func moveHereAwayPaysAtArrival() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        park(core)
        #expect(core.moveHere(.window(WindowID(7))))
        arrive(core, 7)
        #expect(core.state.workspaces.space(of: WindowID(7)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.state.workspaces.lastFocused == WindowID(7))
    }
}
