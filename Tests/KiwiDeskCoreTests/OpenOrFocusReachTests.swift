import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    nonisolated(unsafe) static var switches: [(UInt64, String)] = []

    static func reset() { switches = [] }
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
    }
}

private final class FakeHideSpaces: NSObject {
    @objc(initWithSpaces:)
    init(spaces: [NSNumber]) {}
    @objc func performWithWMBridgeDelegate() {}
}

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self,
    "ManagedDisplaySetCurrentSpaceOperation":
        FakeSetCurrentSpace.self,
    "HideSpacesOperation": FakeHideSpaces.self,
]

/// How the fake bridge answers: every class, only the
/// availability probe (so a switch is REFUSED), or nothing.
private enum BridgeShape {
    case present
    case refusing
    case absent

    func resolve(_ name: String) -> AnyClass? {
        switch self {
        case .present: bridgeClasses[name]
        case .refusing:
            name == "CopyManagedDisplaySpacesOperation"
                ? bridgeClasses[name] : nil
        case .absent: nil
        }
    }
}

/// What Open or Focus did to the machine, and the census the
/// core reads — one box per core, captured by its seams.
@MainActor
private final class Touches {
    var activated: [pid_t] = []
    var restored: [WindowID] = []
    var opened: [String] = []
    var hosts: [WindowID: DesktopCensus.Host] = [:]
}

// MARK: - Suite

/// Open or Focus reaches a window UP on an away Desktop (#1146):
/// with nothing up on a shown Desktop, the Desktop is switched
/// over the bridge and the window is owed its focus; nothing is
/// un-parked beside an away window; the cycle ring holds away
/// windows by rank. Without the bridge the pre-#1146 path runs.
/// The topology is the #888 fixture: Desktops 1–2 on `UUID-A`
/// (ids 10, 11), 3–4 on `UUID-B` (ids 20, 21).
@Suite("Open-or-Focus reach (#1146)", .serialized)
@MainActor
struct OpenOrFocusReachTests {
    private let pid: pid_t = 100
    private let bundle = "app.test.safari"

    private func makeCore(
        bridge: BridgeShape = .present
    ) -> (KiwiCore, Touches) {
        Bridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { bridge.resolve($0) }
        let core = makeTestCore()
        core.state.workspaces.ensureSpace("1")
        core.state.workspaces.activate("1")
        let touches = Touches()
        core.openOrFocus.runningAppPID = { _ in self.pid }
        core.openOrFocus.census = { _ in
            KiwiCore.AppWindowCensus(
                visible: 0,
                minimized: [WindowID(9)]
            )
        }
        core.openOrFocus.deminiaturize = { _, id in
            touches.restored.append(id)
        }
        core.openOrFocus.activate = { touches.activated.append($0) }
        core.openOrFocus.openApp = { id, _ in
            touches.opened.append(id)
            return true
        }
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: touches.hosts,
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
        return (core, touches)
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// Files `id` as away in space "1", hosted on `space` (11 =
    /// Desktop 2 by default).
    private func park(
        _ core: KiwiCore,
        _ touches: Touches,
        _ id: UInt32,
        rank: Int,
        up: Bool = true,
        space: UInt64 = 11
    ) {
        core.state.awayWindows[WindowID(id)] = AwayWindow(
            id: WindowID(id),
            pid: pid,
            appName: "Safari",
            appBundleID: bundle,
            nativeSpace: space
        )
        core.state.rememberedSpaces[WindowID(id)] = .departed("1")
        core.state.departedSlots[WindowID(id)] = rank
        touches.hosts[WindowID(id)] = DesktopCensus.Host(
            space: space,
            pid: pid,
            isUp: up
        )
    }

    private func press(_ core: KiwiCore) {
        #expect(
            core.execute("pull_or_spawn", args: [.string(bundle)])
                .isSuccess
        )
    }

    @Test("nothing up here, a window up away: switched and owed")
    func reaches() {
        let (core, touches) = makeCore()
        defer { teardown() }
        park(core, touches, 7, rank: 0)
        press(core)
        #expect(Bridge.switches.map(\.0) == [11])
        #expect(core.followFocus.owed() == WindowID(7))
        #expect(touches.restored.isEmpty)
        #expect(touches.activated.isEmpty)
        #expect(core.deferred.isScheduled(.awayReachReap))
    }

    @Test("a parked away window is not reached; the un-park runs")
    func parkedAwayIsNotReached() {
        let (core, touches) = makeCore()
        defer { teardown() }
        park(core, touches, 7, rank: 0, up: false)
        press(core)
        #expect(Bridge.switches.isEmpty)
        #expect(core.followFocus.owed() == nil)
        #expect(touches.restored == [WindowID(9)])
        #expect(touches.activated == [pid])
    }

    /// A stale entry the census has since re-homed onto a shown
    /// Desktop is not away, whatever the ledger last recorded.
    @Test("an entry hosted on a shown Desktop is not reached")
    func staleEntryOnShownDesktopIsNotReached() {
        let (core, touches) = makeCore()
        defer { teardown() }
        park(core, touches, 7, rank: 0, space: 10)
        press(core)
        #expect(Bridge.switches.isEmpty)
        #expect(core.followFocus.owed() == nil)
        // Not away ⇒ nothing up anywhere ⇒ the un-park runs.
        #expect(touches.restored == [WindowID(9)])
        #expect(touches.activated == [pid])
    }

    @Test("without the bridge the pre-#1146 path runs")
    func noBridgeActivates() {
        let (core, touches) = makeCore(bridge: .absent)
        defer { teardown() }
        park(core, touches, 7, rank: 0)
        press(core)
        #expect(Bridge.switches.isEmpty)
        #expect(core.followFocus.owed() == nil)
        // A window UP away still counts as up: no un-park.
        #expect(touches.restored.isEmpty)
        #expect(touches.activated == [pid])
    }

    @Test("with a window up here the away one waits")
    func visibleHereWins() {
        let (core, touches) = makeCore()
        defer { teardown() }
        core.openOrFocus.census = { _ in
            KiwiCore.AppWindowCensus(visible: 1, minimized: [])
        }
        park(core, touches, 7, rank: 0)
        press(core)
        #expect(Bridge.switches.isEmpty)
        #expect(touches.activated == [pid])
    }

    private func trackTwo(_ core: KiwiCore) {
        for id: UInt32 in [1, 3] {
            core.state.windows.upsert(
                ManagedWindow(
                    id: WindowID(id),
                    pid: pid,
                    appName: "Safari",
                    appBundleID: bundle
                )
            )
            core.state.workspaces.add(WindowID(id), to: "1")
        }
        core.state.departedSlots[WindowID(1)] = 0
        core.state.departedSlots[WindowID(3)] = 2
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.frontmostPIDProvider = { self.pid }
    }

    @Test("the cycle ring holds the away window by rank and reaches it")
    func cycleReaches() {
        let (core, touches) = makeCore()
        defer { teardown() }
        trackTwo(core)
        park(core, touches, 2, rank: 1)
        press(core)
        // 1 → 2: the away window is next by rank, so the press
        // reaches it rather than focusing 3.
        #expect(Bridge.switches.map(\.0) == [11])
        #expect(core.followFocus.owed() == WindowID(2))
        #expect(touches.activated.isEmpty)
    }

    /// The bridge is present but declines the switch: the press
    /// falls through to the plain activate rather than dying in
    /// the cycle. (A `guard canDriveDesktops` inside the reach is
    /// defence in depth this fixture cannot see — an absent
    /// resolver refuses through the bridge's own nil anyway.)
    @Test("a refused reach falls through to the activate")
    func refusedReachFallsThrough() {
        let (core, touches) = makeCore(bridge: .refusing)
        defer { teardown() }
        trackTwo(core)
        park(core, touches, 2, rank: 1)
        press(core)
        #expect(Bridge.switches.isEmpty)
        #expect(core.followFocus.owed() == nil)
        #expect(core.state.workspaces["1"]?.focused == WindowID(1))
        #expect(touches.activated == [pid])
    }

    @Test("without the bridge the ring is the tracked windows alone")
    func noBridgeRingIsTracked() {
        let (core, touches) = makeCore(bridge: .absent)
        defer { teardown() }
        trackTwo(core)
        park(core, touches, 2, rank: 1)
        press(core)
        #expect(core.state.workspaces["1"]?.focused == WindowID(3))
        #expect(core.followFocus.owed() == nil)
    }
}
