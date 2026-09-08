import Foundation
import Testing

@testable import KiwiDeskCore

// The fakes live in `DesktopBridgeFakes.swift` (§2.1); the suite
// keeps its own short names.
private typealias Bridge = DesktopVerbBridge
private let bridgeClasses = desktopVerbBridgeClasses

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
                    originSpace: 10,
                    spaces: snapshot.spaces
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
                    originSpace: 20,
                    spaces: snapshot.spaces
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
        let moved = core.execute("focus_desktop", args: [.number(2)])
        #expect(moved.isSuccess)
        // The other half of the discriminator, through the same
        // consumer: presence-vs-absence must never come back as
        // the way a caller tells the two apart (#1336).
        #expect(SwitchOutcomeReading.switched(moved) == true)
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
        let shown = core.execute("focus_desktop", args: [.number(1)])
        #expect(shown.isSuccess)
        // Success alone is what a bare `.ok()` also satisfies, so
        // read the field the Lua and CLI callers read (#1336).
        #expect(SwitchOutcomeReading.switched(shown) == false)
        #expect(Bridge.switches.isEmpty)
        // The move cannot know the window is there already — it
        // may sit on another display — so it dispatches; only
        // the follow stands down.
        let followed = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(1)]
        )
        #expect(followed.isSuccess)
        // The follow's own consumer, which returns the outcome's
        // response after doing the most work of any arm.
        #expect(SwitchOutcomeReading.switched(followed) == false)
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
        // The switch window: without a compositor answer the
        // removal reads as `vanished` off the stamp (#1146 keeps
        // the timer as the no-SkyLight fallback).
        #expect(core.lastDesktopSwitch > before)
        #expect(
            WindowGoneReason.classify(
                wasMinimized: false,
                presence: .unknown(
                    sinceDesktopSwitch: Date()
                        .timeIntervalSince(core.lastDesktopSwitch)
                )
            ) == .vanished
        )
        // The departure record (#1345): a hidden target's vanish
        // is the verb's own hand-off, so it is recorded.
        #expect(core.desktopMoveDepartures[WindowID(7)] != nil)
    }

    /// A move onto the Desktop its screen already shows produces
    /// no vanish, so the verb records no departure (#1345).
    @Test("A no-follow move onto the shown Desktop records no departure")
    func noFollowMoveOntoShownRecordsNothing() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("move_to_desktop", args: [.number(1)]).isSuccess)
        #expect(core.desktopMoveDepartures.isEmpty)
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
