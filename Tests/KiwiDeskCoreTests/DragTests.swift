import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private final class MouseButtonState {
    var isPressed: Bool

    init(isPressed: Bool) {
        self.isPressed = isPressed
    }
}

@Suite("DragCoordinator", .serialized)
@MainActor
struct DragCoordinatorTests {
    @Test("Rapid moves settle into exactly one drag end")
    func debounce() async throws {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        let mouse = MouseButtonState(isPressed: true)
        drag.isMousePressed = { mouse.isPressed }
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
        mouse.isPressed = false
        // Await the settle's own timeline instead of polling a
        // clock for `ended` (#994; `tests.md` ▸ Async tests).
        // The settle fires from an unstructured `Task` on the
        // main actor, so a deadline here measured how long the
        // *other* suites held that actor — the `ended` still
        // empty flake — and never this coordinator. The handle
        // is the LAST move's: each move cancels its predecessor.
        let settle = drag.settleTask(for: id)
        #expect(settle != nil, "the move scheduled no settle")
        await settle?.value
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
        let settle = drag.settleTask(for: WindowID(1))
        #expect(settle != nil, "the move scheduled no settle")
        await settle?.value
        // Grace window so a wrong second fire would show up.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(ended == [frame])
    }

    @Test("A gesture's start comes from the pre-event frame")
    func startAnchorsOnPreEventFrame() async {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        let mouse = MouseButtonState(isPressed: true)
        drag.isMousePressed = { mouse.isPressed }
        var ended: [(CGRect, CGRect)] = []
        drag.onDragEnd = { _, start, frame in
            ended.append((start, frame))
        }
        // AX throttles notifications, so a fast gesture's FIRST
        // event already sits mid-flight — measuring from it
        // loses everything before it (#933: a fast border drag
        // resized only part of the way). The caller passes the
        // frame its state held BEFORE the event; the gesture
        // starts there.
        drag.windowMoved(
            WindowID(1),
            frame: CGRect(x: 0, y: 0, width: 700, height: 500),
            previous: CGRect(
                x: 0,
                y: 0,
                width: 400,
                height: 500
            )
        )
        mouse.isPressed = false
        let settle = drag.settleTask(for: WindowID(1))
        #expect(settle != nil, "the move scheduled no settle")
        await settle?.value
        #expect(ended.first?.0.width == 400)
        #expect(ended.first?.1.width == 700)
    }

    @Test("Trailing moves after release join the gesture")
    func trailingMovesJoinGesture() async {
        let drag = DragCoordinator()
        drag.settleDelay = 0.05
        let mouse = MouseButtonState(isPressed: true)
        drag.isMousePressed = { mouse.isPressed }
        var ended: [(start: CGRect, end: CGRect)] = []
        drag.onDragEnd = { _, start, end in
            ended.append((start, end))
        }
        let first = CGRect(x: 100, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: first)
        // The last AX event of a fast drag lags the release;
        // it must still update the gesture's end frame.
        mouse.isPressed = false
        let trailing = CGRect(x: 400, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: trailing)
        // The trailing move rescheduled the settle, so this is
        // its handle rather than the released gesture's first.
        let settle = drag.settleTask(for: WindowID(1))
        #expect(settle != nil, "the move scheduled no settle")
        await settle?.value
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
        let mouse = MouseButtonState(isPressed: true)
        drag.isMousePressed = { mouse.isPressed }
        var ended = 0
        drag.onDragEnd = { _, _, _ in ended += 1 }
        drag.windowMoved(WindowID(1), frame: .zero)
        mouse.isPressed = false
        drag.cancel(WindowID(1))
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended == 0)
    }

    @Test("Moves with the button down fire live drag moves")
    func liveMoves() throws {
        let drag = DragCoordinator()
        let mouse = MouseButtonState(isPressed: true)
        drag.isMousePressed = { mouse.isPressed }
        var moves: [CGRect] = []
        drag.onDragMove = { _, _, frame in
            moves.append(frame)
        }
        let frame = CGRect(x: 50, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: frame)
        #expect(moves == [frame])
        // Trailing AX events after the release: no feedback.
        mouse.isPressed = false
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
        let mouse = MouseButtonState(isPressed: true)
        drag.isMousePressed = { mouse.isPressed }
        var ended: [CGRect] = []
        drag.onDragEnd = { _, _, frame in
            ended.append(frame)
        }
        let frame = CGRect(x: 500, y: 0, width: 10, height: 10)
        drag.windowMoved(WindowID(1), frame: frame)
        // Standing still with the button down is not a drop.
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(ended.isEmpty)
        mouse.isPressed = false
        // Read the handle AFTER the release, and only because
        // this test is `@MainActor` throughout: the release and
        // this read share one synchronous stretch, so the leg
        // read here cannot already have run its settle. Awaiting
        // a leg read while the button was still down would prove
        // nothing — that leg reschedules and fires no drop.
        let settle = drag.settleTask(for: WindowID(1))
        #expect(settle != nil, "the release poll stopped early")
        await settle?.value
        #expect(ended == [frame])
    }
}
