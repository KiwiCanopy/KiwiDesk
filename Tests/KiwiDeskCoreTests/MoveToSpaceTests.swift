import AppKit
import CoreGraphics
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

    /// Polls `condition` up to a deadline so a settle that fires
    /// a little late under load does not flake the test.
    private func pollUntil(
        deadlineMS: Int,
        _ condition: () -> Bool
    ) async {
        var waited = 0
        while !condition(), waited < deadlineMS {
            try? await Task.sleep(for: .milliseconds(20))
            waited += 20
        }
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

    @Test("A space switch re-asserts the layout after settling")
    func spaceSwitchReassertsLayout() async throws {
        // Slot geometry needs a real screen (headless CI skips).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        // Drive the observable animated apply path and let the
        // settle re-run use it too.
        core.tiler.animateSpaceSwitch = true
        core.tiler.animation.isEnabled = false
        var applies: [WindowID: Int] = [:]
        core.tiler.animation.apply = { id, _, _ in
            applies[id, default: 0] += 1
        }
        addWindow(core, 1)
        core.execute(
            "move_to_virtual_space",
            args: [.string("2")]
        )
        // Count only what the focus + settle apply.
        applies = [:]
        core.execute(
            "focus_virtual_space",
            args: [.string("2")]
        )
        let onFocus = applies[WindowID(1)] ?? 0
        #expect(onFocus >= 1)
        // The settle (~300ms later) re-issues the whole layout, so
        // the apply count grows past the on-focus count without a
        // manual second focus — how a dropped frame is recovered.
        await pollUntil(deadlineMS: 2000) {
            (applies[WindowID(1)] ?? 0) > onFocus
        }
        #expect((applies[WindowID(1)] ?? 0) > onFocus)
    }

    @Test("Switching away cancels and replaces the settle")
    func settleCancelsOnReswitch() {
        let core = makeCore()
        addWindow(core, 1)
        core.execute(
            "focus_virtual_space",
            args: [.string("2")]
        )
        let first = core.pendingSpaceSettle
        #expect(first != nil)
        core.execute(
            "focus_virtual_space",
            args: [.string("1")]
        )
        // The prior settle is cancelled AND a fresh one scheduled
        // for the new target — not merely cancelled.
        #expect(first?.isCancelled == true)
        #expect(core.pendingSpaceSettle != nil)
        #expect(core.pendingSpaceSettle != first)
    }

    @Test("Moving to the current space re-stamps focus safely")
    func moveToSameSpaceIsSafe() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        // Window 2 is space 1's focus; move it into space 1 again.
        #expect(core.activeSpace?.focused == WindowID(2))
        let response = core.execute(
            "move_to_virtual_space",
            args: [.string("1")]
        )
        #expect(response.isSuccess)
        // Both windows survive (nothing dropped) and 2 stays focus.
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1), WindowID(2)]
        )
        #expect(core.activeSpace?.focused == WindowID(2))
    }
}
