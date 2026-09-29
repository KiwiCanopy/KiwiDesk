import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// The move and float verbs take an optional trailing `window`
/// (#1518, the owner's 2026-09-29 ruling): a named window is acted
/// on instead of the focused one, an unknown id is refused, and a
/// named call skips the #292 foreground preflight because its
/// target is named rather than implied.
@Suite("Window-explicit move and float verbs (#1518)", .serialized)
@MainActor
struct WindowExplicitCommandTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-explicit-\(UUID().uuidString)"
                )
        )
    }

    /// Two windows on Space 1; window 2, the later, holds focus.
    private func makeTwo() -> KiwiCore {
        let core = makeCore()
        for raw in [UInt32(1), 2] {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(raw),
                        pid: 1,
                        appName: "App\(raw)"
                    )
                )
            )
        }
        #expect(core.focusedWindowID == WindowID(2))
        return core
    }

    private func floats(_ core: KiwiCore, _ raw: UInt32) -> Bool? {
        core.state.windows[WindowID(raw)]?.isFloating
    }

    @Test("every verb that names a window finds it at its record")
    func recordStatesTheArgument() {
        let verbs = [
            "move_to_space", "move_to_space_and_follow",
            "make_floating", "make_tiled", "toggle_floating",
        ]
        for verb in verbs {
            let index = APIReference.windowArgumentIndex(verb)
            #expect(index != nil, "\(verb)")
            let arguments =
                APIReference.entry(named: verb)?.record.arguments ?? []
            #expect(index == arguments.count - 1, "\(verb)")
            #expect(arguments.last?.isOptional == true, "\(verb)")
        }
    }

    @Test("make_floating and make_tiled act on the named window")
    func floatNamed() {
        let core = makeTwo()
        #expect(core.execute("make_floating", args: [.number(1)]).isSuccess)
        #expect(floats(core, 1) == true)
        #expect(floats(core, 2) == false)
        #expect(core.execute("make_tiled", args: [.number(1)]).isSuccess)
        #expect(floats(core, 1) == false)
    }

    @Test("toggle_floating flips the named window, not the focus")
    func toggleNamed() {
        let core = makeTwo()
        #expect(
            core.execute("toggle_floating", args: [.string("1")])
                .isSuccess
        )
        #expect(floats(core, 1) == true)
        #expect(floats(core, 2) == false)
    }

    @Test("move_to_space moves the named window, not the focus")
    func moveNamed() {
        let core = makeTwo()
        let response = core.execute(
            "move_to_space",
            args: [.string("2"), .number(1)]
        )
        #expect(response.isSuccess)
        #expect(
            core.state.workspaces[SpaceID(2)]?.windows == [WindowID(1)]
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows == [WindowID(2)]
        )
    }

    @Test("an id no tracked window carries is refused")
    func unknownRefused() {
        let core = makeTwo()
        let float = core.execute("make_floating", args: [.number(99)])
        #expect(float.error == "unknown window: 99")
        #expect(floats(core, 2) == false)
        let move = core.execute(
            "move_to_space",
            args: [.string("2"), .string("nope")]
        )
        #expect(move.error == "unknown window: nope")
        #expect(core.state.workspaces[SpaceID(2)]?.windows ?? [] == [])
    }

    @Test("a fractional id or a non-scalar value is refused")
    func malformedRefused() {
        let core = makeTwo()
        let fractional = core.execute(
            "make_floating",
            args: [.number(1.5)]
        )
        #expect(fractional.error == "unknown window: 1.5")
        let table = core.execute("make_floating", args: [.bool(true)])
        #expect(table.error == "expected window id")
        #expect(floats(core, 1) == false)
        #expect(floats(core, 2) == false)
    }

    /// A move from a Space nobody shows, of a window that held no
    /// focus, leaves the active Space's focus alone: the warp
    /// that refocus would make is held, so it is observable.
    @Test("a named move from elsewhere does not refocus the active Space")
    func namedMoveKeepsFocus() {
        let core = makeTwo()
        core.execute("move_to_space", args: [.string("2"), .number(1)])
        core.tiler.settings.mouse.followsFocus = true
        core.zOrderRestoresInFlight = 1
        defer { core.zOrderRestoresInFlight = 0 }
        core.pendingMouseWarp = nil
        #expect(
            core.execute(
                "move_to_space",
                args: [.string("3"), .number(1)]
            ).isSuccess
        )
        #expect(
            core.state.workspaces[SpaceID(3)]?.windows == [WindowID(1)]
        )
        #expect(core.pendingMouseWarp == nil)
        // KiwiDesk still believes the focus is where macOS keeps it.
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        #expect(
            core.state.workspaces[SpaceID(3)]?.focused == WindowID(1)
        )
    }

    /// "Move to Current Space" (#1518): the moved window is not
    /// only recorded as the active Space's focus, it is FOCUSED —
    /// raised and warped to, the warp held so it is observable.
    @Test("a named move into the active Space focuses the window")
    func namedMoveIntoActiveFocuses() {
        let core = makeTwo()
        core.execute("move_to_space", args: [.string("2"), .number(1)])
        #expect(core.state.workspaces.lastFocused == WindowID(2))
        core.tiler.settings.mouse.followsFocus = true
        core.zOrderRestoresInFlight = 1
        defer { core.zOrderRestoresInFlight = 0 }
        core.pendingMouseWarp = nil
        #expect(
            core.execute(
                "move_to_space",
                args: [.string("1"), .number(1)]
            ).isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
        #expect(core.state.workspaces.lastFocused == WindowID(1))
        #expect(core.pendingMouseWarp == WindowID(1))
    }

    @Test("without the argument the focused window is still the one")
    func focusedFallback() {
        let core = makeTwo()
        #expect(core.execute("make_floating").isSuccess)
        #expect(floats(core, 2) == true)
        #expect(floats(core, 1) == false)
    }

    @Test("a named window skips the foreground preflight")
    func preflightSkipped() {
        let core = makeTwo()
        // Another app is frontmost: a focused call is denied ...
        core.frontmostPIDProvider = { 999 }
        #expect(!core.execute("make_floating").isSuccess)
        #expect(floats(core, 2) == false)
        // ... and a call naming its window is not.
        #expect(core.execute("make_floating", args: [.number(1)]).isSuccess)
        #expect(floats(core, 1) == true)
    }
}
