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

// MARK: - Suite

/// `focus_app_window` reaches the app's window UP on a Desktop
/// no screen shows (#3131 over #1146): the ring holds it by
/// rank, and a step onto it switches that Desktop over the
/// bridge, owing the window its focus, and logs under the
/// calling verb. The topology is the #888 fixture
/// `OpenOrFocusReachTests` uses: Desktops 1–2 on `UUID-A` (ids
/// 10, 11), 3–4 on `UUID-B` (ids 20, 21). The fakes are that
/// suite's, copied per tests.md.
@Suite("Focus app window reach (#3131)", .serialized)
@MainActor
struct FocusAppWindowReachTests {
    private let pid: pid_t = 100
    private let bundle = "app.test.safari"

    /// Tracked 1 (rank 0) and 3 (rank 2) in Space 1, 1 focused;
    /// 2 away on Desktop 2 at rank 1, between them.
    private func makeCore(
        bridge: BridgeShape = .present
    ) -> KiwiCore {
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
        var hosts: [WindowID: DesktopCensus.Host] = [:]
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
        core.state.departedSlots[WindowID(1)] = .init(rank: 0)
        core.state.departedSlots[WindowID(3)] = .init(rank: 2)
        core.state.awayWindows[WindowID(2)] = AwayWindow(
            id: WindowID(2),
            pid: pid,
            appName: "Safari",
            appBundleID: bundle,
            nativeSpace: 11
        )
        core.state.rememberedSpaces[WindowID(2)] = .departed("1")
        core.state.departedSlots[WindowID(2)] = .init(rank: 1)
        hosts[WindowID(2)] = DesktopCensus.Host(
            space: 11,
            pid: pid,
            isUp: true
        )
        core.desktopMemory.readCensus = { spaces in
            DesktopCensus(
                hosts: hosts,
                shown: Set(spaces.filter(\.isCurrent).map(\.id))
            )
        }
        core.state.workspaces.focus(WindowID(1), in: "1")
        core.frontmostPIDProvider = { self.pid }
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("next onto the away window reaches its Desktop")
    func nextReachesAway() {
        let core = makeCore()
        defer { teardown() }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        #expect(
            core.execute("focus_app_window", args: [.string("next")])
                .isSuccess
        )
        #expect(Bridge.switches.map(\.0) == [11])
        #expect(core.followFocus.owed() == WindowID(2))
        // The reach logs under the verb that called it.
        #expect(
            lines.contains { $0.hasPrefix("focus_app_window: reaching w2") }
        )
        #expect(!lines.contains { $0.hasPrefix("focus_or_spawn:") })
    }

    @Test("prev from the far end reaches the same away window")
    func prevReachesAway() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.focus(WindowID(3), in: "1")
        #expect(
            core.execute("focus_app_window", args: [.string("prev")])
                .isSuccess
        )
        #expect(Bridge.switches.map(\.0) == [11])
        #expect(core.followFocus.owed() == WindowID(2))
    }

    @Test("a refused reach is refused by its rule, focus unmoved")
    func refusedReachRefuses() {
        let core = makeCore(bridge: .refusing)
        defer { teardown() }
        #expect(
            core.execute("focus_app_window", args: [.string("next")])
                == .fail(
                    "the app's next window is on a Desktop that "
                        + "could not be switched to"
                )
        )
        #expect(Bridge.switches.isEmpty)
        #expect(core.followFocus.owed() == nil)
        #expect(core.state.workspaces.lastFocused == WindowID(1))
    }

    @Test("without the bridge the ring is the tracked windows")
    func noBridgeSkipsAway() {
        let core = makeCore(bridge: .absent)
        defer { teardown() }
        #expect(
            core.execute("focus_app_window", args: [.string("next")])
                .isSuccess
        )
        #expect(Bridge.switches.isEmpty)
        #expect(core.state.workspaces.lastFocused == WindowID(3))
    }
}
