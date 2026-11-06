import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// What naming a window on a Desktop move does to the focus (#2888),
/// and the follow, through the real dispatch, over the topology
/// `DesktopMoveNamedWindowTests` states.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move naming a window: focus (#2888)", .serialized)
@MainActor
struct DesktopMoveNamedFocusTests {
    private let focused = WindowID(7)
    private let named = WindowID(8)
    private var id: JSONValue { .number(Double(named.raw)) }

    private func makeCore() -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        let core = makeTestCore()
        for (window, pid) in [(named, pid_t(2)), (focused, pid_t(1))] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(id: window, pid: pid, appName: "App")
                )
            )
        }
        core.state.apply(.windowFocused(focused))
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    /// Files `named` into Space `2`, leaving the focus alone.
    private func parkNamed(_ core: KiwiCore) {
        core.execute("move_to_space", args: [.string("2"), id])
    }

    @Test("a window filed into the active Space takes focus")
    func filedIntoActiveTakesFocus() {
        let core = makeCore()
        defer { teardown() }
        parkNamed(core)
        #expect(core.state.workspaces.space(of: named) == SpaceID("2"))
        #expect(core.focusedWindowID == focused)
        let active = core.state.workspaces.activeSpace
        core.eventLoop.lastCommandedFocus = nil
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string(active?.raw ?? ""), id]
        )
        #expect(response.isSuccess)
        #expect(core.state.workspaces.space(of: named) == active)
        #expect(core.focusedWindowID == named)
        // The filing moved the state focus alone: only the raise,
        // told the anchor it left, stamps the command.
        #expect(core.eventLoop.lastCommandedFocus != nil)
    }

    @Test("a stale lastFocused does not excuse the raise")
    func staleLastFocusedStillRaises() {
        let core = makeCore()
        defer { teardown() }
        // `lastFocused` stays on the window a switch left behind.
        core.execute("focus_space", args: [.string("3")])
        #expect(core.focusedWindowID == nil)
        #expect(core.state.workspaces.lastFocused == focused)
        // The raise asks its gate; the filing alone never does.
        var asked: [WindowID] = []
        core.windowIsOnScreen = {
            asked.append($0)
            return nil
        }
        let response = core.execute(
            "move_to_desktop",
            args: [
                .number(1), .string("3"), .number(Double(focused.raw)),
            ]
        )
        #expect(response.isSuccess)
        #expect(core.focusedWindowID == focused)
        #expect(asked.contains(focused))
    }

    @Test("another screen's shown Desktop changes no focus")
    func rehomeKeepsFocus() {
        let core = makeCore()
        defer { teardown() }
        let home = core.state.workspaces.activeSpace ?? SpaceID("1")
        for (raw, x) in [(UInt32(1), CGFloat(0)), (2, 1728)] {
            core.state.workspaces.upsertDisplay(
                Display(
                    id: DisplayID(raw),
                    name: "Screen \(raw)",
                    frame: CGRect(x: x, y: 0, width: 1728, height: 1080)
                )
            )
        }
        core.state.workspaces.ensureSpace(SpaceID("5"))
        core.state.workspaces.assign(home, to: DisplayID(1))
        core.state.workspaces.assign(SpaceID("5"), to: DisplayID(2))
        // Parks 5 as the second screen's shown Space.
        core.state.workspaces.activate(SpaceID("5"))
        core.state.workspaces.activate(home)
        let response = core.execute(
            "move_to_desktop",
            args: [.number(3), .null, id]
        )
        #expect(response.isSuccess)
        #expect(core.state.workspaces.space(of: named) == SpaceID("5"))
        #expect(core.focusedWindowID == focused)
        #expect(core.state.workspaces.lastFocused == focused)
    }

    @Test("a shown Desktop's move that files nothing keeps the focus")
    func noFilingKeepsFocus() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .null, id]
        )
        #expect(response.isSuccess)
        #expect(core.focusedWindowID == focused)
    }

    @Test("a hidden Desktop's move keeps the focus")
    func hiddenKeepsFocus() {
        let core = makeCore()
        defer { teardown() }
        let active = core.state.workspaces.activeSpace
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .string(active?.raw ?? ""), id]
        )
        #expect(response.isSuccess)
        #expect(core.focusedWindowID == focused)
    }

    // MARK: - The follow

    @Test("a follow onto a hidden Desktop owes the named window")
    func followOwesTheNamedWindow() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(2), .null, id]
        )
        #expect(response.isSuccess)
        #expect(core.followFocus.claim(if: { $0 == named }) == named)
    }

    @Test("a refused follow of a named window owes its bookkeeping")
    func refusedFollowKeepsTheBookkeeping() {
        let core = makeCore()
        defer { teardown() }
        WMBridge.classResolverOverride = { name in
            name == "ManagedDisplaySetCurrentSpaceOperation"
                ? nil : desktopVerbBridgeClasses[name]
        }
        // Asked at the press: a starved run outlasts the latch.
        let now = Date()
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(2), .null, id]
        )
        #expect(!response.isSuccess)
        #expect(core.moveLatch.isLatched(named, at: now))
        #expect(core.deferred.isScheduled(.desktopMoveReap))
        #expect(core.desktopMoveDepartures[named] != nil)
    }

    @Test("an already-shown follow of an unfocused window focuses it")
    func alreadyShownFocusesIt() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(1), .null, id]
        )
        #expect(response.isSuccess)
        #expect(core.focusedWindowID == named)
    }

    @Test("an already-shown follow into a parked Space switches there")
    func alreadyShownSwitchesToItsSpace() {
        let core = makeCore()
        defer { teardown() }
        parkNamed(core)
        #expect(core.state.workspaces.space(of: named) == SpaceID("2"))
        #expect(core.focusedWindowID == focused)
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(1), .null, id]
        )
        #expect(response.isSuccess)
        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(core.focusedWindowID == named)
        #expect(core.deferred.isScheduled(.spaceSettle))
    }

    @Test("a focused follow naming an unshown Space switches whole")
    func focusedFollowToUnshownSpace() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.ensureSpace(SpaceID("3"))
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(1), .string("3")]
        )
        #expect(response.isSuccess)
        #expect(core.state.workspaces.activeSpace == SpaceID("3"))
        #expect(core.focusedWindowID == focused)
        #expect(core.deferred.isScheduled(.spaceSettle))
    }
}
