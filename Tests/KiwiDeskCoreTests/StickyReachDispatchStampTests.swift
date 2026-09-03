import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)

private enum Bridge {
    /// Every dispatched MOVE, recorded on `perform`.
    nonisolated(unsafe) static var moves: [([NSNumber], UInt64)] = []

    static func reset() { moves = [] }
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

private final class FakeSetCurrentSpace: NSObject {
    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: String, spaceID: UInt64) {}
    @objc func performWithWMBridgeDelegate() {}
}

private final class FakeHideSpaces: NSObject {
    @objc(initWithSpaces:)
    init(spaces: [NSNumber]) {}
    @objc func performWithWMBridgeDelegate() {}
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
    "HideSpacesOperation": FakeHideSpaces.self,
    "MoveWindowsToManagedSpaceOperation": FakeMoveWindows.self,
]

// MARK: - Suite

/// Our own switch dispatch promises the carry's flight (#1213):
/// `switchDesktop` stamps every window the carry WILL move as in
/// flight the moment the bridge accepts the set — before any
/// notification or move — scoped to the switching screen the way
/// the carry is (#445's render screen); a refused set promises
/// nothing. The argument is accessibility.md's carried arm.
///
/// The fixture is `StickyReachCarryVerdictTests`': Desktops 1–2
/// on `UUID-A` (ids 10, 11), 3–4 on `UUID-B` (ids 20, 21); space
/// "1" on display 1 (A), "5" on display 2 (B); windows 1 (∞), 2
/// (📌) and 3 (plain) homed on A, 4 (📌) on B. Serialized,
/// synchronous bodies — the resolver and the space overrides are
/// process-global (`DesktopCommandTests`' note).
@Suite("Sticky reach in flight from the switch dispatch (#1213)", .serialized)
@MainActor
struct StickyReachDispatchStampTests {
    private let w1 = WindowID(1)
    private let w2 = WindowID(2)
    private let w3 = WindowID(3)
    private let w4 = WindowID(4)

    private final class Box {
        var lines: [String] = []
    }

    private func makeCore(
        resolver: @escaping (String) -> AnyClass? = { bridgeClasses[$0] }
    ) -> KiwiCore {
        Bridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        NativeSpaces.activeSpaceIsUserOverride = true
        pinTwoDisplays()
        WMBridge.classResolverOverride = resolver
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
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("an accepted switch stamps the switched screen's carried windows")
    func acceptedSwitchStampsItsScreensWindows() {
        let core = makeCore()
        defer { teardown() }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        // A reach-off sticky window on the same screen: the
        // display filter admits it, only the carry's verdict
        // excludes it — the one shape that tells the stamp's
        // own set from the reader's re-intersection
        // (guard-prover, 2026-09-02).
        core.state.stickyReachOverrides[w2] = false
        #expect(core.eventLoop.carriedWindows().isEmpty)
        #expect(
            core.execute("focus_desktop", args: [.number(2)]).isSuccess
        )
        // The ∞ window renders on the active space's screen (A);
        // the pinned-off 📌 window, the plain window and B's 📌
        // window are not this switch's to carry.
        #expect(core.eventLoop.carriedWindows() == [w1])
        // The dispatch's OWN stamp: no carry has run — the
        // handler fires on the OS notification, which no test
        // sends — so nothing was moved.
        #expect(Bridge.moves.isEmpty)
        // The WHOLE line: the reader re-intersects with the
        // verdict, so this line is the one witness of the
        // stamp's own set.
        #expect(
            box.lines.contains(
                "reach: in flight for the dispatched switch: w1"
            )
        )
    }

    /// The stamp classifies off the verb's ONE reading (profiles.md):
    /// a target whose reading names no screen stamps nothing, even
    /// while the live topology still holds two displays — a stamp
    /// re-reading `NativeSpaces.allSpaces()` would stamp w1 w2 here.
    @Test("the stamp reads the target's topology, never the live one")
    func stampReadsTheTargetsTopology() {
        let core = makeCore()
        defer { teardown() }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        let target = KiwiCore.DesktopTarget(
            space: 11,
            displayIdentifier: "UUID-A",
            originSpace: 10,
            spaces: []
        )
        _ = core.switchDesktop(to: target, verb: "focus_desktop")
        #expect(core.eventLoop.carriedWindows().isEmpty)
        #expect(
            !box.lines.contains {
                $0.contains("in flight for the dispatched switch")
            }
        )
    }

    @Test("a switch of the other screen stamps only its own windows")
    func otherScreensSwitchStampsItsOwn() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute("focus_desktop", args: [.number(4)]).isSuccess
        )
        #expect(core.eventLoop.carriedWindows() == [w4])
    }

    @Test("a refused set promises nothing")
    func refusedSetStampsNothing() {
        // The set class does not resolve: the bridge refuses the
        // switch, nothing will move, so nothing may be expected
        // to vanish — ⌘W of a sticky window stays instant.
        let core = makeCore(resolver: { name in
            name == "ManagedDisplaySetCurrentSpaceOperation"
                ? nil : bridgeClasses[name]
        })
        defer { teardown() }
        #expect(
            !core.execute("focus_desktop", args: [.number(2)]).isSuccess
        )
        #expect(core.eventLoop.carriedWindows().isEmpty)
    }

    @Test("a Desktop already shown promises nothing")
    func alreadyShownStampsNothing() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute("focus_desktop", args: [.number(1)]).isSuccess
        )
        #expect(core.eventLoop.carriedWindows().isEmpty)
    }

    @Test("the stamp takes the carry's own verdict")
    func stampFollowsTheCarryVerdict() {
        let core = makeCore()
        defer { teardown() }
        // A native-fullscreen window travels nowhere (#670), so
        // it is promised nothing either.
        core.state.apply(
            .windowFullscreenChanged(w1, isFullscreen: true)
        )
        #expect(
            core.execute("focus_desktop", args: [.number(2)]).isSuccess
        )
        #expect(core.eventLoop.carriedWindows() == [w2])
    }

    @Test("reach switched off promises nothing")
    func reachOffStampsNothing() {
        let core = makeCore()
        defer { teardown() }
        core.tiler.settings.stickyStyle.desktopReach = false
        #expect(
            core.execute("focus_desktop", args: [.number(2)]).isSuccess
        )
        #expect(core.eventLoop.carriedWindows().isEmpty)
    }
}
