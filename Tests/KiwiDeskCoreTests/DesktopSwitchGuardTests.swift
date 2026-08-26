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

private let bridgeClasses: [String: AnyClass] = [
    "CopyManagedDisplaySpacesOperation":
        FakeCopyManagedDisplaySpaces.self,
    "ManagedDisplaySetCurrentSpaceOperation":
        FakeSetCurrentSpace.self,
    "HideSpacesOperation": FakeHideSpaces.self,
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
                // The class resolves; the bridge declines to
                // dispatch — "performed is not applied".
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
            isCurrent: false,
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
