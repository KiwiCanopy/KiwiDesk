import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The follow and focus of `DesktopMoveAwayTests`' away window (#3034),
/// over the same fixture. Split at the §2.1 ceiling.
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
        let now = Date()
        core.followFocus.clock = { now }
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(4), .null, id]
        )
        #expect(response.isSuccess)
        expectEqual(core.followFocus.owed(), away)
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
        expectEqual(core.state.workspaces.activeSpace, mail)
        expectEqual(core.desktopMemory.moveReapPIDs, [pid])
        #expect(core.deferred.isScheduled(.desktopMoveReap))
        arrive(core)
        expectEqual(core.state.workspaces.space(of: away), mail)
        expectEqual(core.focusedWindowID, away)
    }

    /// A Space that holds a focus grants the arrival nothing, so only
    /// the debt can carry the follow's focus onto the window.
    @Test("a follow's focus beats a Space that already holds one")
    func followShownOverAFocus() {
        let core = makeCore()
        defer { teardown() }
        let holder = WindowID(11)
        core.state.apply(
            .windowCreated(
                ManagedWindow(id: holder, pid: 900_003, appName: "Holder")
            )
        )
        core.execute("focus_space", args: [.string("mail")])
        core.state.workspaces.add(holder, to: mail)
        core.state.workspaces.focus(holder, in: mail)
        core.execute("focus_space", args: [.string("1")])
        core.state.rememberedSpaces[away] = .departed("1")
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        expectEqual(core.state.workspaces.activeSpace, mail)
        arrive(core)
        expectEqual(core.focusedWindowID, away)
    }

    /// The window moved and only the switch was refused, so it still
    /// owes the reap, and no focus.
    @Test("a follow whose switch is refused still reaps")
    func followRefusedSwitchReaps() {
        let core = makeCore()
        defer { teardown() }
        WMBridge.classResolverOverride = {
            $0 == "ManagedDisplaySetCurrentSpaceOperation"
                ? nil : desktopVerbBridgeClasses[$0]
        }
        let response = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(4), .null, id]
        )
        #expect(!response.isSuccess)
        expectEqual(DesktopVerbBridge.moves.count, 1)
        #expect(core.followFocus.owed() == nil)
        #expect(core.deferred.isScheduled(.desktopMoveReap))
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
        expectEqual(core.state.workspaces.activeSpace, mail)
        arrive(core)
        expectEqual(core.state.workspaces.space(of: away), mail)
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
        expectEqual(core.state.workspaces.activeSpace, "other")
    }

    /// The ledger can lag the 60 s backstop: the refusal reads a fresh
    /// census, as the Open or Focus reach does.
    @Test("a follow judges a fresh census, not the stored flag")
    func followReadsFreshHost() {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readCensus = { [away, pid] _ in
            DesktopCensus(
                hosts: [
                    away: DesktopCensus.Host(
                        space: 11,
                        pid: pid,
                        isUp: false
                    )
                ],
                shown: [10, 20]
            )
        }
        #expect(
            core.execute(
                "move_to_desktop_and_follow",
                args: [.number(4), .null, id]
            ).error == "Can't follow a minimized or hidden window."
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
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

    // MARK: - The focus

    /// The fold grants the focus in state alone, so without the debt
    /// the next focused verb refuses at the #292 preflight (device,
    /// 2026-11-06).
    @Test("an arrival in a Space with no focus owes the raise")
    func vacantOwesTheRaise() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("focus_space", args: [.string("mail")]).isSuccess)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        // A filing here would undo a #1010 re-home across screens.
        expectEqual(core.jump.take(arrived: away)?.relocates, false)
    }

    @Test("a hidden Desktop owes no raise")
    func hiddenOwesNoRaise() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("focus_space", args: [.string("mail")]).isSuccess)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(2), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.jump.take(arrived: away) == nil)
    }

    @Test("a filing elsewhere owes no raise")
    func otherSpaceOwesNoRaise() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("focus_space", args: [.string("mail")]).isSuccess)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("other"), id]
            ).isSuccess
        )
        #expect(core.jump.take(arrived: away) == nil)
    }

    @Test("an arrival beside a focus owes nothing")
    func occupiedOwesNothing() {
        let core = makeCore()
        defer { teardown() }
        let active = core.state.workspaces.activeSpace!
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string(active.raw), id]
            ).isSuccess
        )
        #expect(core.jump.take(arrived: away) == nil)
    }
}
