import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The window-explicit `moveWindow` core behind the Space Bar
/// drag-drop (#372): a fast drop relocates an explicit (not
/// necessarily focused) window, and a drop after a spring files
/// the window into what is now the active space.
@Suite("Space bar drop moves", .serialized)
@MainActor
struct SpaceBarDropMoveTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-drop-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: "App"
                )
            )
        )
    }

    @Test("Fast drop relocates an explicit, non-focused window")
    func relocatesExplicitWindow() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        // Window 2 is the active-space focus; drag window 1.
        #expect(core.activeSpace?.focused == WindowID(2))

        core.moveWindow(WindowID(1), to: SpaceID("2"), follow: false)

        // Stay on space 1; window 1 relocated; focus untouched.
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        #expect(
            core.state.workspaces[SpaceID(2)]?.windows
                == [WindowID(1)]
        )
        #expect(core.activeSpace?.focused == WindowID(2))
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(2)]
        )
    }

    @Test("cancelDrag tears down drop state, scoped to the window")
    func cancelDragTearsDown() {
        let core = makeCore()
        addWindow(core, 1)
        core.tiler.dragExemptWindow = WindowID(1)
        core.spaceBarDrop.moved(WindowID(1), cursor: .zero)
        #expect(core.spaceBarDrop.draggingWindow == WindowID(1))
        // A cancel for a different window leaves the gesture alone.
        core.cancelDrag(WindowID(2))
        #expect(core.tiler.dragExemptWindow == WindowID(1))
        #expect(core.spaceBarDrop.draggingWindow == WindowID(1))
        // A cancel for the dragged window clears both — no leaked
        // exemption, no stale spring target for the next drag.
        core.cancelDrag(WindowID(1))
        #expect(core.tiler.dragExemptWindow == nil)
        #expect(core.spaceBarDrop.draggingWindow == nil)
    }

    @Test("A dragged window is exempt from retile frame apply")
    func dragExemptWindowNotReframed() {
        // Slot geometry needs a real screen (headless CI skips).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.tiler.animation.isEnabled = false
        var applied: Set<WindowID> = []
        core.tiler.animation.apply = { id, _, _ in
            applied.insert(id)
        }
        // With window 1 pinned as the in-flight drag, a forced
        // retile must place the others but never reframe it — the
        // pointer owns its frame (#372). Reframing it here is what
        // yanked it to a slot mid-drag and tripped the echo guard.
        core.tiler.dragExemptWindow = WindowID(1)
        applied = []
        core.retile(force: true)
        #expect(!applied.contains(WindowID(1)))
        #expect(applied.contains(WindowID(2)))
    }

    @Test("Spring eager-moves the dragged window into the target")
    func springEagerMovesWindow() {
        let core = makeCore()
        addWindow(core, 1)
        #expect(core.state.workspaces.activeSpace == SpaceID(1))

        // Fire the spring the dwell would trigger (the coordinator
        // calls this closure). Eager membership: the window moves
        // into the target NOW, so the live drag can preview and the
        // drop places it precisely.
        core.spaceBarDrop.spring(SpaceID("2"), WindowID(1))

        #expect(core.state.workspaces.activeSpace == SpaceID("2"))
        #expect(
            core.state.workspaces[SpaceID("2")]?.windows
                == [WindowID(1)]
        )
        #expect(core.activeSpace?.focused == WindowID(1))
        // Pinned against stashInactive for the rest of the drag.
        #expect(core.tiler.dragExemptWindow == WindowID(1))
    }
}
