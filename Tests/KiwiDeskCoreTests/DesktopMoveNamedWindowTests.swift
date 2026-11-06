import Foundation
import Testing

@testable import KiwiDeskCore

/// `move_to_desktop(N, space, window)` and its follow (#2888),
/// through the real dispatch: the argument and its refusals. Over
/// the #888 fixture (Desktops 1–2 on `UUID-A`, ids 10/11; 3–4 on
/// `UUID-B`, ids 20/21), Desktops 1 and 3 shown: Desktop 2 is HIDDEN
/// on the main screen, Desktop 1 SHOWN.
///
/// `WMBridge.classResolverOverride` is process-global; the same
/// synchronous-body arrangement as `DesktopCommandTests` applies.
@Suite("Desktop move naming a window (#2888)", .serialized)
@MainActor
struct DesktopMoveNamedWindowTests {
    private let focused = WindowID(7)
    private let named = WindowID(8)
    private var id: JSONValue { .number(Double(named.raw)) }

    private func makeCore(bridge: Bool = true) -> KiwiCore {
        DesktopVerbBridge.reset()
        NativeSpaces.spacesOverride = authorityTopology(
            mainCurrent: 10,
            secondaryCurrent: 20
        )
        NativeSpaces.activeSpaceIDOverride = 10
        pinTwoDisplays()
        WMBridge.classResolverOverride = {
            bridge ? desktopVerbBridgeClasses[$0] : nil
        }
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

    private func movedWindows() -> [[NSNumber]] {
        DesktopVerbBridge.moves.map { $0.0 }
    }

    private func moved(_ window: WindowID) -> [[NSNumber]] {
        [[NSNumber(value: window.raw)]]
    }

    // MARK: - The argument

    @Test("a named window moves, and the focus stays")
    func namedMoves() {
        let core = makeCore()
        defer { teardown() }
        // Asked at the press: a starved run outlasts the latch.
        let now = Date()
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .null, id]
        )
        #expect(response.isSuccess)
        #expect(movedWindows() == moved(named))
        #expect(core.focusedWindowID == focused)
        #expect(core.moveLatch.isLatched(named, at: now))
        #expect(!core.moveLatch.isLatched(focused, at: now))
    }

    @Test("no window argument still moves the focus")
    func unnamedMovesTheFocus() {
        let core = makeCore()
        defer { teardown() }
        #expect(core.execute("move_to_desktop", args: [.number(2)]).isSuccess)
        #expect(movedWindows() == moved(focused))
    }

    @Test("the capability answers a named call first")
    func capabilityFirst() {
        let core = makeCore(bridge: false)
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .null, .number(99)]
        )
        #expect(
            response.error
                == "the Desktop bridge is unavailable on this macOS"
        )
    }

    @Test("a bad Desktop number answers ahead of an unknown window")
    func desktopParseFirst() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(9), .null, .number(99)]
        )
        #expect(response.error == "no Desktop 9")
    }

    @Test("an empty Space is skipped only ahead of a window")
    func cliSkipSpelling() {
        let core = makeCore()
        defer { teardown() }
        let response = core.execute(
            "move_to_desktop",
            args: [.string("2"), .string(""), .string("\(named.raw)")]
        )
        #expect(response.isSuccess)
        #expect(movedWindows() == moved(named))
        let bare = core.execute(
            "move_to_desktop",
            args: [.string("2"), .string("")]
        )
        #expect(bare.error == "expected space id")
    }

    @Test("Lua skips the Space with nil")
    func luaSkipsWithNil() {
        let core = makeCore()
        defer { teardown() }
        core.loadConfig()
        _ = core.lua?.run(
            "KiwiDesk.move_to_desktop(2, nil, \(named.raw))"
        )
        #expect(movedWindows() == moved(named))
    }

    @Test("a named Space is pending for the named window")
    func pendingSpaceTakesTheName() {
        let core = makeCore()
        defer { teardown() }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .string("mail"), id]
        )
        #expect(response.isSuccess)
        #expect(
            lines.contains {
                $0.contains("w\(named.raw) will join space mail")
            }
        )
    }

    // MARK: - The window's refusals

    @Test("a full-screen window refuses in both forms")
    func fullScreenRefuses() {
        let core = makeCore()
        defer { teardown() }
        var lines: [String] = []
        core.onLog = { lines.append($0) }
        core.state.apply(.windowFullscreenChanged(named, isFullscreen: true))
        let response = core.execute(
            "move_to_desktop",
            args: [.number(2), .null, id]
        )
        #expect(response.error == "a full-screen window cannot change Desktop")
        #expect(lines.contains { $0.contains("cannot change Desktop") })
        core.state.apply(.windowFullscreenChanged(focused, isFullscreen: true))
        let unnamed = core.execute("move_to_desktop", args: [.number(2)])
        #expect(unnamed.error == "a full-screen window cannot change Desktop")
        #expect(movedWindows().isEmpty)
    }

    @Test("a pocketed window refuses and is filed nowhere")
    func pocketedRefuses() {
        let core = makeCore()
        defer { teardown() }
        core.execute("pocket")
        let window = focused
        #expect(core.state.isPocketed(window))
        var spoken: [String] = []
        core.borders.announceRefusal = { spoken.append($0) }
        let response = core.execute(
            "move_to_desktop",
            args: [.number(1), .string("mail"), .number(Double(window.raw))]
        )
        #expect(response.error == "a pocketed window cannot change Desktop")
        #expect(core.state.workspaces.space(of: window) == nil)
        #expect(spoken.isEmpty)
        #expect(movedWindows().isEmpty)
    }

    @Test("an out pocket window refuses in both forms")
    func outPocketRefuses() {
        let core = makeCore()
        defer { teardown() }
        core.execute("toggle_pocket_window")
        #expect(core.state.pocketPhase(of: focused) == .out)
        var spoken: [String] = []
        core.borders.announceRefusal = { spoken.append($0) }
        let refusal = "a pocket window cannot change Desktop"
        let unnamed = core.execute("move_to_desktop", args: [.number(2)])
        #expect(unnamed.error == refusal)
        let named = core.execute(
            "move_to_desktop_and_follow",
            args: [.number(2), .null, .number(Double(focused.raw))]
        )
        #expect(named.error == refusal)
        #expect(spoken.count == 2)
        #expect(movedWindows().isEmpty)
    }

    // MARK: - The reap

    @Test("a burst of named moves reaps every app")
    func burstKeepsEveryPID() {
        let core = makeCore()
        defer { teardown() }
        core.execute("move_to_desktop", args: [.number(2), .null, id])
        core.execute("move_to_desktop", args: [.number(2)])
        #expect(core.desktopMemory.moveReapPIDs == [1, 2])
        #expect(core.deferred.isScheduled(.desktopMoveReap))
    }
}
