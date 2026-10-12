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

/// Jump to window's Jump and Bring here (#1875), over the doors
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
        core.jump(to: .window(WindowID(1)))
        #expect(core.state.workspaces.lastFocused == WindowID(1))
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

    @Test("Bring here moves a window into this Space and focuses it")
    func bringTracked() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        #expect(core.bringHere(.window(WindowID(2))))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "1")
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }

    @Test("Bring here refuses a full-screen window and moves nothing")
    func bringRefusesFullscreen() {
        let core = makeCore()
        defer { teardown() }
        track(core, 2, in: "2", fullscreen: true)
        #expect(!core.bringHere(.window(WindowID(2))))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "2")
    }

    /// Up on Desktop 2: hopped onto the shown Desktop 1, filed
    /// into the active Space and owed the focus at its arrival.
    @Test("Bring here hops an away window over and owes it the focus")
    func bringAway() {
        let core = makeCore()
        defer { teardown() }
        park(core)
        #expect(core.bringHere(.window(WindowID(7))))
        #expect(Bridge.moves.map(\.1) == [10])
        #expect(Bridge.moves.first?.0 == [NSNumber(value: 7)])
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("1"))
        #expect(core.followFocus.owed() == WindowID(7))
    }

    @Test("without the bridge Bring here refuses an away window")
    func bringAwayNoBridge() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        park(core)
        #expect(!core.bringHere(.window(WindowID(7))))
        #expect(Bridge.moves.isEmpty)
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("2"))
    }
}
