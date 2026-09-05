import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)
//
// A per-file copy, as tests.md prefers (`DesktopFollowTests` has
// the twin). These only accept; nothing here asserts on WHAT was
// dispatched.

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

/// The composed `space:` target of the Desktop move verbs (#1150),
/// end to end through the real dispatch and fold. The topology is
/// the #888 fixture (Desktops 1–2 on `UUID-A`, ids 10/11; 3–4 on
/// `UUID-B`, ids 20/21), Desktop 1 and 3 shown — so Desktop 2 is
/// a HIDDEN target on the main screen and Desktop 1 a SHOWN one.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move with an explicit Space (#1150)", .serialized)
@MainActor
struct DesktopMoveSpaceTargetTests {
    private final class Box {
        var lines: [String] = []
    }

    private let mail = SpaceID("mail")
    private let window = WindowID(7)

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { bridgeClasses[$0] }
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "App")
            )
        )
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// The fixture's two screens, matching `pinTwoDisplays`'
    /// UUID map, so a Space can be assigned to either.
    private func addDisplays(_ core: KiwiCore) {
        for (index, name) in ["A", "B"].enumerated() {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(UInt32(index + 1)),
                    name: name,
                    frame: CGRect(
                        x: CGFloat(index) * 1920,
                        y: 0,
                        width: 1920,
                        height: 1080
                    )
                )
            )
        }
    }

    @Test("A hidden target's Space is paid at the departure")
    func hiddenTargetFilesAtTheDeparture() {
        let core = makeCore()
        defer { teardown() }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        let origin = core.state.workspaces.space(of: window)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string("mail")]
            ).isSuccess
        )
        // Not a member yet — the reveal reconcile owns the
        // arrival, and an eager write would fight it.
        #expect(core.state.workspaces.space(of: window) == origin)
        #expect(
            box.lines.contains { $0.contains("will join space mail") }
        )
        // The reap's departure: the fold records the origin and
        // the gone handler re-files it under the name.
        core.handle(.windowDestroyed(window, wasMinimized: false))
        #expect(core.state.rememberedSpace(of: window) == mail)
        // …and the arrival lands there through the ordinary
        // remembered-space rule.
        core.handle(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "App")
            )
        )
        #expect(core.state.workspaces.space(of: window) == mail)
    }

    @Test("A shown target's Space is joined now")
    func shownTargetFilesNow() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail")]
            ).isSuccess
        )
        #expect(core.state.workspaces.space(of: window) == mail)
        #expect(core.pendingSpace.isEmpty)
    }

    @Test("A follow to a hidden target files the eager departure")
    func followFilesTheEagerDeparture() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(2), .string("mail")]
            ).isSuccess
        )
        // The eager departure ran synchronously (#1023), and the
        // name was paid into it.
        #expect(core.state.windows[window] == nil)
        #expect(core.state.rememberedSpace(of: window) == mail)
        #expect(core.pendingSpace.isEmpty)
    }

    @Test("A Space on another screen than the Desktop's is refused")
    func spaceOnAnotherScreenIsRefused() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        core.state.workspaces.assign(mail, to: DisplayID(2))
        let origin = core.state.workspaces.space(of: window)
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string("mail")]
        )
        #expect(!response.isSuccess)
        #expect(core.state.workspaces.space(of: window) == origin)
        #expect(core.pendingSpace.isEmpty)
    }

    /// Control: the one-argument form still files the departure
    /// under the Space the window left.
    @Test("Without a Space the departure keeps its origin")
    func noSpaceKeepsTheOrigin() {
        let core = makeCore()
        defer { teardown() }
        let origin = core.state.workspaces.space(of: window)
        #expect(
            core.execute("move_to_desktop", args: [.number(2)])
                .isSuccess
        )
        core.handle(.windowDestroyed(window, wasMinimized: false))
        #expect(core.state.rememberedSpace(of: window) == origin)
    }

    /// An unassigned Space lays out on the MAIN screen, so a
    /// fresh Space named for a secondary screen's Desktop would
    /// carry the window back there (#1010 by another door): the
    /// route homes it once the bridge accepted.
    @Test("A new Space is homed to the Desktop's screen")
    func newSpaceIsHomedToTheDesktopsScreen() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        #expect(core.state.workspaces[mail] == nil)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(4), .string("mail")]
            ).isSuccess
        )
        #expect(core.state.workspaces[mail] != nil)
        #expect(
            core.state.workspaces.display(of: mail) == DisplayID(2)
        )
    }

    /// The explicit Space is a membership write, so it takes the
    /// one sticky gate `move_to_space` takes — and the whole
    /// command is refused, the window staying put, with no Space
    /// created by a parse that never writes.
    @Test("A sticky window's explicit Space refuses the move")
    func stickyWindowRefusesTheExplicitSpace() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("make_sticky").isSuccess)
        let origin = core.state.workspaces.space(of: window)
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .string("mail")]
        )
        #expect(!response.isSuccess)
        #expect(core.state.windows[window] != nil)
        #expect(core.state.workspaces.space(of: window) == origin)
        #expect(core.state.workspaces[mail] == nil)
        #expect(core.pendingSpace.isEmpty)
    }

    @Test("An empty Space id is refused")
    func emptySpaceIsRefused() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            !core.execute(
                "move_to_desktop",
                args: [.number(2), .string("")]
            ).isSuccess
        )
        #expect(core.pendingSpace.isEmpty)
    }
}
