import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)
//
// A per-file copy of `DesktopCommandTests`' fakes, as tests.md
// prefers — split off at the §2.1 ceiling when the #1023 switch
// discipline joined that suite.

private enum Bridge {
    nonisolated(unsafe) static var switches: [UInt64] = []
    nonisolated(unsafe) static var hides: [[NSNumber]] = []

    static func reset() {
        switches = []
        hides = []
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

/// Records only when DISPATCHED — "performed is not applied"
/// cuts both ways (see `DesktopCommandTests`' twin).
private final class FakeSetCurrentSpace: NSObject {
    private let space: UInt64

    @objc(initWithDisplayIdentifier:spaceID:)
    init(displayIdentifier: String, spaceID: UInt64) {
        space = spaceID
    }

    @objc func performWithWMBridgeDelegate() {
        Bridge.switches.append(space)
    }
}

private final class FakeHideSpaces: NSObject {
    private let spaces: [NSNumber]

    @objc(initWithSpaces:)
    init(spaces: [NSNumber]) {
        self.spaces = spaces
    }

    @objc func performWithWMBridgeDelegate() {
        Bridge.hides.append(spaces)
    }
}

/// Accepts the move so the refusal under test is the SWITCH's.
private final class FakeMoveWindows: NSObject {
    @objc(initWithWindows:spaceID:)
    init(windows: [NSNumber], spaceID: UInt64) {}

    @objc func performWithWMBridgeDelegate() {}
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

/// The #1023 switch discipline: the pointer write performs no
/// transition, so a switch pairs an ACCEPTED set with the
/// origin's hide — and only an accepted one, because an origin
/// hidden under a refused set is a blank screen; a missing hide
/// capability degrades to the pointer-only switch; and the
/// deferred re-query names a pointer that never moved, only
/// that.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests`
/// applies, and a future async body here owes a different one.
/// The topology is the #888 fixture (Desktops 1–2 on `UUID-A`,
/// ids 10/11; 3–4 on `UUID-B`, ids 20/21).
@Suite("Desktop switch discipline (#1023)", .serialized)
@MainActor
struct DesktopSwitchGuardTests {
    private func makeCore(
        switching: Bool = true,
        hiding: Bool = true
    ) -> KiwiCore {
        Bridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { name in
            if !switching,
                name == "ManagedDisplaySetCurrentSpaceOperation"
            {
                // Capability absent: the class does not resolve,
                // so the dispatch answers false and the verb
                // refuses (os-private-apis.md's nil ⇒ absent).
                return nil
            }
            if !hiding, name == "HideSpacesOperation" {
                return nil
            }
            return bridgeClasses[name]
        }
        return makeTestCore()
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("A refused switch fails, stamps nothing, hides nothing")
    func refusedSwitchFailsAndStampsNothing() {
        let core = makeCore(switching: false)
        defer { teardown() }
        let before = core.lastDesktopSwitch
        let response = core.execute(
            "focus_desktop",
            args: [.number(2)]
        )
        #expect(!response.isSuccess)
        #expect(core.lastDesktopSwitch == before)
        // An unhidden origin under a refused set is the old
        // behavior; an origin hidden under one is a blank
        // screen.
        #expect(Bridge.hides.isEmpty)
        #expect(!core.deferred.isScheduled(.desktopSwitchVerify))
    }

    @Test("A refused switch folds no departure")
    func refusedSwitchFoldsNoDeparture() {
        let core = makeCore(switching: false)
        defer { teardown() }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
            )
        )
        // The move dispatches; the switch refuses — the window
        // is still where the user sees it, so the eager
        // departure fold (#1023's second half) must stand down.
        #expect(
            !core.execute(
                "move_to_desktop_and_follow",
                args: [.number(2)]
            ).isSuccess
        )
        #expect(core.state.windows[WindowID(7)] != nil)
    }

    @Test("A hidden-target follow arms the reveal reap")
    func followToHiddenArmsTheRevealReap() {
        let core = makeCore()
        defer { teardown() }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
            )
        )
        // The switch's own reconcile can fire before the moved
        // window composites on the destination; the adoption
        // heal then quiets the id and nothing ever adopts it.
        // The reap's direct per-pid reconcile is the guaranteed
        // adoption pass (#1023's third half). Desktop 4 is
        // hidden on UUID-B in the fixture; Desktop 1 is current
        // on UUID-A, so the same verb there arms nothing.
        // The event loop knows the window too — the fold must
        // release this registration or every later reconcile
        // treats the window as already known and never re-adopts
        // it (the "ignored until minimized" trace).
        core.eventLoop.elements[1] = [
            WindowID(7): AXUIElementCreateApplication(1)
        ]
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(4)]
            ).isSuccess
        )
        #expect(core.deferred.isScheduled(.desktopMoveReap))
        #expect(core.eventLoop.elements[1]?[WindowID(7)] == nil)
        core.deferred.cancel(.desktopMoveReap)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(8), pid: 1, appName: "App")
            )
        )
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(1)]
            ).isSuccess
        )
        #expect(!core.deferred.isScheduled(.desktopMoveReap))
    }

    @Test("A missing hide capability degrades to the pointer-only switch")
    func missingHideDegradesToPointerOnly() {
        let core = makeCore(hiding: false)
        defer { teardown() }
        #expect(
            core.execute("focus_desktop", args: [.number(2)])
                .isSuccess
        )
        #expect(Bridge.switches == [11])
        #expect(Bridge.hides.isEmpty)
    }

    @Test("The verify names a pointer that never moved, and only that")
    func verifyNamesAnUnmovedPointer() {
        final class Box {
            var lines: [String] = []
        }
        let core = makeCore()
        defer { teardown() }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        let target = KiwiCore.DesktopTarget(
            space: 11,
            displayIdentifier: "UUID-A",
            originSpace: 10
        )
        // The display never left space 10 — the set was dropped
        // somewhere past the bridge.
        NativeSpaces.currentSpaceOverride = { _ in 10 }
        core.verifyDesktopSwitch(to: target, verb: "focus_desktop")
        #expect(box.lines.contains { $0.contains("did not land") })
        // A pointer that DID move stays quiet — the check names
        // failure, never narrates success.
        box.lines = []
        NativeSpaces.currentSpaceOverride = { _ in 11 }
        core.verifyDesktopSwitch(to: target, verb: "focus_desktop")
        #expect(box.lines.isEmpty)
        // An unanswerable read stays quiet too: nil means "no
        // SkyLight", not "the switch failed".
        NativeSpaces.currentSpaceOverride = { _ in nil }
        core.verifyDesktopSwitch(to: target, verb: "focus_desktop")
        #expect(box.lines.isEmpty)
    }
}
