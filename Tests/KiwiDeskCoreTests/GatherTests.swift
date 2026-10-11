import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []

    static func reset() { moves = [] }
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

/// `gather` (#1510): every window of an app into the Space the
/// user is on — tracked ones filed in the Space Bar's reading
/// order, a native fullscreen window left in its own Space, an
/// away one (#1146) re-pointed at the target and moved onto the
/// shown Desktop over the bridge. Nothing launches: an app with
/// nothing to gather refuses. The topology is the #888 fixture:
/// Desktops 1–2 on `UUID-A` (ids 10, 11).
@Suite("gather (#1510)", .serialized)
@MainActor
struct GatherTests {
    private let bundle = "app.test.notes"
    private let pid: pid_t = 100

    private func makeCore(bridge: Bool = true) -> KiwiCore {
        Bridge.reset()
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
        for space in ["1", "2", "3"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.activate("1")
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func window(
        _ core: KiwiCore,
        _ id: UInt32,
        in space: String,
        bundleID: String? = nil,
        fullscreen: Bool = false
    ) {
        var window = ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "Notes",
            appBundleID: bundleID ?? bundle
        )
        window.isFullscreen = fullscreen
        core.state.apply(.windowCreated(window))
        core.state.workspaces.add(WindowID(id), to: SpaceID(space))
    }

    @Test("the app's windows come into the active Space, in order")
    func gathersTracked() {
        let core = makeCore()
        defer { teardown() }
        window(core, 1, in: "1", bundleID: "app.test.other")
        window(core, 3, in: "3")
        window(core, 2, in: "2")
        window(core, 4, in: "2")
        window(core, 5, in: "3", bundleID: "app.test.other")
        let response = core.execute("gather", args: [.string(bundle)])
        #expect(response.isSuccess)
        let active = core.state.workspaces[SpaceID("1")]?.windows
        #expect(
            active == [WindowID(1), WindowID(2), WindowID(4), WindowID(3)]
        )
        #expect(core.state.workspaces.space(of: WindowID(5)) == "3")
    }

    @Test("a native fullscreen window keeps its own Space")
    func fullscreenStays() {
        let core = makeCore()
        defer { teardown() }
        window(core, 2, in: "2")
        window(core, 3, in: "3", fullscreen: true)
        #expect(core.execute("gather", args: [.string(bundle)]).isSuccess)
        #expect(core.state.workspaces.space(of: WindowID(2)) == "1")
        #expect(core.state.workspaces.space(of: WindowID(3)) == "3")
    }

    @Test("nothing to gather refuses and launches nothing")
    func nothingRefuses() {
        let core = makeCore()
        defer { teardown() }
        window(core, 1, in: "1")
        let response = core.execute("gather", args: [.string(bundle)])
        #expect(!response.isSuccess)
        #expect(Bridge.moves.isEmpty)
    }

    /// Up on Desktop 2: re-pointed at the active Space, so its
    /// arrival files there, and moved onto the shown Desktop 1.
    @Test("an away window is moved here, never switched to")
    func hopsAwayWindow() {
        let core = makeCore()
        defer { teardown() }
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle,
            nativeSpace: 11
        )
        core.state.rememberedSpaces[WindowID(7)] = .departed("2")
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: [
                    WindowID(7): DesktopCensus.Host(
                        space: 11,
                        pid: self.pid,
                        isUp: true
                    )
                ],
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
        #expect(core.execute("gather", args: [.string(bundle)]).isSuccess)
        #expect(Bridge.moves.map(\.1) == [10])
        #expect(Bridge.moves.first?.0 == [NSNumber(value: 7)])
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("1"))
        #expect(core.deferred.isScheduled(.awayReachReap))
    }

    @Test("without the bridge an away window is left where it is")
    func noBridgeNoHop() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle,
            nativeSpace: 11
        )
        let response = core.execute("gather", args: [.string(bundle)])
        #expect(!response.isSuccess)
        #expect(Bridge.moves.isEmpty)
    }
}
