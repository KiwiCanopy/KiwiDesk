import ApplicationServices
import Foundation
import Testing

@testable import KiwiDeskCore

// MARK: - Bridge fakes (the resolver seam, never the machine)
//
// A per-file copy, as tests.md prefers — split from
// `DesktopSwitchGuardTests` at the §2.1 ceiling when the #1007
// follow-focus tests joined it. These fakes only accept; the
// suites asserting on WHAT was dispatched live with the
// recording twins.

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

/// The follow verb's departure and arrival, end to end through
/// the real dispatch and fold (#1007/#1023): the eager departure
/// stands the close-return raise down (witnessed through the
/// narration's own verdict), and the focus debt a hidden-target
/// follow records is paid at the window's arrival as a space
/// switch.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests`
/// applies, and a future async body here owes a different one.
/// The topology is the #888 fixture (Desktops 1–2 on `UUID-A`,
/// ids 10/11; 3–4 on `UUID-B`, ids 20/21).
@Suite("Desktop follow departure and arrival (#1007)", .serialized)
@MainActor
struct DesktopFollowTests {
    private final class Box {
        var lines: [String] = []
    }

    private func makeCore() -> KiwiCore {
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { bridgeClasses[$0] }
        return makeTestCore()
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("A hidden-target follow owes a focus, paid at the arrival")
    func followDebtIsPaidAtTheArrival() {
        let core = makeCore()
        defer { teardown() }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
            )
        )
        // The follow records the debt (#1007) — narrated at the
        // record, so a device trace can pair it with the payment.
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(4)]
            ).isSuccess
        )
        #expect(
            box.lines.contains { $0.contains("owing focus to w7") }
        )
        // …and the ARRIVAL pays it, end-to-end through the real
        // dispatch and fold: the reveal's reconcile re-lists the
        // window, the create fold adopts it, and the payer hands
        // focus over as a space switch.
        core.handle(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
            )
        )
        #expect(
            box.lines.contains { $0.contains("focus handed to w7") }
        )
        // Paid once: a second arrival of the same id is an
        // ordinary create and hands nothing.
        box.lines = []
        core.handle(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
            )
        )
        #expect(
            !box.lines.contains { $0.contains("focus handed") }
        )
    }

    @Test("The eager departure raises no origin successor")
    func eagerDepartureRaisesNoSuccessor() {
        let core = makeCore()
        defer { teardown() }
        let box = Box()
        core.onLog = { box.lines.append($0) }
        // Successor first, mover second — the spawn grant gives
        // the LAST created window the focus, so removing w7
        // hands the space's focus back to w9, which is the
        // close-return raise's exact trigger. At t=0 of the
        // switch the origin is still composited, so the raise
        // would fight the follow the user just asked for; the
        // stand-down's third arm refuses it (#1023, and #936's
        // one-predicate rule covers the restore arm with it).
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(9), pid: 1, appName: "App")
            )
        )
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(7), pid: 1, appName: "App")
            )
        )
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(4)]
            ).isSuccess
        )
        #expect(core.state.windows[WindowID(7)] == nil)
        // The WITNESS is the narration, which fires for every
        // focus-lost removal and prints the predicate's own
        // verdict — located by what the fixture cannot lose
        // (guard-prover round 3: the raise site itself sits
        // behind a live-AX gate no unit fixture reaches, so an
        // absence-of-raise clause is vacuous here).
        #expect(
            box.lines.contains { $0.contains("standsDown=true") }
        )
        // Belt only — vacuously green in this fixture; the
        // clause above is what discriminates.
        #expect(
            !box.lines.contains { $0.contains("close-return: raising") }
        )
        // And the latch is a SPAN, not a state: it must not
        // outlive the fold, or every later genuine close would
        // stand its raise down too.
        #expect(core.eventLoop.eagerDepartureInFlight == nil)
    }
}
