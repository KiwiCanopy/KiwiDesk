import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("Drag drop resolution", .serialized)
@MainActor
struct DragDropTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-drag-\(UUID().uuidString)"
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

    @Test("Dropping onto another slot swaps the windows")
    func swapOnDrop() throws {
        // Needs a real screen for slot geometry.
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let home = try #require(slots[WindowID(1)])
        let targetSlot = try #require(slots[WindowID(2)])

        // Same size as at gesture start (a move), centered
        // over the other window's slot.
        var frame = home
        frame.origin = CGPoint(
            x: targetSlot.midX - home.width / 2,
            y: targetSlot.midY - home.height / 2
        )
        // The drop target follows the cursor, not the frame
        // center (#492): place the pointer over the target slot.
        // `cursorLocation` is Cocoa; the flip is its own inverse,
        // so `axPoint` of the AX center yields the Cocoa point
        // that flips back to it.
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(
                CGPoint(x: targetSlot.midX, y: targetSlot.midY)
            )
        }
        core.handleDragEnd(
            WindowID(1),
            start: home,
            frame: frame
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(2), WindowID(1)]
        )
        // The dropped window ends up focused.
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Dropping into nowhere keeps the order (snap back)")
    func snapBack() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)

        let nowhere = CGRect(
            x: -9000,
            y: -9000,
            width: 100,
            height: 100
        )
        // Cursor over no slot either — the drop target is keyed
        // on the pointer (#492), so pin it away from every slot.
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(CGPoint(x: -9000, y: -9000))
        }
        core.handleDragEnd(
            WindowID(1),
            start: nowhere.offsetBy(dx: 500, dy: 500),
            frame: nowhere
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1), WindowID(2)]
        )
    }

    @Test("Live preview shows ghost and drop zone over a slot")
    func livePreview() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let home = try #require(slots[WindowID(1)])
        let targetSlot = try #require(slots[WindowID(2)])

        // Same size (a move, not a resize), centered over the
        // other window's slot.
        var frame = home
        frame.origin = CGPoint(
            x: targetSlot.midX - home.width / 2,
            y: targetSlot.midY - home.height / 2
        )
        // Cursor over the target slot: the drop zone is keyed on
        // the pointer, not the frame center (#492).
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(
                CGPoint(x: targetSlot.midX, y: targetSlot.midY)
            )
        }
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: frame
        )
        #expect(core.dragOverlay.isGhostVisible)
        #expect(core.dragOverlay.isDropZoneVisible)

        // Cursor over no slot: the drop zone goes away, the ghost
        // (home slot) stays.
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(CGPoint(x: -9000, y: -9000))
        }
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: frame.offsetBy(dx: -9000, dy: -9000)
        )
        #expect(core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)

        // The drop hides everything.
        core.handleDragEnd(
            WindowID(1),
            start: home,
            frame: frame
        )
        #expect(!core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    @Test(
        """
        The gesture's first frame (no motion) shows no preview \
        so a resize can't flash the ghost (#237)
        """
    )
    func firstFrameShowsNoPreview() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let home = try #require(slots[WindowID(1)])
        // start == frame: nothing has translated or resized yet,
        // so the gesture reads as neither a move nor a resize.
        // A resize begins here — showing the ghost now would be
        // the one-frame flash.
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: home
        )
        #expect(!core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    @Test(
        """
        An edge-grabbed sub-threshold resize hides the ghost, \
        while the same drag grabbed in the body shows it (#237)
        """
    )
    func edgePressDiscriminatesSmallResize() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let home = try #require(slots[WindowID(1)])
        // A < 10 pt width growth, below the magnitude
        // threshold, with the origin nudged so movedOrigin is
        // true — this isolates the pressNearEdge && sizeChanged
        // path from the first-frame guard.
        var frame = home
        frame.size.width += 4
        frame.origin.x += 1

        // Press on the right edge — a resize grab: hidden.
        core.mouse.seedPress(
            at: CGPoint(x: home.maxX, y: home.midY)
        )
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: frame
        )
        #expect(!core.dragOverlay.isGhostVisible)

        // Same frames, but the press began in the body: the
        // sub-threshold size wobble reads as move noise, so the
        // ghost stays (the character-grid-move fallback).
        core.mouse.seedPress(
            at: CGPoint(x: home.midX, y: home.midY)
        )
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: frame
        )
        #expect(core.dragOverlay.isGhostVisible)
    }

    @Test("Disabled toggles suppress the drag visuals")
    func previewDisabled() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.dragGhost.enabled = false
        core.tiler.settings.dragDropZone.enabled = false
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let targetSlot = try #require(slots[WindowID(2)])

        core.handleDragMove(
            WindowID(1),
            start: targetSlot,
            frame: targetSlot
        )
        #expect(!core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    @Test("A resize-shaped drag shows no swap preview")
    func previewSkipsResize() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let start = try #require(slots[WindowID(1)])
        var frame = start
        frame.size.width += 120

        core.handleDragMove(
            WindowID(1),
            start: start,
            frame: frame
        )
        #expect(!core.dragOverlay.isGhostVisible)
        #expect(!core.dragOverlay.isDropZoneVisible)
    }

    @Test(
        """
        A moved window that never matched its slot's size \
        still swaps (no false resize)
        """
    )
    func constrainedWindowMoveIsNotAResize() throws {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        let slots = core.tiler.calculatedFrames(
            state: core.state
        )
        let home = try #require(slots[WindowID(1)])
        let targetSlot = try #require(slots[WindowID(2)])

        // The app refused the slot size (min size): the real
        // frame is bigger than the slot for the whole
        // gesture, but its size never CHANGES — a move.
        var start = home
        start.size.height += 80
        var frame = start
        frame.origin = CGPoint(
            x: targetSlot.midX - frame.width / 2,
            y: targetSlot.midY - frame.height / 2
        )
        // Pointer over the target slot: the swap is keyed on the
        // cursor, not the (constrained) frame's center (#492).
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(
                CGPoint(x: targetSlot.midX, y: targetSlot.midY)
            )
        }
        core.handleDragEnd(
            WindowID(1),
            start: start,
            frame: frame
        )
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(2), WindowID(1)]
        )
    }
}
