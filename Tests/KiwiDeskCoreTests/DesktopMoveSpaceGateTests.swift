import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)
//
// A per-file copy, as tests.md prefers (`DesktopFollowTests` and
// `DesktopMoveSpaceTargetTests` have the twins). These only
// accept; nothing here asserts on WHAT was dispatched.

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

/// The composed `space:` target's PARSE and GATE (#1150) — the
/// refusals and the sticky gate's landing thread; the routes are
/// `DesktopMoveSpaceTargetTests`'. Split at the §2.1 ceiling. The topology is
/// the #888 fixture (Desktops 1–2 on `UUID-A`, ids 10/11; 3–4 on
/// `UUID-B`, ids 20/21), Desktop 1 and 3 shown — so Desktop 2 is
/// a HIDDEN target on the main screen and Desktop 1 a SHOWN one.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move explicit-Space refusals (#1150)", .serialized)
@MainActor
struct DesktopMoveSpaceGateTests {
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

    /// An unowned Space has no settled screen while two are
    /// connected — the layout falls back to the key window's, the
    /// placement resolve to the menu bar's — so naming one for
    /// ANY Desktop is refused with the pin hint, creating nothing.
    @Test("An unowned Space on two screens is refused")
    func unownedSpaceOnTwoScreensIsRefused() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        for desktop in [2, 4] {
            let response = core.execute(
                "move_to_desktop",
                args: [.number(Double(desktop)), .string("mail")]
            )
            #expect(!response.isSuccess)
            #expect(response.error?.contains("no screen yet") == true)
        }
        #expect(core.state.workspaces[mail] == nil)
        #expect(core.pendingSpace.isEmpty)
    }

    /// On ONE screen every reading agrees, so the same unowned
    /// Space is accepted — and created at the CLAIM, unassigned,
    /// never at the record.
    @Test("An unowned Space on one screen is created at the claim")
    func unownedSpaceOnOneScreenIsCreated() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        #expect(core.state.workspaces[mail] == nil)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string("mail")]
            ).isSuccess
        )
        #expect(core.state.workspaces[mail] == nil)
        core.handle(.windowDestroyed(window, wasMinimized: false))
        #expect(core.state.workspaces[mail] != nil)
        #expect(core.state.workspaces.display(of: mail) == nil)
        #expect(core.state.rememberedSpace(of: window) == mail)
    }

    /// The gate is handed where the Space WILL lay out: a
    /// display-sticky window on screen A, named into a Space
    /// assigned to screen A, is the move its scope forbids.
    @Test("A display-sticky window is refused a Space on its screen")
    func displayStickyRefusedASpaceOnItsOwnScreen() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        let origin = core.state.workspaces.space(of: window)!
        core.state.workspaces.assign(origin, to: DisplayID(1))
        core.state.workspaces.assign(mail, to: DisplayID(1))
        #expect(core.execute("make_display_sticky").isSuccess)
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .string("mail")]
        )
        #expect(!response.isSuccess)
        #expect(response.error?.contains("sticky") == true)
        #expect(core.state.workspaces.space(of: window) == origin)
        #expect(core.pendingSpace.isEmpty)
    }

    /// Where the carried landing and the gate's own ledger read
    /// DISAGREE: an unowned Space on one screen lands on that
    /// screen, while the ledger reads nil — "elsewhere" to the
    /// gate — so a display-sticky window would slip into another
    /// Space on its own screen unless the gate is handed the
    /// landing (guard-prover, 2026-09-05).
    @Test("The gate is handed an unowned Space's single-screen landing")
    func displayStickyRefusedAnUnownedSpaceOnOneScreen() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        let origin = core.state.workspaces.space(of: window)!
        core.state.workspaces.assign(origin, to: DisplayID(1))
        #expect(core.execute("make_display_sticky").isSuccess)
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .string("mail")]
        )
        #expect(!response.isSuccess)
        #expect(response.error?.contains("sticky") == true)
        #expect(core.state.workspaces[mail] == nil)
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
        #expect(response.error?.contains("sticky") == true)
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
