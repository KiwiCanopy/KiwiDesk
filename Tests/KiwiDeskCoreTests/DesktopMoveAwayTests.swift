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

    /// A census read 400 ms after the move must not read a window
    /// mid-move as closed: that is the settle's and the task's prune.
    @Test("the reap prunes nothing")
    func reapKeepsAnAbsentEntry() async {
        let core = makeCore()
        defer { teardown() }
        core.desktopMemory.readCensus = { _ in
            DesktopCensus(hosts: [:], shown: [10, 20])
        }
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(4), .null, id]
            ).isSuccess
        )
        await core.deferred.task(for: .desktopMoveReap)?.value
        #expect(core.state.awayWindows[away] != nil)
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

    /// A vanish keeps the slot: only a close or a minimize empties it.
    private func vanish(_ core: KiwiCore, _ window: WindowID) {
        core.state.apply(.windowDestroyed(window, wasMinimized: false))
        core.state.awayWindows[window] = AwayWindow(
            id: window,
            pid: 900_002,
            appName: "Here",
            appBundleID: nil,
            title: "",
            nativeSpace: 11
        )
    }

    @Test("an out pocket window refuses")
    func outPocketRefuses() {
        let core = makeCore()
        defer { teardown() }
        core.execute("toggle_pocket_window")
        #expect(core.state.pocketPhase(of: focused) == .out)
        vanish(core, focused)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, .number(Double(focused.raw))]
            ).error == "a pocket window cannot change Desktop"
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("a pocketed window refuses")
    func pocketedRefuses() {
        let core = makeCore()
        defer { teardown() }
        core.execute("pocket")
        #expect(core.state.pocketPhase(of: focused) == .pocketed)
        vanish(core, focused)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, .number(Double(focused.raw))]
            ).error == "a pocketed window cannot change Desktop"
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
    }

    @Test("a window that left sticky refuses a named Space")
    func stickyRefusesTheName() {
        let core = makeCore()
        defer { teardown() }
        var window = ManagedWindow(
            id: away,
            pid: pid,
            appName: "Away",
            title: "Elsewhere"
        )
        window.stickyScope = .global
        core.state.rememberStickyIntent(of: window)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .string("mail"), id]
            ).error == "a sticky window keeps its Space"
        )
        #expect(DesktopVerbBridge.moves.isEmpty)
        #expect(
            core.execute(
                "move_to_desktop",
                args: [.number(1), .null, id]
            ).isSuccess
        )
    }

    /// A tracked id takes the tracked route even if the ledger names
    /// it too: that route files a shown Desktop's Space at once.
    @Test("a tracked id takes the tracked route")
    func trackedOutranksTheLedger() {
        let core = makeCore()
        defer { teardown() }
        core.state.awayWindows[focused] = core.state.awayWindows[away]
        #expect(
            core.execute(
                "move_to_desktop",
                args: [
                    .number(1), .string("mail"),
                    .number(Double(focused.raw)),
                ]
            ).isSuccess
        )
        #expect(core.state.workspaces.space(of: focused) == mail)
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
}
