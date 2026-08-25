import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    nonisolated(unsafe) static var switches: [(UInt64, String)] = []
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []

    static func reset() {
        switches = []
        moves = []
    }
}

private final class FakePlistArrayResult: NSObject {
    @objc let propertyListArray: [[String: Any]]
    init(propertyListArray: [[String: Any]]) {
        self.propertyListArray = propertyListArray
    }
}

/// The availability probe, answering — the bridge is present.
private final class FakeCopyManagedDisplaySpaces: NSObject {
    @objc override init() {}
    @objc func performWithWMBridgeDelegate() -> AnyObject? {
        FakePlistArrayResult(propertyListArray: [["Spaces": []]])
    }
}

private final class FakeSetCurrentSpace: NSObject {
    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: String, spaceID: UInt64) {
        Bridge.switches.append((spaceID, displayIdentifier))
    }
    @objc func performWithWMBridgeDelegate() {}
}

private final class FakeMoveWindows: NSObject {
    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {
        Bridge.moves.append((windows, spaceID))
    }
    @objc func performWithWMBridgeDelegate() {}
}

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self,
    "ManagedDisplaySetCurrentSpaceOperation":
        FakeSetCurrentSpace.self,
    "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self,
]

// MARK: - Suite

/// The native Desktop verbs (#884): a Mission Control number
/// resolves in ONE topology reading to the Desktop's WindowServer
/// id and its display, the bridge is asked exactly once per verb,
/// an absent bridge refuses every verb, and a target already
/// current is a no-op. The topology is the #888 fixture: Desktops
/// 1–2 on the main display `UUID-A` (ids 10, 11), 3–4 on `UUID-B`
/// (ids 20, 21).
@Suite("Desktop verbs (#884)", .serialized)
@MainActor
struct DesktopCommandTests {
    private func makeCore(
        bridge: Bool = true,
        focused: Bool = true
    ) -> KiwiCore {
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
        if focused {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
                )
            )
        }
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("A number resolves to the Desktop's id and its display")
    func numberResolvesInOneSnapshot() {
        let core = makeCore()
        defer { teardown() }
        _ = core
        let snapshot = NativeSpaces.desktopSnapshot()
        #expect(
            KiwiCore.desktopTarget(number: 2, in: snapshot)
                == .init(
                    space: 11,
                    displayIdentifier: "UUID-A",
                    isCurrent: false
                )
        )
        #expect(
            KiwiCore.desktopTarget(number: 3, in: snapshot)
                == .init(
                    space: 20,
                    displayIdentifier: "UUID-B",
                    isCurrent: true
                )
        )
        #expect(KiwiCore.desktopTarget(number: 0, in: snapshot) == nil)
        #expect(KiwiCore.desktopTarget(number: 5, in: snapshot) == nil)
    }

    @Test("focus_desktop switches the Desktop's own display")
    func focusDesktopSwitches() {
        let core = makeCore()
        defer { teardown() }
        let before = core.lastDesktopSwitch
        #expect(core.execute("focus_desktop", args: [.number(2)]).isSuccess)
        #expect(Bridge.switches.map(\.0) == [11])
        #expect(Bridge.switches.map(\.1) == ["UUID-A"])
        #expect(core.lastDesktopSwitch > before)
        // A Desktop on the secondary display switches THAT display.
        #expect(core.execute("focus_desktop", args: [.number(4)]).isSuccess)
        #expect(Bridge.switches.last?.0 == 21)
        #expect(Bridge.switches.last?.1 == "UUID-B")
    }

    @Test("A Desktop its display already shows: no switch, still a move")
    func currentDesktopSwitchStandsDown() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("focus_desktop", args: [.number(1)]).isSuccess)
        #expect(Bridge.switches.isEmpty)
        // The move cannot know the window is there already — it
        // may sit on another display — so it dispatches; only
        // the follow stands down.
        #expect(
            core.execute("move_to_desktop_and_follow", args: [.number(1)])
                .isSuccess
        )
        #expect(Bridge.moves.map(\.1) == [10])
        #expect(Bridge.switches.isEmpty)
    }

    @Test("move_to_desktop moves the focused window, and follow switches")
    func moveThenFollow() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("move_to_desktop", args: [.number(2)]).isSuccess)
        #expect(Bridge.moves.map(\.1) == [11])
        #expect(Bridge.moves.first?.0 == [7])
        #expect(Bridge.switches.isEmpty)
        // Follow to a Desktop its display does NOT show: the
        // move, then that display's switch.
        #expect(
            core.execute("move_to_desktop_and_follow", args: [.number(4)])
                .isSuccess
        )
        #expect(Bridge.moves.last?.1 == 21)
        #expect(Bridge.switches.map(\.0) == [21])
        #expect(Bridge.switches.map(\.1) == ["UUID-B"])
    }

    @Test("Refusals: no bridge, no such Desktop, bad argument, no focus")
    func refusals() {
        do {
            let core = makeCore(bridge: false)
            defer { teardown() }
            #expect(
                !core.execute("focus_desktop", args: [.number(2)]).isSuccess
            )
            #expect(
                !core.execute("move_to_desktop", args: [.number(2)]).isSuccess
            )
            #expect(Bridge.switches.isEmpty && Bridge.moves.isEmpty)
        }
        do {
            let core = makeCore()
            defer { teardown() }
            #expect(
                !core.execute("focus_desktop", args: [.number(9)]).isSuccess
            )
            #expect(
                !core.execute("focus_desktop", args: [.string("x")]).isSuccess
            )
            #expect(!core.execute("focus_desktop", args: []).isSuccess)
            #expect(Bridge.switches.isEmpty)
        }
        do {
            let core = makeCore(focused: false)
            defer { teardown() }
            #expect(
                !core.execute("move_to_desktop", args: [.number(2)]).isSuccess
            )
            #expect(Bridge.moves.isEmpty)
        }
    }
}
