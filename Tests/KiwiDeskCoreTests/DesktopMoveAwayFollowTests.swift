import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The follow of `DesktopMoveAwayTests`' away window (#3034), over the
/// same fixture. Split at the §2.1 ceiling.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move naming an away window: follow (#3034)", .serialized)
@MainActor
struct DesktopMoveAwayFollowTests {
    private let focused = WindowID(7)
    private let away = WindowID(9)
    private let pid: pid_t = 900_001
    private let mail = SpaceID("mail")
    private var id: JSONValue { .number(Double(away.raw)) }

    private func makeCore(
        spaces: [NativeSpace]? = nil,
        bridge: Bool = true
    ) -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride =
            spaces
            ?? authorityTopology(mainCurrent: 10, secondaryCurrent: 20)
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = {
            bridge ? desktopVerbBridgeClasses[$0] : nil
        }
        let core = makeTestCore()
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: focused, pid: 900_002, appName: "Here")
            )
        )
        core.state.apply(.windowFocused(focused))
        file(core)
        return core
    }

    private func file(_ core: KiwiCore) {
        core.state.awayWindows[away] = AwayWindow(
            id: away,
            pid: pid,
            appName: "Away",
            appBundleID: "com.example.away",
            title: "Elsewhere",
            nativeSpace: 11
        )
    }

    private func teardown() {
        WMBridge.classResolverOverride = nil
        resetAuthorityOverrides()
    }

    private func arrive(_ core: KiwiCore) {
        core.handle(
            .windowCreated(
                ManagedWindow(id: away, pid: pid, appName: "Away")
            )
        )
    }

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

    // MARK: - The follow

    @Test("a follow to a hidden Desktop owes the focus")
    func followHidden() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(4), .null, id]
        )
        #expect(response.isSuccess)
        #expect(core.followFocus.owed() == away)
    }

    /// No reveal comes: the Space switches at the command, whole, and
    /// the reap's arrival takes a plain focus, which owes no #1007 debt.
    @Test("a follow to a shown Desktop switches now, focus at the arrival")
    func followShown() {
        let core = makeCore()
        defer { teardown() }
        core.state.rememberedSpaces[away] = .departed("1")
        core.state.workspaces.ensureSpace(mail)
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(1), .string("mail"), id]
        )
        #expect(response.isSuccess)
        #expect(core.followFocus.owed() == nil)
        #expect(core.state.workspaces.activeSpace == mail)
        arrive(core)
        #expect(core.state.workspaces.space(of: away) == mail)
        #expect(core.focusedWindowID == away)
    }

    /// A Space no screen owns yet is no crossing: on one screen every
    /// reading agrees, and the name stands.
    @Test("a follow keeps a new Space on one screen")
    func followKeepsNewSpaceOnOneScreen() {
        let core = makeCore()
        defer { teardown() }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 1920, height: 1080)
            )
        )
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == mail)
        arrive(core)
        #expect(core.state.workspaces.space(of: away) == mail)
    }

    /// A shown Desktop on another screen than its filing: the follow
    /// lands in the Space that screen shows, as the #1010 net would.
    @Test("a follow across screens lands where that screen shows")
    func followAcrossScreens() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.workspaces.assign("other", to: DisplayID(2))
        core.state.rememberedSpaces[away] = .departed("1")
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(3), .null, id]
            ).isSuccess
        )
        #expect(core.state.workspaces.activeSpace == "other")
    }

    @Test("a follow never switches for a minimized or hidden window")
    func followRefusesParked() {
        let core = makeCore()
        defer { teardown() }
        core.state.awayWindows[away]?.isUp = false
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(4), .null, id]
        )
        #expect(response.error == "Can't follow a minimized or hidden window.")
        #expect(DesktopVerbBridge.moves.isEmpty)
        #expect(core.followFocus.owed() == nil)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(4), .null, id]
            ).isSuccess
        )
    }
}
