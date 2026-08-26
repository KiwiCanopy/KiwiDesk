import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    nonisolated(unsafe) static var switches: [(UInt64, String)] = []
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []
    nonisolated(unsafe) static var hides: [[NSNumber]] = []
    /// Every dispatched operation in order — the set-then-hide
    /// sequence is the #1023 fix, so the ORDER is an assertion,
    /// not a convenience.
    nonisolated(unsafe) static var events: [String] = []

    static func reset() {
        switches = []
        moves = []
        hides = []
        events = []
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

/// Captures its arguments on `init` but records the call only
/// when the operation is DISPATCHED — "performed is not applied"
/// cuts both ways, and an assertion over a merely-constructed
/// operation would stay green if a verb dropped its perform.
private final class FakeSetCurrentSpace: NSObject {
    private let space: UInt64
    private let display: String

    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: String, spaceID: UInt64) {
        space = spaceID
        display = displayIdentifier
    }

    @objc func performWithWMBridgeDelegate() {
        Bridge.switches.append((space, display))
        Bridge.events.append("set \(space) \(display)")
    }
}

private final class FakeHideSpaces: NSObject {
    private let spaces: [NSNumber]

    @objc(initWithSpaces:)
    init(spaces: [NSNumber]) {
        self.spaces = spaces
    }

    @objc func performWithWMBridgeDelegate() {
        Bridge.hides.append(spaces)
        Bridge.events.append("hide \(spaces)")
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
    "ManagedDisplaySetCurrentSpaceOperation":
        FakeSetCurrentSpace.self,
    "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self,
    "HideSpacesOperation": FakeHideSpaces.self,
]

// MARK: - Suite

/// The native Desktop verbs (#884): a Mission Control number
/// resolves in ONE topology reading to the Desktop's WindowServer
/// id and its display, the bridge is asked exactly once per verb,
/// an absent bridge refuses every verb, and a target already
/// current is a no-op.
///
/// `WMBridge.classResolverOverride` is process-global and
/// `WMBridgeTests` writes it too, but neither suite can observe
/// the other's window: both are `@MainActor` and every body
/// between the set and the `defer` restore is synchronous, so
/// there is no suspension point at which they could interleave.
/// A future async body here owes a different arrangement.
///
/// The topology is the #888 fixture: Desktops
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
                    originSpace: 10
                )
        )
        // isCurrent is DERIVED (origin == space), so the two
        // targets also pin the verdict both ways.
        #expect(
            KiwiCore.desktopTarget(number: 2, in: snapshot)?
                .isCurrent == false
        )
        #expect(
            KiwiCore.desktopTarget(number: 3, in: snapshot)
                == .init(
                    space: 20,
                    displayIdentifier: "UUID-B",
                    originSpace: 20
                )
        )
        #expect(
            KiwiCore.desktopTarget(number: 3, in: snapshot)?
                .isCurrent == true
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
        // The transition's missing half (#1023): the origin that
        // display showed is hidden, AFTER the accepted set.
        #expect(Bridge.events == ["set 11 UUID-A", "hide [10]"])
        // The honest re-query is armed.
        #expect(core.deferred.isScheduled(.desktopSwitchVerify))
        // A Desktop on the secondary display switches THAT display
        // — and hides THAT display's current space, not the main's.
        #expect(core.execute("focus_desktop", args: [.number(4)]).isSuccess)
        #expect(Bridge.switches.last?.0 == 21)
        #expect(Bridge.switches.last?.1 == "UUID-B")
        #expect(Bridge.hides.last == [20])
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
        // No switch dispatched means nothing to hide either — a
        // hide without a set blanks the visible Desktop.
        #expect(Bridge.hides.isEmpty)
        // And a VISIBLE target folds no departure: the window
        // stays tracked, re-homed by `rehomeAcrossScreens`.
        #expect(core.state.windows[WindowID(7)] != nil)
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
        #expect(Bridge.hides == [[20]])
        // A follow onto a HIDDEN Desktop folds the departure
        // eagerly (#1023's second half): the window must be OUT
        // of state before the switch's retile can re-place it
        // on the origin screen and undo the move. The reveal's
        // reconcile re-homes it through the #1010 arrival rule.
        #expect(core.state.windows[WindowID(7)] == nil)
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

    @Test("A no-follow move arms the reap, the latch and the vanish")
    func noFollowMoveArmsItsBookkeeping() {
        let core = makeCore()
        defer { teardown() }
        let before = core.lastDesktopSwitch
        #expect(core.execute("move_to_desktop", args: [.number(2)]).isSuccess)
        // The reap: nothing else notices a window that left for
        // another Desktop, so the verb arms its own reconcile.
        #expect(core.deferred.isScheduled(.desktopMoveReap))
        // The latch: the moved window can keep OS key focus.
        #expect(core.moveLatch.isLatched(WindowID(7)))
        // The switch window: the removal reads as `vanished`.
        #expect(core.lastDesktopSwitch > before)
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                sinceDesktopSwitch: Date()
                    .timeIntervalSince(core.lastDesktopSwitch)
            ) == .vanished
        )
    }

    @Test("A follow arms no reap — the switch reconciles instead")
    func followLeavesTheReapToTheSwitch() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute("move_to_desktop_and_follow", args: [.number(4)])
                .isSuccess
        )
        #expect(!core.deferred.isScheduled(.desktopMoveReap))
    }

    @Test("The capability is answered before any argument")
    func capabilityOutranksEveryOtherPrecondition() {
        let core = makeCore(bridge: false, focused: false)
        defer { teardown() }
        // No bridge AND no focused window AND a bad argument:
        // the answer names the capability, always the same one.
        let response = core.execute(
            "move_to_desktop",
            args: [.string("nonsense")]
        )
        #expect(!response.isSuccess)
        #expect(response.error?.contains("bridge") == true)
    }
}
