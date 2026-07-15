import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-monocle-nav-\(UUID().uuidString)"
        )
    return KiwiCore(configDirectory: directory)
}

/// Boots `count` windows into the active space, switches it to
/// monocle (horizontal orientation → left/right cycles), and
/// focuses `focus`. Returns the space id.
@MainActor
private func makeMonocleSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: WindowID
) -> SpaceID {
    for id in 1...count {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)"
                )
            )
        )
    }
    let space = core.state.workspaces.space(of: WindowID(1))!
    core.execute(
        "set_mode",
        args: [.string(space.raw), .string("monocle")]
    )
    core.state.workspaces.focus(focus, in: space)
    return space
}

/// Monocle focus cycle & the opt-in wrap toggle (#168): wrap
/// defaults off, matching the other array-order layouts (#257);
/// turn it on and focus wraps past the ends. `swap` never wraps.
@Suite("Monocle navigation (#168)", .serialized)
@MainActor
struct MonocleNavigationTests {
    @Test("Focus wraps past the ends when wrap_focus is on")
    func focusWrapsWhenOn() {
        let core = makeCore()
        let space = makeMonocleSpace(
            core,
            windows: 3,
            focus: WindowID(1)
        )
        core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(true)]
        )
        // Left from the first wraps to the last.
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
        // Right from the last wraps to the first.
        core.state.workspaces.focus(WindowID(3), in: space)
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("wrap_focus off makes focus stop at the ends")
    func wrapOffStopsAtEnds() {
        let core = makeCore()
        _ = makeMonocleSpace(core, windows: 3, focus: WindowID(1))
        core.execute(
            "monocle.set_wrap_focus",
            args: [.bool(false)]
        )
        // At the first window, left no longer wraps.
        #expect(
            !core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
        // Mid-array stepping is unaffected.
        core.state.workspaces.focus(WindowID(2), in: core.activeSpace!.id)
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("Swap never wraps, even with wrap on")
    func swapNeverWraps() {
        let core = makeCore()
        _ = makeMonocleSpace(core, windows: 3, focus: WindowID(1))
        // Default wrap is on, but a swap off the first end is a
        // no-op (a wrapping swap would teleport the window).
        #expect(
            !core.execute("swap", args: [.string("left")])
                .isSuccess
        )
    }

    @Test("Swap trades adjacent windows within range")
    func swapWithinRange() {
        let core = makeCore()
        let space = makeMonocleSpace(
            core,
            windows: 3,
            focus: WindowID(1)
        )
        #expect(
            core.execute("swap", args: [.string("right")])
                .isSuccess
        )
        #expect(
            core.state.workspaces[space]?.windows.prefix(2)
                == [WindowID(2), WindowID(1)]
        )
    }
}
