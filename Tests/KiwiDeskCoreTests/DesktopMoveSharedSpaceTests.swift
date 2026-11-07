import AppKit
import Testing

@testable import KiwiDeskCore

/// A named Space on shared Desktops (#3033), through the real
/// dispatch. Every Desktop files under `Main`, which names no screen;
/// Desktop 1 is shown, Desktop 2 hidden, and the window's Space lays
/// out on screen 1.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move naming a Space, shared Desktops (#3033)", .serialized)
@MainActor
struct DesktopMoveSharedSpaceTests {
    private let mail = SpaceID("mail")
    private let window = WindowID(7)
    private let refusal =
        "Screens can only be crossed through the visible Desktop. "
        + "Cross there first, then move the window."

    private func makeCore() -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = [
            authoritySpace(10, display: "Main", current: true),
            authoritySpace(11, display: "Main"),
        ]
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = { desktopVerbBridgeClasses[$0] }
        let core = makeTestCore()
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
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: window, pid: 1, appName: "App")
            )
        )
        let origin = core.state.workspaces.space(of: window)!
        core.state.workspaces.assign(origin, to: DisplayID(1))
        return core
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    @Test("a hidden Desktop refuses a Space on another screen")
    func hiddenRefusesAnotherScreen() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.assign(mail, to: DisplayID(2))
        for verb in ["move_to_desktop", "move_to_desktop_and_follow"] {
            let response = core.execute(
                verb,
                args: [.number(2), .string("mail")]
            )
            expectEqual(response.error, refusal)
        }
        #expect(DesktopVerbBridge.moves.isEmpty)
        #expect(core.pendingSpace.isEmpty)
    }

    @Test("a hidden Desktop takes a Space on the window's screen")
    func hiddenTakesTheWindowsScreen() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.assign(mail, to: DisplayID(1))
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string("mail")]
            ).isSuccess
        )
        expectEqual(DesktopVerbBridge.moves.count, 1)
    }

    @Test("a hidden Desktop with no Space named still moves")
    func hiddenNamingNothingMoves() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("move_to_desktop", args: [.number(2)]).isSuccess)
        expectEqual(DesktopVerbBridge.moves.count, 1)
    }

    @Test("a shown Desktop crosses to a Space on another screen")
    func shownCrosses() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.assign(mail, to: DisplayID(2))
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail")]
            ).isSuccess
        )
        expectEqual(core.state.workspaces.space(of: window), mail)
    }

    /// One screen is never a crossing, whatever its frame reads: a
    /// refusal here would reach every single-screen user.
    @Test("one screen never refuses, with no screen read")
    func oneScreenNeverRefuses() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.removeDisplay(DisplayID(2))
        core.state.workspaces.assign(mail, to: DisplayID(1))
        core.state.apply(.windowDestroyed(window, wasMinimized: false))
        core.state.rememberedSpaces[window] = nil
        core.state.awayWindows[window] = AwayWindow(
            id: window,
            pid: 1,
            appName: "App",
            appBundleID: nil,
            title: "",
            nativeSpace: 11
        )
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string("mail"), .number(7)]
            ).isSuccess
        )
    }

    /// The frame outranks the Space, since the frame is what the
    /// arrival reads: a window sitting on another screen than its
    /// Space's is judged where it sits.
    @Test("the window's frame decides its screen")
    func frameDecides() throws {
        let core = makeCore()
        defer { teardown() }
        let screen = try #require(ScreenList.all.first)
        let shown = try #require(screen.kiwiDisplayID)
        let frame = GeometryUtils.axVisibleFrame(of: screen)
        core.state.windows.updateFrame(window, frame: frame)
        let home = try #require(core.state.workspaces.space(of: window))
        core.state.workspaces.assign(home, to: DisplayID(UInt32.max))
        core.state.workspaces.assign(mail, to: shown)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string("mail")]
            ).isSuccess
        )
    }
}
