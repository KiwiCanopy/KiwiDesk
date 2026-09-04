import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    /// Every dispatched MOVE, in order — recorded on `perform`,
    /// never on `init`: performed is not applied cuts both ways.
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []

    static func reset() { moves = [] }

    static func targets(of id: WindowID) -> [UInt64] {
        moves.filter { $0.0 == [NSNumber(value: id.raw)] }.map(\.1)
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

/// Sticky reach is a CARRY (#1145): at each Desktop switch every
/// enabled sticky window is MOVED to its home screen's current
/// Desktop — eagerly from the switch handler's one snapshot, and
/// again from the settle. Multi-membership is not available
/// (`AddWindowsToSpaces` performs and applies nothing on macOS
/// 26.6.2, os-private-apis.md), so the move IS the state and
/// there is no ledger to reconcile.
///
/// The #888 fixture: Desktops 1–2 on the main display `UUID-A`
/// (ids 10, 11), 3–4 on `UUID-B` (ids 20, 21); KiwiDesk space
/// "1" on display 1 (A), space "5" on display 2 (B). Windows 1
/// (∞), 2 (📌) and 3 (plain) are homed on A; window 4 (📌) on B.
/// A ∞ window renders on the ACTIVE space (#445), so its carry
/// follows the active space's screen; a 📌 window its home's.
/// Serialized, synchronous bodies — the resolver and the space
/// overrides are process-global (`DesktopCommandTests`' note).
/// This half holds WHERE a window is carried; WHO is carried — the
/// verdicts, the toggle, the profile tails, the gate's reading —
/// is `StickyReachCarryVerdictTests`', split at the tests.md file
/// ceiling with a per-file harness copy.
@Suite("Sticky reach carry (#1145)", .serialized)
@MainActor
struct StickyReachCarryTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)
    private let w4 = WindowID(4)

    private func makeCore(bridge: Bool = true) -> KiwiCore {
        Bridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        NativeSpaces.activeSpaceIsUserOverride = true
        pinTwoDisplays()
        WMBridge.classResolverOverride = { name in
            bridge ? bridgeClasses[name] : nil
        }
        let core = makeAuthorityCore()
        connectAuthority(
            core,
            [
                authorityDisplay(1, "A"),
                authorityDisplay(2, "B", x: 100),
            ]
        )
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.ensureSpace(SpaceID("5"))
        core.state.workspaces.assign(SpaceID("1"), to: DisplayID(1))
        core.state.workspaces.assign(SpaceID("5"), to: DisplayID(2))
        core.state.workspaces.activate(SpaceID("1"))
        for id in [w1, w2, w3, w4] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: id, pid: 1, appName: "App")
                )
            )
        }
        core.state.workspaces.add(w4, to: SpaceID("5"))
        core.state.setSticky(w1, .global)
        core.state.setSticky(w2, .display)
        core.state.setSticky(w4, .display)
        core.lastDesktop = .number(1)
        core.desktopMemory.lastDisplaySpaces = [
            "UUID-A": 10, "UUID-B": 20,
        ]
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("a switch carries every enabled sticky window, per screen")
    func switchCarriesEnabledStickyWindows() {
        let core = makeCore()
        defer { teardown() }
        // Main swipes Desktop 1 → 2.
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        core.handleDesktopChange()
        // Both scopes carry onto the arriving Desktop of THEIR
        // screen; the plain window stays.
        #expect(Bridge.targets(of: w1) == [11])
        #expect(Bridge.targets(of: w2) == [11])
        #expect(Bridge.targets(of: w3).isEmpty)
        // A window homed on the OTHER screen is normalized onto
        // that screen's current Desktop — never teleported across
        // screens because this one switched.
        #expect(Bridge.targets(of: w4) == [20])
    }

    @Test("a ∞ window carries with the screen it renders on")
    func globalStickyFollowsTheActiveSpacesScreen() {
        let core = makeCore()
        defer { teardown() }
        // The user works on B: the active space is B's, so the ∞
        // window renders there (#445) — and B's switch carries it
        // to B's arriving Desktop, while the 📌 window homed on A
        // stays with A's current.
        core.state.workspaces.activate(SpaceID("5"))
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        core.handleDesktopChange()
        #expect(Bridge.targets(of: w1) == [21])
        #expect(Bridge.targets(of: w2) == [10])
        #expect(Bridge.targets(of: w4) == [21])
    }

    @Test("the settle carries again, as the eager pass's net")
    func settleCarriesAgain() {
        let core = makeCore()
        defer { teardown() }
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        core.handleDesktopChange()
        Bridge.reset()
        core.desktopSettle(ifStill: core.desktopMemory.lastDesktopSpace)
        #expect(Bridge.targets(of: w1) == [11])
        #expect(Bridge.targets(of: w2) == [11])
        #expect(Bridge.targets(of: w4) == [20])
    }

    @Test("a secondary screen's switch carries only its own windows")
    func secondarySwitchCarriesItsOwnWindows() {
        let core = makeCore()
        defer { teardown() }
        // B swipes Desktop 3 → 4; A stays on Desktop 1.
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 21
        )
        core.handleDesktopChange()
        #expect(Bridge.targets(of: w4) == [21])
        #expect(Bridge.targets(of: w1) == [10])
        #expect(Bridge.targets(of: w2) == [10])
    }

    @Test("the eager carry runs after the arriving Space is activated")
    func eagerCarryFollowsTheActivation() {
        let core = makeCore()
        defer { teardown() }
        // The user is on B (active space "5"), and Desktop 2 on the
        // main screen remembers space "1" (on A). The switch's own
        // arm re-activates "1", so the ∞ window renders on A after
        // it — and the carry must read THAT, or it lands on B's
        // Desktop while the retile draws the window on A.
        core.state.workspaces.activate(SpaceID("5"))
        core.desktopMemory.virtualSpaces[.number(2)] = SpaceID("1")
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 11,
            secondaryCurrent: 20
        )
        core.handleDesktopChange()
        #expect(core.state.workspaces.activeSpace == SpaceID("1"))
        #expect(Bridge.targets(of: w1) == [11])
        #expect(Bridge.targets(of: w4) == [20])
    }

    @Test("shared-Spaces mode carries everything with the one list")
    func sharedSpacesCarriesWithTheOneList() {
        let core = makeCore()
        defer { teardown() }
        // One display record whose identifier is no screen UUID —
        // the shape "Displays have separate Spaces" OFF produces.
        core.refreshStickyReach(spaces: [
            authoritySpace(30, display: "SHARED"),
            authoritySpace(31, display: "SHARED", current: true),
        ])
        #expect(Bridge.targets(of: w1) == [31])
        #expect(Bridge.targets(of: w2) == [31])
        #expect(Bridge.targets(of: w4) == [31])
        #expect(Bridge.targets(of: w3).isEmpty)
    }

    @Test("a fullscreen or system space is never a carry target")
    func fullscreenSpaceCarriesNothing() {
        let core = makeCore()
        defer { teardown() }
        core.refreshStickyReach(spaces: [
            authoritySpace(10, display: "UUID-A"),
            authoritySpace(
                40,
                display: "UUID-A",
                current: true,
                isUser: false
            ),
            authoritySpace(20, display: "UUID-B", current: true),
        ])
        #expect(Bridge.targets(of: w1).isEmpty)
        #expect(Bridge.targets(of: w2).isEmpty)
        #expect(Bridge.targets(of: w4) == [20])
    }
}
