import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #22: a window moved to another virtual space must
/// become that space's focused window at move time, so the
/// FIRST focus of the space raises (surfaces) it. Before the
/// fix the target space kept no focus, so `focus_virtual_space`
/// un-stashed the window frame-wise but never brought it
/// forward — the space rendered empty until a second focus.
@Suite("Move to virtual space (issue #22)", .serialized)
@MainActor
struct MoveToSpaceTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-move-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        app: String = "App"
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: app
                )
            )
        )
    }

    @Test("Moved window becomes the target space's focus")
    func movedWindowFocusesTarget() {
        let core = makeCore()
        addWindow(core, 1)
        // A freshly created window is its space's focus.
        #expect(core.activeSpace?.id == SpaceID(1))
        #expect(core.activeSpace?.focused == WindowID(1))

        let response = core.execute(
            "move_to_virtual_space",
            args: [.string("2")]
        )
        #expect(response.isSuccess)
        // No follow: we stay on space 1 ...
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        // ... but the window now lives in space 2, as its focus.
        #expect(
            core.state.workspaces[SpaceID(2)]?.windows
                == [WindowID(1)]
        )
        #expect(
            core.state.workspaces[SpaceID(2)]?.focused
                == WindowID(1)
        )
    }

    @Test("First focus of the target lands on the moved window")
    func firstFocusSurfacesMovedWindow() {
        let core = makeCore()
        addWindow(core, 1)
        core.execute(
            "move_to_virtual_space",
            args: [.string("2")]
        )
        // A single focus is enough — no second switch (#22).
        core.execute(
            "focus_virtual_space",
            args: [.string("2")]
        )
        #expect(core.state.workspaces.activeSpace == SpaceID(2))
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Follow keeps focus on the moved window")
    func followFocusesMovedWindow() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        // Window 2 is the active-space focus; move+follow it.
        #expect(core.activeSpace?.focused == WindowID(2))
        core.execute(
            "move_to_virtual_space_and_follow",
            args: [.string("3")]
        )
        #expect(core.state.workspaces.activeSpace == SpaceID(3))
        #expect(core.activeSpace?.focused == WindowID(2))
        // Space 1 retains its other window and re-picks a focus.
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1)]
        )
    }
}
