import Foundation
import Testing

@testable import KiwiDeskCore

/// The per-Desktop focus memory through the real switch handler,
/// the real fold and the settle (#1207): the departure remembers
/// the focus BEFORE the burst walks it off, the return owes it,
/// the owed window's arrival pays it, and the settle stands its
/// refocus down while the debt is unpaid.
///
/// The #888 fixture: Desktops 1–2 on the main display `UUID-A`
/// (ids 10, 11), 3–4 on `UUID-B` (ids 20, 21); KiwiDesk space
/// "1" on display 1. Window 2 is first in the row, window 1 the
/// focused one — the issue's TextEdit-beside-Claude shape.
/// Serialized, synchronous bodies: the topology overrides and
/// the bridge resolver are process-global (`DesktopCommandTests`'
/// note). No bridge: the carry (#1145) has nothing to move, and
/// the `carried` case below is a window the departure simply
/// keeps.
@Suite("Per-Desktop focus memory (#1207)", .serialized)
@MainActor
struct DesktopFocusMemoryTests {
    private final class Box {
        var lines: [String] = []
    }

    private let focused = WindowID(1)
    private let first = WindowID(2)
    private let carried = WindowID(3)
    private let home = SpaceID("1")

    private func makeCore() -> (KiwiCore, Box) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        NativeSpaces.activeSpaceIsUserOverride = true
        pinTwoDisplays()
        WMBridge.classResolverOverride = { _ in nil }
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "A"),
                authorityDisplay(2, "B", x: 100),
            ]
        )
        core.state.workspaces.ensureSpace(home)
        core.state.workspaces.assign(home, to: DisplayID(1))
        core.state.workspaces.activate(home)
        for id in [first, focused] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "App")
                )
            )
        }
        core.state.apply(.windowFocused(focused))
        core.lastDesktop = 1
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        let box = Box()
        core.onLog = { box.lines.append($0) }
        return (core, box)
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// Main switches Desktop 1 → 2, then the reconcile burst
    /// folds the left Desktop's windows as destroys (#40's
    /// ordering: the switch event goes out first).
    private func leaveDesktop1(_ core: KiwiCore) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 11
        core.handle(.desktopChanged)
        for id in [focused, first] {
            core.handle(.windowDestroyed(id, wasMinimized: false))
        }
    }

    /// Main switches Desktop 2 → 1. The burst that re-tracks the
    /// Desktop's windows is each test's own.
    private func returnToDesktop1(_ core: KiwiCore) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        core.handle(.desktopChanged)
    }

    private func arrive(_ id: WindowID, in core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(id: id, pid: 1, appName: "App")
            )
        )
    }

    @Test("the departure remembers the focus before the burst walks it off")
    func departureRemembersTheFocus() {
        let (core, _) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        // The burst walked `Space.focused` to nil…
        #expect(core.state.workspaces[home]?.focused == nil)
        // …and the memory kept what it was, under the main
        // display and the Desktop that was left.
        #expect(
            core.desktopMemory.focusedWindows["UUID-A"]?[1]
                == focused
        )
    }

    @Test("a focusless departure does not overwrite a good entry")
    func nilFocusDoesNotOverwrite() {
        let (core, _) = makeCore()
        defer { teardown() }
        core.desktopMemory.focusedWindows["UUID-A"] = [1: first]
        for id in [focused, first] {
            core.state.apply(
                .windowDestroyed(id, wasMinimized: false)
            )
        }
        #expect(core.state.workspaces[home]?.focused == nil)
        leaveDesktop1(core)
        #expect(
            core.desktopMemory.focusedWindows["UUID-A"]?[1] == first
        )
    }

    @Test("the return owes the remembered window, narrated")
    func returnOwesTheRememberedWindow() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
        #expect(
            box.lines.contains { $0.contains("owing focus to w1") }
        )
    }

    @Test("memory keyed to another display is not owed")
    func perDisplayKeying() {
        let (core, box) = makeCore()
        defer { teardown() }
        for id in [focused, first] {
            core.state.apply(
                .windowDestroyed(id, wasMinimized: false)
            )
        }
        core.desktopMemory.focusedWindows["UUID-B"] = [1: focused]
        core.lastDesktop = 2
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(!box.lines.contains { $0.contains("owing focus") })
    }

    /// A window the carry kept (#1145) is present through the
    /// switch: it never departed, so it is owed nothing — which
    /// is how the restore never prefers it.
    @Test("a window that never departed is owed nothing")
    func presentWindowIsNotOwed() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: carried, pid: 1, appName: "App")
            )
        )
        core.state.apply(.windowFocused(carried))
        leaveDesktop1(core)
        #expect(core.state.workspaces[home]?.focused == carried)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(!box.lines.contains { $0.contains("owing focus") })
    }

    @Test("the owed window's arrival pays the debt, once")
    func arrivalPaysTheDebt() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        // First in the row re-lists first: the vacancy is held.
        arrive(first, in: core)
        #expect(core.state.workspaces[home]?.focused == nil)
        #expect(!box.lines.contains { $0.contains("focus paid") })
        // The owed window's own arrival is the payment.
        arrive(focused, in: core)
        #expect(core.state.workspaces[home]?.focused == focused)
        #expect(
            box.lines.contains { $0.contains("focus paid to w1") }
        )
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        // Paid once: a second arrival is an ordinary create.
        box.lines = []
        arrive(focused, in: core)
        #expect(!box.lines.contains { $0.contains("focus paid") })
    }

    @Test("the settle stands down while owed, and not after payment")
    func settleStandsDownWhileOwed() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        arrive(first, in: core)
        core.desktopSettle(ifStill: core.lastDesktop)
        #expect(
            box.lines.contains {
                $0.contains("settle refocus stands down")
            }
        )
        arrive(focused, in: core)
        box.lines = []
        core.desktopSettle(ifStill: core.lastDesktop)
        #expect(
            !box.lines.contains {
                $0.contains("settle refocus stands down")
            }
        )
    }

    /// A debt lives from one return to the next. Passing through
    /// Desktop 1 before its window re-lists must not hold Desktop
    /// 2's vacancy and settle on a window that cannot arrive
    /// there.
    @Test("a return that owes nothing retires the last return's debt")
    func returnRetiresTheLastDebt() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
        // Moved on before the window re-listed: Desktop 2
        // remembers nothing, and the last return's debt goes.
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 11
        core.handle(.desktopChanged)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        box.lines = []
        core.desktopSettle(ifStill: core.lastDesktop)
        #expect(
            !box.lines.contains {
                $0.contains("settle refocus stands down")
            }
        )
    }

    /// The verb named its window (#1007): while a follow's debt
    /// stands, the return owes nothing, or whichever re-lists
    /// last would win the focus.
    @Test("a standing follow outranks the return")
    func followOutranksTheReturn() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        core.followFocus.record(WindowID(7))
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(
            box.lines.contains { $0.contains("a follow owes w7") }
        )
    }

    /// The drain key is the window: its arrival ends the debt
    /// even where the fold declined to pay it, so the settle is
    /// not held for a window already back.
    @Test("the owed window arriving unpaid drops the debt")
    func unpaidArrivalDropsTheDebt() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        // Its space is no longer the active one when it re-lists.
        core.state.workspaces.ensureSpace(SpaceID("2"))
        core.state.workspaces.activate(SpaceID("2"))
        arrive(focused, in: core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(
            box.lines.contains { $0.contains("focus debt dropped") }
        )
        #expect(!box.lines.contains { $0.contains("focus paid") })
    }

    @Test("the arrangement reset forgets the memory and the debt")
    func resetForgetsTheMemory() {
        let (core, _) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        core.discardSavedArrangement()
        #expect(core.desktopMemory.focusedWindows.isEmpty)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
    }

    @Test("a native-tab re-key follows in the memory and the debt")
    func rekeyFollows() {
        let (core, _) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        let fresh = WindowID(9)
        core.handle(.windowRekeyed(focused, fresh))
        #expect(
            core.desktopMemory.focusedWindows["UUID-A"]?[1] == fresh
        )
        #expect(core.desktopMemory.returnFocus.owed() == fresh)
    }
}
