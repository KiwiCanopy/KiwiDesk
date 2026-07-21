import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Behavioral tests for the native-tab in-place re-key (#308):
/// `Space.rekey`, `WindowManager.rekey` / `ManagedWindow.withID`,
/// and the `StateCoordinator.apply(.windowRekeyed)` fold. The
/// exhaustiveness of the id-keyed map list is guarded separately by
/// `WindowRekeyParityTests`.
@Suite("Window re-key (#308)")
struct WindowRekeyTests {
    private let old = WindowID(9001)
    private let new = WindowID(9002)

    @Test("Space.rekey keeps the slot, focus, and every marker")
    func spaceRekeyPreservesSlot() {
        var space = Space(
            id: SpaceID(1),
            windows: [WindowID(1), old, WindowID(3)],
            focused: old,
            stackWeights: [old: 2.0],
            trackBreaks: [old],
            trackWeights: [old: 1.5]
        )
        space.rekey(old, to: new)
        #expect(space.windows == [WindowID(1), new, WindowID(3)])
        #expect(space.focused == new)
        #expect(space.stackWeights[new] == 2.0)
        #expect(space.stackWeights[old] == nil)
        #expect(space.trackBreaks.contains(new))
        #expect(!space.trackBreaks.contains(old))
        #expect(space.trackWeights[new] == 1.5)
        #expect(space.trackWeights[old] == nil)
    }

    @Test("Space.rekey is a no-op when old is absent")
    func spaceRekeyNoOp() {
        var space = Space(id: SpaceID(1), windows: [WindowID(1)])
        space.rekey(old, to: new)
        #expect(space.windows == [WindowID(1)])
        #expect(!space.windows.contains(new))
    }

    @Test("Space.rekey leaves focus alone when old was not focused")
    func spaceRekeyUnfocused() {
        var space = Space(
            id: SpaceID(1),
            windows: [WindowID(1), old],
            focused: WindowID(1)
        )
        space.rekey(old, to: new)
        #expect(space.focused == WindowID(1))
    }

    @Test("withID preserves every field but the id")
    func withIDPreservesFields() {
        let base = ManagedWindow(id: WindowID(0), pid: 0, appName: "")
        let window = ManagedWindow(
            id: old,
            pid: 7,
            appName: "App",
            appBundleID: "com.app",
            title: "Title",
            frame: CGRect(x: 1, y: 2, width: 3, height: 4),
            isFloating: true,
            isSticky: true,
            isTransientOverlay: true
        )
        // The fixture must touch every field, so a new field added
        // to ManagedWindow that withID forgets shows up as an extra
        // changed field below (silent-data-loss guard, AGENTS.md §5).
        expectAllChanged(window, from: base)
        let renamed = window.withID(new)
        #expect(changedFields(renamed, from: window) == ["id"])
    }

    @Test("WindowManager.rekey moves the entry under the new id")
    func windowManagerRekey() {
        var manager = WindowManager()
        manager.upsert(
            ManagedWindow(id: old, pid: 7, appName: "App")
        )
        manager.rekey(old, to: new)
        #expect(manager[old] == nil)
        #expect(manager[new]?.pid == 7)
        #expect(manager.count == 1)
    }

    @Test("apply(.windowRekeyed) swaps the id end to end")
    func applyRekey() {
        var state = StateCoordinator(defaultSpace: SpaceID(1))
        state.apply(
            .windowCreated(
                ManagedWindow(id: WindowID(1), pid: 7, appName: "App")
            )
        )
        state.apply(
            .windowCreated(
                ManagedWindow(id: old, pid: 7, appName: "App")
            )
        )
        state.apply(.windowRekeyed(old, new))
        #expect(state.windows[old] == nil)
        #expect(state.windows[new]?.pid == 7)
        let space = state.workspaces[SpaceID(1)]
        #expect(space?.windows == [WindowID(1), new])
        #expect(space?.focused == new)
    }
}
