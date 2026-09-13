import Foundation
import Testing

@testable import KiwiDeskCore

/// The settle's refocus stands down for a focus the switch itself
/// removed (#1364): a window that LEFT WITH ITS DESKTOP inside the
/// switch and was re-listed before the settle is back because the
/// OS re-listed it — an empty destination Desktop makes its app
/// the active one — not because the user chose it, and raising it
/// activates that app on the Desktop the user left: the pull-back.
/// Observed through `focusWindow`'s own refusal line under an
/// on-screen seam pinned false, which proves whether the settle
/// reached the raise at all. Serialized: the topology overrides
/// are process-global.
@Suite("Settle: a departed focus stays down (#1364)", .serialized)
@MainActor
struct DesktopSettleDepartureTests {
    private final class Box {
        var lines: [String] = []
    }

    private let focused = WindowID(1)
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
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: focused, pid: 1, appName: "App")
            )
        )
        core.state.workspaces.focus(focused, in: home)
        core.lastDesktop = .number(1)
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        // The raise gate's read, pinned false: a refocus the
        // settle reaches is REFUSED there and says so, which is
        // the one line that tells "stood down" from "raised".
        core.windowIsOnScreen = { _ in false }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        return (core, box)
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// The main display leaves Desktop 1 for an EMPTY Desktop 2:
    /// no Space is bound to it, so the active Space stays.
    private func swipeToEmptyDesktop(_ core: KiwiCore) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 11
        core.handle(.desktopChanged)
    }

    private func relist(_ core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(id: focused, pid: 1, appName: "App")
            )
        )
    }

    /// Scoped to the settle: the lines are cleared first, so the
    /// raise needle can only come from the settle's own refocus.
    private func settle(_ core: KiwiCore, _ box: Box) {
        box.lines = []
        core.desktopSettle(
            ifStill: core.desktopMemory.lastDesktopSpace
        )
    }

    private func reachedTheRaise(_ box: Box) -> Bool {
        box.lines.contains {
            $0.contains("focus: w1 refused — not on screen")
        }
    }

    private func stoodDown(_ box: Box) -> Bool {
        box.lines.contains {
            $0.contains("left with this switch and came back")
        }
    }

    /// The issue's shape: the focused window vanishes with the
    /// Desktop, the swipe lands on an empty Desktop, the sweep
    /// re-lists the window into the vacancy, and the settle
    /// would raise it.
    @Test("a window that left with the switch and came back is not raised")
    func departedReturnStandsDown() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        core.handle(.windowDestroyed(focused, wasMinimized: false))
        swipeToEmptyDesktop(core)
        relist(core)
        #expect(core.state.workspaces[home]?.focused == focused)
        settle(core, box)
        #expect(stoodDown(box))
        #expect(!reachedTheRaise(box))
    }

    /// The control: a focus that stayed through the switch is
    /// re-asserted the way it always was.
    @Test("a focus that stayed through the switch is still re-asserted")
    func presentFocusIsReasserted() {
        let (core, box) = makeCore()
        defer { teardown() }
        swipeToEmptyDesktop(core)
        settle(core, box)
        #expect(!stoodDown(box))
        #expect(reachedTheRaise(box))
    }

    /// A close is not a departure: a window closed and reopened
    /// across the switch is an ordinary create, and the settle
    /// re-asserts it.
    @Test("a closed and reopened window does not stand the settle down")
    func closeIsNotADeparture() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .gone }
        core.handle(.windowDestroyed(focused, wasMinimized: false))
        swipeToEmptyDesktop(core)
        relist(core)
        settle(core, box)
        #expect(!stoodDown(box))
        #expect(reachedTheRaise(box))
    }

    /// A record older than the switch is not this switch's: the
    /// filing is stamped, and a later switch's settle re-asserts
    /// the same still-focused window. Backdated past the grace
    /// rather than waited out (tests.md: no tight deadlines).
    @Test("a departure filed before the switch grace is not this switch's")
    func olderDepartureIsNotThisSwitch() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        core.handle(.windowDestroyed(focused, wasMinimized: false))
        swipeToEmptyDesktop(core)
        relist(core)
        settle(core, box)
        #expect(stoodDown(box))
        // Backdated against the SWITCH, never against now: a loaded
        // runner spends more than the grace between the swipe and
        // this line, and a stamp aged from now would still read as
        // this switch's (CI, 2026-09-13).
        core.desktopMemory.switchDepartures[focused] =
            core.lastDesktopSwitch.addingTimeInterval(
                -EventLoop.spaceSwitchCoalesceGrace - 1
            )
        settle(core, box)
        #expect(!stoodDown(box))
        #expect(reachedTheRaise(box))
    }

    /// The bound is the filing door's: a stale entry is pruned
    /// at the next filing, and a fresh one is read against the
    /// switch — inside the grace before it, not beyond.
    @Test("the record is pruned at filing and read against the switch")
    func recordIsBoundedAndSwitchScoped() {
        let (core, _) = makeCore()
        defer { teardown() }
        let stale = WindowID(9)
        let now = Date()
        core.fileSwitchDeparture(
            stale,
            now: now.addingTimeInterval(
                -KiwiCore.switchDepartureWindow - 1
            )
        )
        #expect(core.desktopMemory.switchDepartures[stale] != nil)
        core.fileSwitchDeparture(focused, now: now)
        #expect(core.desktopMemory.switchDepartures[stale] == nil)
        core.lastDesktopSwitch = now.addingTimeInterval(0.5)
        #expect(core.departedWithThisSwitch(focused))
        core.lastDesktopSwitch = now.addingTimeInterval(
            EventLoop.spaceSwitchCoalesceGrace + 0.5
        )
        #expect(!core.departedWithThisSwitch(focused))
    }

    /// Read, never consumed: a second settle of the same switch
    /// finds the record still standing.
    @Test("the settle does not consume the record")
    func settleDoesNotConsume() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.desktopMemory.readWindowSpace = { _ in .hosted(11) }
        core.handle(.windowDestroyed(focused, wasMinimized: false))
        swipeToEmptyDesktop(core)
        relist(core)
        settle(core, box)
        #expect(stoodDown(box))
        settle(core, box)
        #expect(stoodDown(box))
        #expect(!reachedTheRaise(box))
    }

    /// Id-keyed like the focus memory, and re-keyed with it: a
    /// native-tab return under a fresh id still stands down.
    @Test("a re-key carries the record to the fresh id")
    func rekeyFollows() {
        let (core, _) = makeCore()
        defer { teardown() }
        let fresh = WindowID(7)
        core.fileSwitchDeparture(focused)
        core.rekeyDesktopFocus(old: focused, new: fresh)
        #expect(core.desktopMemory.switchDepartures[focused] == nil)
        #expect(core.departedWithThisSwitch(fresh))
    }

    /// Retired with the focus memory: a window gone for good, and
    /// the #634 reset, leave no record behind.
    @Test("retire and the arrangement reset end the record")
    func retireAndResetEndTheRecord() {
        let (core, _) = makeCore()
        defer { teardown() }
        core.fileSwitchDeparture(focused)
        core.retireDesktopFocus(of: focused)
        #expect(core.desktopMemory.switchDepartures[focused] == nil)
        core.fileSwitchDeparture(focused)
        core.forgetDesktopFocus()
        #expect(core.desktopMemory.switchDepartures.isEmpty)
    }
}
