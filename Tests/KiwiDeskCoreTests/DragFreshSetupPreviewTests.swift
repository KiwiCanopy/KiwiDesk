import AppKit
import Testing

@testable import KiwiDeskCore

/// A fresh setup's drag draws the drop zone alone (#2797): the
/// ghost is off by default, since the emptied home slot already
/// shows where the displaced window goes.
@Suite("Drag preview on a fresh setup", .serialized)
@MainActor
struct DragFreshSetupPreviewTests {
    private func addWindow(_ core: KiwiCore, _ raw: UInt32) {
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

    @Test("A fresh setup's drag shows the drop zone and no ghost")
    func onlyTheDropZone() throws {
        guard NSScreen.main != nil else { return }
        let core = makeTestCore(
            configDirectory:
                testTemporaryDirectory
                .appendingPathComponent(
                    "kiwi-dragfresh-\(UUID().uuidString)"
                )
        )
        defer { core.dragOverlay.hideAll() }
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(state: core.state)
        let home = try #require(slots[WindowID(1)])
        let target = try #require(slots[WindowID(2)])
        var frame = home
        frame.origin = CGPoint(
            x: target.midX - home.width / 2,
            y: target.midY - home.height / 2
        )
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(CGPoint(x: target.midX, y: target.midY))
        }
        core.handleDragMove(WindowID(1), start: home, frame: frame)
        #expect(!core.dragOverlay.isGhostVisible)
        #expect(core.dragOverlay.isDropZoneVisible)
    }
}
