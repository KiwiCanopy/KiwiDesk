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

    /// The Space is created only once the bridge accepted the
    /// move — a refused bridge leaves no Space and no record.
    @Test("A bridge refusal creates nothing")
    func bridgeRefusalCreatesNothing() {
        let core = makeCore()
        defer { teardown() }
        WMBridge.classResolverOverride = {
            $0 == "MoveWindowsToManagedSpaceOperation"
                ? nil : bridgeClasses[$0]
        }
        let origin = core.state.workspaces.space(of: window)
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .string("mail")]
        )
        #expect(!response.isSuccess)
        #expect(response.error?.contains("bridge") == true)
        #expect(core.state.workspaces[mail] == nil)
        #expect(core.state.workspaces.space(of: window) == origin)
        #expect(core.pendingSpace.isEmpty)
    }

    /// An expired name is dropped at the departure and leaves no
    /// empty Space behind — the Space is created at the CLAIM.
    @Test("An expired name leaves no Space behind")
    func expiredNameLeavesNoSpace() {
        let core = makeCore()
        defer { teardown() }
        let origin = core.state.workspaces.space(of: window)
        core.pendingSpace.record(
            window,
            space: mail,
            at: Date(
                timeIntervalSinceNow:
                    -PendingSpaceAssignment.drainWindow - 1
            )
        )
        core.handle(.windowDestroyed(window, wasMinimized: false))
        #expect(core.state.rememberedSpace(of: window) == origin)
        #expect(core.state.workspaces[mail] == nil)
    }

    /// A departure the redirect does not take — a minimize, which
    /// the fold records as no remembered Space — creates nothing:
    /// the Space is made only for a filing that happened.
    @Test("A minimized departure with a pending name creates nothing")
    func minimizedDepartureCreatesNothing() {
        let core = makeCore()
        defer { teardown() }
        core.pendingSpace.record(window, space: mail)
        core.handle(.windowDestroyed(window, wasMinimized: true))
        #expect(core.state.workspaces[mail] == nil)
        #expect(core.state.rememberedSpace(of: window) == nil)
        #expect(core.pendingSpace.isEmpty)
    }

    /// At the arrival the #1010 screen-home net still outranks
    /// the name: a Space moved to another screen between the
    /// command and the reveal is exactly what that net exists
    /// for, and the fold asks it before the remembered Space.
    @Test("At the arrival the screen-home net outranks the name")
    func arrivalScreenHomeOutranksTheName() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        let origin = core.state.workspaces.space(of: window)!
        core.state.workspaces.assign(origin, to: DisplayID(1))
        core.state.workspaces.assign(mail, to: DisplayID(2))
        core.state.apply(.windowDestroyed(window, wasMinimized: false))
        core.state.redirectDeparture(of: window, to: mail)
        #expect(core.state.rememberedSpace(of: window) == mail)
        // `mail` exists, so the name is OUTRANKED below rather
        // than dropped by `livingRememberedSpace` — the fold's
        // fallback is the origin too, and only this tells the
        // two apart (guard-prover, 2026-09-05).
        #expect(core.state.workspaces[mail] != nil)
        // The window's frame lands on screen 1, which shows the
        // origin — the net re-homes it there, not into `mail`.
        core.state.arrivalDisplay = DisplayID(1)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "App")
            )
        )
        #expect(core.state.workspaces.space(of: window) == origin)
    }
}
