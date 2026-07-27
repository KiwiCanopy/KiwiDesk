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
