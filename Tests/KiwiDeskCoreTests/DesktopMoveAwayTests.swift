import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_to_desktop` naming a window on a hidden Desktop (#3034),
/// through the real dispatch. Over the #888 fixture (Desktops 1–2 on
/// `UUID-A`, ids 10/11; 3–4 on `UUID-B`, ids 20/21), Desktops 1 and 3
/// shown; the window sits on Desktop 2.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move naming an away window (#3034)", .serialized)
@MainActor
struct DesktopMoveAwayTests {
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

    // MARK: - The move

    @Test("an away window moves, and the focus stays")
    func moves() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .null, id]
        )
        #expect(response.isSuccess)
        #expect(
            DesktopVerbBridge.moves.map { $0.0 }
                == [[NSNumber(value: away.raw)]]
        )
        #expect(core.focusedWindowID == focused)
        #expect(core.state.windows[away] == nil)
        #expect(core.desktopMemory.moveReapPIDs == [pid])
        #expect(core.deferred.isScheduled(.desktopMoveReap))
    }

    @Test("the CLI's spelling reaches it")
    func cliSpelling() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop",
            args: [.string("1"), .string(""), .string("\(away.raw)")]
        )
        #expect(response.isSuccess)
        #expect(DesktopVerbBridge.moves.count == 1)
    }

    @Test("an id nobody knows stays unknown, and only this verb reaches")
    func reachIsThisVerbs() {
        let core = makeCore()
        defer { teardown() }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, .number(77)]
            ).error == "unknown window: 77"
        )
        #expect(
            core.execute("focus_window", args: [id]).error?
                .contains("cannot reach") == true
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    /// The reap re-reads the ledger, so a Jump after the move takes
    /// the Desktop the window moved to rather than waiting out the
    /// census backstop.
    @Test("the reap refreshes the ledger's Desktop")
    func reapFoldsTheCensus() async {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readCensus = { [away, pid] _ in
            DesktopCensus(
                hosts: [
                    away: DesktopCensus.Host(
                        space: 21,
                        pid: pid,
                        isUp: true
                    )
                ],
                shown: [10, 20]
            )
        }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(4), .null, id]
            ).isSuccess
        )
        #expect(core.state.awayWindows[away]?.nativeSpace == 11)
        await core.deferred.task(for: .desktopMoveReap)?.value
        #expect(core.state.awayWindows[away]?.nativeSpace == 21)
    }

    // MARK: - The refusals

    @Test("a window on a full-screen Space refuses")
    func fullScreenRefuses() {
        let core = makeCore(
            spaces: authorityTopology(mainCurrent: 10, secondaryCurrent: 20)
                + [
                    NativeSpace(
                        id: 999_999,
                        displayUUID: "UUID-A",
                        isCurrent: false,
                        isUser: false
                    )
                ]
        )
        defer { teardown() }
        core.state.awayWindows[away]?.nativeSpace = 999_999
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .null, id]
        )
        #expect(response.error == "a full-screen window cannot change Desktop")
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("a refused bridge files nothing")
    func bridgeRefusal() {
        let core = makeCore()
        defer { teardown() }
        WMBridge.classResolverOverride = {
            $0 == "MoveWindowsToManagedSpaceOperation"
                ? nil : desktopVerbBridgeClasses[$0]
        }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string("mail"), id]
        )
        #expect(response.error?.contains("bridge") == true)
        #expect(core.state.rememberedSpace(of: away) == nil)
        #expect(core.state.workspaces[mail] == nil)
    }

    // MARK: - A named Space

    @Test("a named Space is filed at once and paid at the arrival")
    func namedSpace() {
        let core = makeCore()
        defer { teardown() }
        core.state.rememberedSpaces[away] = .departed("1")
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == mail)
        #expect(core.pendingSpace.isEmpty)
        arrive(core)
        #expect(core.state.workspaces.space(of: away) == mail)
    }

    @Test("a window nothing has filed takes the name")
    func unfiledTakesTheName() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.state.rememberedSpace(of: away) == nil)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == mail)
    }

    /// Separate Spaces: the parse compares with the Desktop's screen,
    /// the same refusal a tracked window takes.
    @Test("a Space off the Desktop's screen refuses")
    func offTheDesktopsScreen() {
        let core = makeCore()
        defer { teardown() }
        addDisplays(core)
        core.state.workspaces.assign(mail, to: DisplayID(2))
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string("mail"), id]
        )
        #expect(response.error?.contains("another screen") == true)
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    // MARK: - Shared Desktops

    private func sharedCore() -> KiwiCore {
        let core = makeCore(spaces: [
            authoritySpace(10, display: "Main", current: true),
            authoritySpace(11, display: "Main"),
            authoritySpace(12, display: "Main"),
        ])
        addDisplays(core)
        core.state.workspaces.assign("1", to: DisplayID(1))
        core.state.rememberedSpaces[away] = .departed("1")
        core.state.workspaces.assign(mail, to: DisplayID(2))
        return core
    }

    /// Only an arrival files it, and an arrival stays on its screen,
    /// so a shown Desktop refuses here where a tracked window crosses.
    @Test("a Space off its screen refuses for a shown Desktop too")
    func sharedRefusesEitherTarget() {
        let core = sharedCore()
        defer { teardown() }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).error
                == "Can't move a window across screens from a hidden Desktop."
        )
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(3), .string("mail"), id]
            ).error
                == "Can't move a window across screens to a hidden Desktop."
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("a Space on its screen is taken")
    func sharedTakesItsScreen() {
        let core = sharedCore()
        defer { teardown() }
        core.state.workspaces.assign(mail, to: DisplayID(1))
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(3), .string("mail"), id]
            ).isSuccess
        )
        #expect(core.state.rememberedSpace(of: away) == mail)
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

    /// No switch happens, and the reap still brings an arrival, so
    /// the debt is paid there as a whole switch into its Space.
    @Test("a follow to a shown Desktop pays at the arrival")
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
        #expect(core.followFocus.owed() == away)
        arrive(core)
        #expect(core.followFocus.owed() == nil)
        #expect(core.state.workspaces.activeSpace == mail)
        #expect(core.focusedWindowID == away)
    }
}
