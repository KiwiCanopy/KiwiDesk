import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Generous hang-guard for waits on the settle Task's `onDragEnd`
/// (#344). The drag settle fires from an unstructured `Task` on the
/// main actor; because swift-testing runs suites concurrently, that
/// actor can be starved for seconds under full-suite load, so the old
/// 5s deadline tripped spuriously (the `ended` still empty flake).
/// The loops exit the instant `ended` fills, so a large value never
/// slows a passing run — it only bounds a genuine hang.
private let dragSettleHangGuard: Duration = .seconds(30)

@Suite("DragCoordinator", .serialized)
@MainActor
struct DragCoordinatorTests {
    @Test("Rapid moves settle into exactly one drag end")
    func debounce() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var pressed = true
        drag.isMousePressed = { pressed }
        var ended: [(WindowID, CGRect, CGRect)] = []
        drag.onDragEnd = { id, start, frame in
            ended.append((id, start, frame))
        }
        let id = WindowID(1)
        for x in 1...3 {
            drag.windowMoved(
                id,
                frame: CGRect(
                    x: CGFloat(x * 100),
                    y: 0,
                    width: 10,
                    height: 10
                )
            )
        }
        pressed = false
        // Poll instead of a fixed sleep: under full-suite
        // load the settle task can get main-actor time late.
        let deadline = ContinuousClock.now + dragSettleHangGuard
        while ended.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // Grace window so a wrong second fire would show up.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(ended.count == 1)
        // The end frame is the last move, the start frame the
        // first one of the gesture.
        #expect(ended.first?.2.minX == 300)
        #expect(ended.first?.1.minX == 100)
    }

    @Test("Mouse-up moves never start a gesture")
    func programmaticMovesIgnored() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var ended = 0
        drag.onDragEnd = { _, _, _ in ended += 1 }
        // An app repositioning its own window: the mouse
        // button is up (isMousePressed defaults to false)
        // and no gesture is in flight — not a drag.
        drag.windowMoved(
            WindowID(1),
            frame: CGRect(x: 100, y: 0, width: 10, height: 10)
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended == 0)
    }

    @Test("A validated trail starts a gesture after release")
    func validatedTrailStartsGesture() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var ended: [CGRect] = []
        drag.onDragEnd = { _, _, frame in
            ended.append(frame)
        }
        // A fast mouse resize on a slow AX responder: every
        // event arrives after the release, pre-classified by
        // the caller (KiwiCore.isResizeGesture).
        let frame = CGRect(x: 0, y: 0, width: 500, height: 500)
        drag.windowMoved(
            WindowID(1),
            frame: frame,
            validated: true
        )
        let deadline = ContinuousClock.now + dragSettleHangGuard
        while ended.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // Grace window so a wrong second fire would show up.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(ended == [frame])
    }

    @Test("Trailing moves after release join the gesture")
    func trailingMovesJoinGesture() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var pressed = true
        drag.isMousePressed = { pressed }
        var ended: [(start: CGRect, end: CGRect)] = []
        drag.onDragEnd = { _, start, end in
            ended.append((start, end))
        }
        let first = CGRect(x: 100, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: first)
        // The last AX event of a fast drag lags the release;
        // it must still update the gesture's end frame.
        pressed = false
        let trailing = CGRect(x: 400, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: trailing)
        let deadline = ContinuousClock.now + dragSettleHangGuard
        while ended.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(ended.count == 1)
        #expect(ended.first?.start == first)
        #expect(ended.first?.end == trailing)
    }

    @Test("Animation-driven moves never count as drags")
    func animationFiltered() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        drag.isAnimating = { _ in true }
        var ended = 0
        drag.onDragEnd = { _, _, _ in ended += 1 }
        drag.windowMoved(WindowID(1), frame: .zero)
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended == 0)
    }

    @Test("Cancel drops a pending drag (window closed)")
    func cancelPending() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        var pressed = true
        drag.isMousePressed = { pressed }
        var ended = 0
        drag.onDragEnd = { _, _, _ in ended += 1 }
        drag.windowMoved(WindowID(1), frame: .zero)
        pressed = false
        drag.cancel(WindowID(1))
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended == 0)
    }

    @Test("Moves with the button down fire live drag moves")
    func liveMoves() throws {
        let drag = DragCoordinator()
        var pressed = true
        drag.isMousePressed = { pressed }
        var moves: [CGRect] = []
        drag.onDragMove = { _, _, frame in
            moves.append(frame)
        }
        let frame = CGRect(x: 50, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: frame)
        #expect(moves == [frame])
        // Trailing AX events after the release: no feedback.
        pressed = false
        drag.windowMoved(WindowID(1), frame: .zero)
        #expect(moves == [frame])
    }

    @Test("Animation-driven moves fire no live drag moves")
    func liveMovesFiltered() throws {
        let drag = DragCoordinator()
        drag.isAnimating = { _ in true }
        drag.isMousePressed = { true }
        var moves = 0
        drag.onDragMove = { _, _, _ in moves += 1 }
        drag.windowMoved(WindowID(1), frame: .zero)
        #expect(moves == 0)
    }

    @Test("No settle while the mouse button is held")
    func waitsForRelease() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        drag.releasePollDelay = 0.02
        var pressed = true
        drag.isMousePressed = { pressed }
        var ended: [CGRect] = []
        drag.onDragEnd = { _, _, frame in
            ended.append(frame)
        }
        let frame = CGRect(x: 500, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: frame)
        // Standing still with the button down is not a drop.
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended.isEmpty)
        pressed = false
        let deadline = ContinuousClock.now + dragSettleHangGuard
        while ended.isEmpty, ContinuousClock.now < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        #expect(ended == [frame])
    }
}

@Suite("Drag drop resolution", .serialized)
@MainActor
struct DragDropTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
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
        core.handleDragMove(
            WindowID(1),
            start: home,
            frame: frame
        )
        #expect(core.dragOverlay.isGhostVisible)
        #expect(core.dragOverlay.isDropZoneVisible)

        // Over no slot: the drop zone goes away, the ghost
        // (home slot) stays.
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

@Suite("Drag visual configuration", .serialized)
@MainActor
struct DragVisualCommandTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-dragviz-\(UUID().uuidString)"
                )
        )
    }

    @Test("drag.* commands update every visual setting")
    func commands() {
        let core = makeCore()
        core.execute(
            "drag.set_ghost_enabled",
            args: [.bool(false)]
        )
        core.execute(
            "drag.set_ghost_fill_color",
            args: [.string("#112233")]
        )
        core.execute(
            "drag.set_ghost_border_thickness",
            args: [.number(4)]
        )
        core.execute(
            "drag.set_ghost_border_alignment",
            args: [.string("outside")]
        )
        core.execute(
            "drag.set_drop_zone_border_thickness",
            args: [.number(3)]
        )
        core.execute(
            "drag.set_drop_zone_border",
            args: [.bool(false)]
        )
        core.execute(
            "drag.set_corner_radius",
            args: [.number(26)]
        )
        let settings = core.tiler.settings
        #expect(!settings.dragGhost.enabled)
        #expect(settings.dragGhost.fillColor == "#112233")
        #expect(settings.dragGhost.borderThickness == 4)
        #expect(settings.dragGhost.borderAlignment == .outside)
        #expect(settings.dragDropZone.borderThickness == 3)
        #expect(settings.dragDropZone.borderAlignment == .inside)
        #expect(!settings.dragDropZone.border)
        #expect(settings.dragCornerRadius == 26)
    }

    @Test("Bad colors and unknown settings are rejected")
    func rejectsBadInput() {
        let core = makeCore()
        #expect(
            !core.execute(
                "drag.set_ghost_border_color",
                args: [.string("kiwi")]
            ).isSuccess
        )
        #expect(
            !core.execute(
                "drag.set_ghost_opacity",
                args: [.number(1)]
            ).isSuccess
        )
        #expect(
            core.tiler.settings.dragGhost
                == .ghostDefault
        )
    }
}

@Suite("Hex color parsing")
struct HexColorTests {
    @Test("6- and 8-digit hex parse, junk does not")
    func parse() throws {
        let rgb = try #require(
            DragVisual.parseHex("#4E9F3D")
        )
        #expect(rgb.alpha == 1)
        #expect(abs(rgb.green - 0x9F / 255.0) < 0.001)
        let rgba = try #require(
            DragVisual.parseHex("8B5E3C40")
        )
        #expect(abs(rgba.alpha - 0x40 / 255.0) < 0.001)
        #expect(DragVisual.parseHex("#12345") == nil)
        #expect(DragVisual.parseHex("kiwi") == nil)
        #expect(DragVisual.parseHex("#GG5E3C") == nil)
    }
}

@Suite("Drag target rule")
struct DragTargetTests {
    private let slots: [WindowID: CGRect] = [
        WindowID(1): CGRect(x: 0, y: 0, width: 100, height: 100),
        WindowID(2): CGRect(
            x: 100,
            y: 0,
            width: 100,
            height: 100
        ),
    ]

    @Test("The slot under the frame's center is the target")
    func centerRule() {
        let frame = CGRect(x: 90, y: 10, width: 80, height: 80)
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                frame: frame,
                slots: slots
            ) == WindowID(2)
        )
    }

    @Test("A window's own slot is never its target")
    func neverSelf() {
        let frame = CGRect(x: 10, y: 10, width: 50, height: 50)
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                frame: frame,
                slots: slots
            ) == nil
        )
    }

    @Test("A center over no slot yields no target")
    func nowhere() {
        let frame = CGRect(x: 500, y: 500, width: 50, height: 50)
        #expect(
            DragTarget.swapTarget(
                of: WindowID(1),
                frame: frame,
                slots: slots
            ) == nil
        )
    }

    @Test(
        """
        Overlapping cascade slots resolve to the visible \
        strip's owner, not dictionary order
        """
    )
    func cascadeOverlap() {
        // A stack overflow cascade: same column, each slot 40
        // lower than the previous, all 100 tall — so slot n's
        // visible part is the 40-point strip under its top.
        let cascade: [WindowID: CGRect] = [
            WindowID(2): CGRect(
                x: 0,
                y: 0,
                width: 100,
                height: 100
            ),
            WindowID(3): CGRect(
                x: 0,
                y: 40,
                width: 100,
                height: 100
            ),
            WindowID(4): CGRect(
                x: 0,
                y: 80,
                width: 100,
                height: 100
            ),
        ]
        func target(centerY: CGFloat) -> WindowID? {
            DragTarget.swapTarget(
                of: WindowID(1),
                frame: CGRect(
                    x: 30,
                    y: centerY - 20,
                    width: 40,
                    height: 40
                ),
                slots: cascade
            )
        }
        // Inside the top window's exposed strip.
        #expect(target(centerY: 20) == WindowID(2))
        // Two slots contain this point; the middle window's
        // strip is the visible one.
        #expect(target(centerY: 60) == WindowID(3))
        // All three contain this point; the last window is
        // raised on top of the whole cascade.
        #expect(target(centerY: 90) == WindowID(4))
    }

    @Test("Identical slots pick a deterministic target")
    func identicalSlots() {
        let rect = CGRect(x: 0, y: 0, width: 100, height: 100)
        let same: [WindowID: CGRect] = [
            WindowID(2): rect,
            WindowID(3): rect,
        ]
        let frame = CGRect(x: 30, y: 30, width: 40, height: 40)
        for _ in 0..<10 {
            #expect(
                DragTarget.swapTarget(
                    of: WindowID(1),
                    frame: frame,
                    slots: same
                ) == WindowID(3)
            )
        }
    }
}
