import Foundation
import Testing

@testable import KiwiDeskCore

/// The returning-focus memory through the real focus handler and
/// the real switch handler (#1207): an honored focus is remembered
/// under its space and the native Space the WindowServer hosts the
/// window on, and the return owes it only when it is gone. The
/// payment half is `DesktopFocusPaymentTests`, split at the
/// tests.md file ceiling with a per-file fixture copy.
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
@Suite("Returning focus memory (#1207)", .serialized)
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
        // Every window lives on Desktop 1 (native 10) unless a
        // test says otherwise.
        core.desktopMemory.readWindowSpace = { _ in .hosted(10) }
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
        core.lastDesktop = 1
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        // The focus REPORT, through the real handler: that is
        // where the memory is written.
        core.handle(.windowFocused(focused))
        let box = Box()
        core.onLog = { box.lines.append($0) }
        return (core, box)
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func switchMain(_ core: KiwiCore, to space: UInt64) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: space,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = space
        core.handle(.desktopChanged)
    }

    private func destroyAll(_ core: KiwiCore) {
        for id in [focused, first] {
            core.handle(.windowDestroyed(id, wasMinimized: false))
        }
    }

    /// Main switches Desktop 1 → 2. The destroys fold FIRST by
    /// default — the ordering the device showed (an app's own AX
    /// observer beats the notification) — or after the handler.
    private func leaveDesktop1(
        _ core: KiwiCore,
        destroysFirst: Bool = true
    ) {
        if destroysFirst {
            destroyAll(core)
            switchMain(core, to: 11)
        } else {
            switchMain(core, to: 11)
            destroyAll(core)
        }
    }

    /// Main switches Desktop 2 → 1. The burst that re-tracks the
    /// Desktop's windows is each test's own.
    private func returnToDesktop1(_ core: KiwiCore) {
        switchMain(core, to: 10)
    }

    private func arrive(_ id: WindowID, in core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(id: id, pid: 1, appName: "App")
            )
        )
    }

    @Test("an honored focus is remembered under its space and Desktop")
    func honoredFocusIsRemembered() {
        let (core, _) = makeCore()
        defer { teardown() }
        #expect(core.desktopMemory.honoredFocus[home]?[10] == focused)
        core.handle(.windowFocused(first))
        #expect(core.desktopMemory.honoredFocus[home]?[10] == first)
    }

    /// The device log's ordering: the departure's destroys fold
    /// before the switch handler runs, so `Space.focused` is
    /// already walked when it does. The memory must not read it.
    @Test("a departure folded before the handler does not corrupt it")
    func departureBeforeHandlerDoesNotCorrupt() {
        let (core, _) = makeCore()
        defer { teardown() }
        leaveDesktop1(core, destroysFirst: true)
        #expect(core.state.workspaces[home]?.focused == nil)
        #expect(core.desktopMemory.honoredFocus[home]?[10] == focused)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
    }

    @Test("the return owes the remembered window, narrated")
    func returnOwesTheRememberedWindow() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core, destroysFirst: false)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
        #expect(
            box.lines.contains { $0.contains("owing focus to w1") }
        )
    }

    /// macOS restores its own key window at the switch, and an
    /// app that re-lists before the handler runs has that focus
    /// HONORED already — stamped where the WindowServer says the
    /// window is, never where the stale handler state says. The
    /// return then finds it present and owes nothing; paying the
    /// memory over it is the yank the device showed.
    @Test("a focus honored before the handler is stamped where it is")
    func honoredBeforeHandlerOwesNothing() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        arrive(first, in: core)
        core.handle(.windowFocused(first))
        #expect(core.desktopMemory.honoredFocus[home]?[10] == first)
        #expect(core.desktopMemory.honoredFocus[home]?[11] == nil)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(!box.lines.contains { $0.contains("owing focus") })
        #expect(core.state.workspaces[home]?.focused == first)
        leaveDesktop1(core)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == first)
    }

    /// The other Desktop's window, honored there and still present
    /// at the return because its app folds slowly, is NOT the
    /// arriving Desktop's restore: it was stamped under its own
    /// native Space, so the remembered window is still owed.
    @Test("a slow-folding window of the left Desktop is not mistaken")
    func slowFoldOfTheLeftDesktopIsNotMistaken() {
        let (core, box) = makeCore()
        defer { teardown() }
        let other = WindowID(7)
        core.desktopMemory.readWindowSpace = {
            .hosted($0 == other ? 11 : 10)
        }
        leaveDesktop1(core)
        arrive(other, in: core)
        core.handle(.windowFocused(other))
        #expect(core.desktopMemory.honoredFocus[home]?[11] == other)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
        core.handle(.windowDestroyed(other, wasMinimized: false))
        arrive(first, in: core)
        #expect(core.state.workspaces[home]?.focused == nil)
        arrive(focused, in: core)
        #expect(core.state.workspaces[home]?.focused == focused)
        #expect(
            box.lines.contains { $0.contains("focus paid to w1") }
        )
    }

    /// A window the carry kept (#1145) is present through the
    /// switch: it never departed, so it is owed nothing.
    @Test("a window that never departed is owed nothing")
    func presentWindowIsNotOwed() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: carried, pid: 1, appName: "App")
            )
        )
        core.handle(.windowFocused(carried))
        leaveDesktop1(core)
        #expect(core.state.workspaces[home]?.focused == carried)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(!box.lines.contains { $0.contains("owing focus") })
    }

    /// The ruling's own case: the walk lands the departure's
    /// focus on the one member that stays, and the return must
    /// not prefer it — the remembered window is owed, and paid
    /// when it re-lists.
    @Test("a carried sticky is not preferred over the remembered focus")
    func carriedStickyIsNotPreferred() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: carried, pid: 1, appName: "App")
            )
        )
        core.handle(.windowFocused(focused))
        leaveDesktop1(core)
        #expect(core.state.workspaces[home]?.focused == carried)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
        arrive(first, in: core)
        #expect(core.state.workspaces[home]?.focused == carried)
        arrive(focused, in: core)
        #expect(core.state.workspaces[home]?.focused == focused)
        #expect(
            box.lines.contains { $0.contains("focus paid to w1") }
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
        // remembers nothing — no Space either, so the retire is
        // reached through the target's first-space fallback —
        // and the last return's debt goes.
        core.desktopMemory.virtualSpaces = [:]
        core.desktopMemory.honoredFocus = [:]
        switchMain(core, to: 11)
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
}
