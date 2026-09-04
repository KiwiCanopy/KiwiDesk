import Foundation
import Testing

@testable import KiwiDeskCore

/// The returning-focus debt's PAYMENT through the real handlers
/// (#1207), and the KEY the owe reads: the owed window's arrival
/// pays it once, the settle stands its refocus down while it is
/// unpaid, an unpaid arrival drops it, the reset and a re-key
/// reach it, and the owe reads exactly the (space, native Space)
/// entry the snapshot names. The memory half — what is remembered
/// — is `DesktopFocusMemoryTests`, split at the tests.md file
/// ceiling with a per-file fixture copy.
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
@Suite("Returning focus payment (#1207)", .serialized)
@MainActor
struct DesktopFocusPaymentTests {
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
        core.lastDesktop = .number(1)
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

    /// The owe reads the snapshot's MAIN-display Space, threaded
    /// from the handler's one reading — never the global active
    /// Space, which under separate Spaces can be a secondary
    /// screen's (profiles.md ▸ thread the value).
    @Test("the owe reads the snapshot's main Space, not the global one")
    func oweReadsTheSnapshotsMainSpace() {
        let (core, _) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        // The user's focus sits on the secondary screen.
        NativeSpaces.activeSpaceIDOverride = 20
        core.handle(.desktopChanged)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
    }

    /// Shared mode ("Displays have separate Spaces" off): the main
    /// display carries a synthetic identifier the per-display map
    /// never lists, so the arriving native Space takes the global
    /// fallback the Desktop number already takes — or the memory
    /// is silently inert for every shared-mode user.
    @Test("shared mode owes through the global fallback")
    func sharedModeOwesThroughTheFallback() {
        let (core, _) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        NativeSpaces.mainDisplayUUIDOverride = "UUID-X"
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
    }

    /// Two Desktops showing one space keep their own entries: the
    /// other Desktop's focus is never this Desktop's debt.
    @Test("another Desktop's entry for the same space is not owed")
    func perDesktopKeying() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.desktopMemory.honoredFocus = [home: [11: focused]]
        destroyAll(core)
        core.lastDesktop = .number(2)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(!box.lines.contains { $0.contains("owing focus") })
    }

    @Test("another space's memory is not owed")
    func perSpaceKeying() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.desktopMemory.honoredFocus = [SpaceID("2"): [10: focused]]
        destroyAll(core)
        core.lastDesktop = .number(2)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(!box.lines.contains { $0.contains("owing focus") })
    }

    /// The other ordering of the OS restore (CI, 2026-09-02):
    /// the handler owes first, THEN a returning window is
    /// reported focused. That report is ground truth; the owed
    /// window's later arrival must not pay over it.
    @Test("a focus honored after the owe retires the debt")
    func honoredAfterOweRetiresTheDebt() {
        let (core, box) = makeCore()
        defer { teardown() }
        leaveDesktop1(core)
        returnToDesktop1(core)
        #expect(core.desktopMemory.returnFocus.owed() == focused)
        arrive(first, in: core)
        core.handle(.windowFocused(first))
        #expect(core.desktopMemory.returnFocus.owed() == nil)
        #expect(
            box.lines.contains { $0.contains("debt to w1 retired") }
        )
        arrive(focused, in: core)
        #expect(core.state.workspaces[home]?.focused == first)
        #expect(!box.lines.contains { $0.contains("focus paid") })
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
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(
            box.lines.contains {
                $0.contains("settle refocus stands down")
            }
        )
        arrive(focused, in: core)
        box.lines = []
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(
            !box.lines.contains {
                $0.contains("settle refocus stands down")
            }
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
        #expect(core.desktopMemory.honoredFocus.isEmpty)
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
        #expect(core.desktopMemory.honoredFocus[home]?[10] == fresh)
        #expect(core.desktopMemory.returnFocus.owed() == fresh)
    }
}
