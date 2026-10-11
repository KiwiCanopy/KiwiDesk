import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (a per-file copy of StickyReachCarryTests')

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

/// A MOVE that records nothing: this suite reads the focus.
private final class FakeMoveWindows: NSObject {
    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {}
    @objc func performWithWMBridgeDelegate() {}
}

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self,
    "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self,
]

// MARK: - Suite

/// A carried sticky window takes the focus back on a Desktop
/// return (#1564): the focus a Desktop was LEFT with, when it was
/// a carried sticky window, is paid at the settle — over the
/// focus macOS restored ahead of the switch handler, and never
/// over a click made since the switch.
///
/// The #888 fixture: Desktops 1–2 on the main display `UUID-A`
/// (ids 10, 11), 3–4 on `UUID-B`; KiwiDesk space "1" on display
/// 1. Window 1 is ∞ sticky, window 2 plain — the issue's TextEdit
/// note beside Claude. Serialized, synchronous bodies: the
/// topology overrides and the bridge resolver are process-global.
@Suite("Sticky return focus (#1564)", .serialized)
@MainActor
struct StickyReturnFocusTests {
    private final class Box {
        var lines: [String] = []
        /// Where the compositor hosts each window.
        var hosts: [WindowID: UInt64] = [:]
    }

    private let sticky = WindowID(1)
    private let other = WindowID(2)
    private let third = WindowID(3)

    private func makeCore() -> (KiwiCore, Box) {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        NativeSpaces.activeSpaceIsUserOverride = true
        pinTwoDisplays()
        WMBridge.classResolverOverride = { bridgeClasses[$0] }
        let core = makeAuthorityCore()
        let box = Box()
        box.hosts = [sticky: 10, other: 10, third: 10]
        core.desktopMemory.readWindowSpace = { id in
            box.hosts[id].map { .hosted($0) } ?? .unavailable
        }
        connectAuthority(
            core,
            [
                authorityDisplay(1, "A"),
                authorityDisplay(2, "B", x: 100),
            ]
        )
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.assign(SpaceID("1"), to: DisplayID(1))
        core.state.workspaces.activate(SpaceID("1"))
        for id in [other, third, sticky] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "App")
                )
            )
        }
        core.state.setSticky(sticky, .global)
        core.lastDesktop = .number(1)
        // Boot's seed (`KiwiCore+BootSeams`): the Desktop shown.
        core.desktopMemory.lastDesktopSpace = 10
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
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

    /// Leave Desktop 1 with `focus` focused, go to Desktop 2 (the
    /// sticky window carried along), and come back: macOS's
    /// restore of `other` on Desktop 1 lands ahead of the handler,
    /// as the issue's trace shows.
    private func roundTrip(
        _ core: KiwiCore,
        _ box: Box,
        leavingWith focus: WindowID
    ) {
        core.handle(.windowFocused(focus))
        switchMain(core, to: 11)
        box.hosts[sticky] = 11
        box.hosts[other] = 10
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        core.handle(.windowFocused(other))
        core.handle(.desktopChanged)
        box.hosts[sticky] = 10
    }

    @Test("the sticky window left with takes the focus back")
    func settlePaysTheStickyWindow() {
        let (core, box) = makeCore()
        defer { teardown() }
        roundTrip(core, box, leavingWith: sticky)
        #expect(core.desktopMemory.stickyReturn?.window == sticky)
        #expect(core.state.workspaces.lastFocused == other)
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.state.workspaces.lastFocused == sticky)
        #expect(box.lines.contains { $0.contains("focus back to carried") })
    }

    @Test("a Desktop left with another window owes nothing")
    func otherFocusOwesNothing() {
        let (core, box) = makeCore()
        defer { teardown() }
        roundTrip(core, box, leavingWith: other)
        #expect(core.desktopMemory.stickyReturn == nil)
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.state.workspaces.lastFocused == other)
    }

    /// macOS's restore report may land after the handler: it is
    /// the focus this debt overrides, so it never retires it.
    @Test("a late restore report still pays")
    func lateRestoreStillPays() {
        let (core, box) = makeCore()
        defer { teardown() }
        roundTrip(core, box, leavingWith: sticky)
        core.handle(.windowFocused(third))
        #expect(core.desktopMemory.stickyReturn?.window == sticky)
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.state.workspaces.lastFocused == sticky)
    }

    /// A focus KiwiDesk commanded after the return — a `focus`
    /// verb, Open or Focus — is the user's choice.
    @Test("a commanded focus since the return keeps its choice")
    func commandedFocusStandsDown() {
        let (core, box) = makeCore()
        defer { teardown() }
        roundTrip(core, box, leavingWith: sticky)
        core.eventLoop.lastCommandedFocus = .now
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.state.workspaces.lastFocused == other)
        #expect(box.lines.contains { $0.contains("commanded focus") })
    }

    /// A settle that stands down still ends the debt, or a later
    /// secondary-screen settle would pay it stale.
    @Test("a settle that stands down ends the debt")
    func standDownEndsTheDebt() {
        let (core, box) = makeCore()
        defer { teardown() }
        roundTrip(core, box, leavingWith: sticky)
        NativeSpaces.activeSpaceIsUserOverride = false
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.desktopMemory.stickyReturn == nil)
        #expect(core.state.workspaces.lastFocused == other)
    }

    /// A follow (#1007) names its window: it outranks the memory.
    @Test("a standing follow outranks the sticky debt")
    func followOutranks() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.followFocus.record(third)
        roundTrip(core, box, leavingWith: sticky)
        #expect(core.desktopMemory.stickyReturn == nil)
    }

    @Test("a click since the switch keeps its choice")
    func clickStandsDown() {
        let (core, box) = makeCore()
        defer { teardown() }
        roundTrip(core, box, leavingWith: sticky)
        core.lastLeftClick = (Date(), .zero, other)
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.state.workspaces.lastFocused == other)
        #expect(box.lines.contains { $0.contains("a press or") })
    }

    /// Reach off: the window was not carried, so nothing follows
    /// the user back to take the focus.
    @Test("a sticky window reach does not carry owes nothing")
    func uncarriedOwesNothing() {
        let (core, box) = makeCore()
        defer { teardown() }
        core.tiler.settings.stickyStyle.desktopReach = false
        roundTrip(core, box, leavingWith: sticky)
        #expect(core.desktopMemory.stickyLeft.isEmpty)
        #expect(core.desktopMemory.stickyReturn == nil)
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(core.state.workspaces.lastFocused == other)
    }
}
