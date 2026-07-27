import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Floating windows never show drag visuals and never swap on
/// drop (#161): they have no tile slot to preview, so ghost
/// and snap zone stay hidden even in a tiled space. The
/// "visuals show for floating windows" reports came from #160
/// (float state silently reverting to tiled on reopen).
@Suite("Floating drag visuals", .serialized)
@MainActor
struct FloatingDragVisualTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-floatdrag-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32
    ) {
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

    @Test("A floating drag shows no ghost or snap zone")
    func floatingDragShowsNoVisuals() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        // The space itself stays tiled; only the window floats.
        core.state.setFloating(WindowID(1), true)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let targetSlot = try #require(slots[WindowID(2)])

        // A move-shaped drag centered over a tiled slot — the
        // strongest case for a visual leak.
        let frame = CGRect(
            x: targetSlot.midX - 200,
            y: targetSlot.midY - 100,
            width: 400,
            height: 200
        )
        core.handleDragMove(
            WindowID(1),
            start: frame.offsetBy(dx: 50, dy: 50),
            frame: frame
        )
        #expect(!core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    @Test("Dropping a floating window never swaps the order")
    func floatingDropIsInert() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        addWindow(core, 3)
        core.state.setFloating(WindowID(1), true)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let targetSlot = try #require(slots[WindowID(3)])

        let frame = CGRect(
            x: targetSlot.midX - 200,
            y: targetSlot.midY - 100,
            width: 400,
            height: 200
        )
        core.handleDragEnd(
            WindowID(1),
            start: frame.offsetBy(dx: 50, dy: 50),
            frame: frame
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1), WindowID(2), WindowID(3)]
        )
        #expect(
            core.state.windows[WindowID(1)]?.isFloating == true
        )
    }

    @Test("Floating windows never occupy a layout slot")
    func floatingWindowHasNoSlot() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        core.state.setFloating(WindowID(1), true)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        #expect(slots[WindowID(1)] == nil)
        #expect(slots[WindowID(2)] != nil)
    }
}
