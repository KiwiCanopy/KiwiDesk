import CoreGraphics
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

/// Move here files into the Space shown on the screen KiwiHub
/// opened on, not the focused screen's (#2791). Topology: the
/// #888 fixture — Space 1 on screen 1 (Desktop 10 shown), Space 5
/// on screen 2 (Desktop 20 shown, Desktop 21 away).
@Suite("Move here targets KiwiHub's screen (#2791)", .serialized)
@MainActor
struct JumpMoveHereScreenTests {
    private let pid: pid_t = 900_100
    private let bundle = "app.test.notes"

    private func makeCore() -> KiwiCore {
        Bridge.moves = []
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { bridgeClasses[$0] }
        let core = makeTestCore()
        for (id, name) in [(1, "A"), (2, "B")] {
            core.state.workspaces.upsertDisplay(
                Display(id: DisplayID(UInt32(id)), name: name, frame: .zero)
            )
        }
        for space in ["1", "2", "5"] {
            core.state.workspaces.ensureSpace(SpaceID(space))
        }
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("2", to: DisplayID(1))
        core.state.workspaces.assign("5", to: DisplayID(2))
        core.state.workspaces.activate("1")
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func window(_ id: UInt32) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle
        )
    }

    private func track(_ core: KiwiCore, _ id: UInt32, in space: String) {
        core.state.apply(.windowCreated(window(id)))
        core.state.workspaces.add(WindowID(id), to: SpaceID(space))
    }

    /// Up on screen 2's away Desktop 21, remembered in Space 2.
    private func park(_ core: KiwiCore) {
        core.state.awayWindows[WindowID(7)] = AwayWindow(
            id: WindowID(7),
            pid: pid,
            appName: "Notes",
            appBundleID: bundle,
            nativeSpace: 21
        )
        core.state.rememberedSpaces[WindowID(7)] = .departed("2")
        let host = DesktopCensus.Host(space: 21, pid: pid, isUp: true)
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: [WindowID(7): host],
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
    }

    @Test("a tracked window lands in KiwiHub's screen's Space")
    func trackedLandsOnThePanelScreen() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        track(core, 2, in: "2")
        #expect(core.moveHere(.window(WindowID(2)), on: DisplayID(2)))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "5")
        #expect(core.state.workspaces.activeSpace == "5")
        #expect(core.state.workspaces.lastFocused == WindowID(2))
    }

    /// A refusal switches nothing: the gate runs before the switch.
    @Test("a refused Move here leaves the focused screen active")
    func refusalSwitchesNothing() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        var fullscreen = window(3)
        fullscreen.isFullscreen = true
        core.state.apply(.windowCreated(fullscreen))
        core.state.workspaces.add(WindowID(3), to: "2")
        #expect(!core.moveHere(.window(WindowID(3)), on: DisplayID(2)))
        #expect(core.state.workspaces.activeSpace == "1")
        #expect(core.state.workspaces.space(of: WindowID(3)) == "2")
    }

    /// Read at the pick: screen 2 now shows Space 6, so that is
    /// where the window goes.
    @Test("the target is what the panel's screen shows at the pick")
    func targetIsReadAtThePick() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.assign("6", to: DisplayID(2))
        core.state.workspaces.show("6", on: DisplayID(2))
        track(core, 1, in: "1")
        track(core, 2, in: "2")
        #expect(core.moveHere(.window(WindowID(2)), on: DisplayID(2)))
        #expect(core.state.workspaces.space(of: WindowID(2)) == "6")
        #expect(core.state.workspaces.activeSpace == "6")
    }

    /// The list names the Space the pick lands in, and judges its
    /// rows against it.
    @Test("the panel's list reads the same here as the move")
    func snapshotReadsTheSameHere() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        track(core, 2, in: "1")
        track(core, 3, in: "5")
        let snapshot = core.jumpSnapshot(on: DisplayID(2))
        #expect(snapshot.here == "5")
        let moves = Dictionary(
            uniqueKeysWithValues: snapshot.entries.map {
                ($0.target, $0.movesHere)
            }
        )
        #expect(moves[.window(WindowID(2))] == true)
        #expect(moves[.window(WindowID(3))] == false)
        #expect(core.jumpSnapshot().here == "1")
    }

    /// The hop lands on screen 2's shown Desktop, and the focus
    /// owed for Space 5 pays at the arrival.
    @Test("an away window hops onto KiwiHub's screen and is focused")
    func awayHopsOntoThePanelScreen() {
        let core = makeCore()
        defer { teardown() }
        track(core, 1, in: "1")
        core.state.workspaces.focus(WindowID(1), in: "1")
        park(core)
        #expect(core.moveHere(.window(WindowID(7)), on: DisplayID(2)))
        #expect(Bridge.moves.map(\.1) == [20])
        #expect(core.state.rememberedSpaces[WindowID(7)] == .departed("5"))
        #expect(core.jump.owed?.space == "5")
        core.handle(.windowCreated(window(7)))
        #expect(core.state.workspaces.space(of: WindowID(7)) == "5")
        #expect(core.state.workspaces.lastFocused == WindowID(7))
    }
}
