import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Generous hang-guard for waits on the dwell Task's `onCross`
/// (#344): swift-testing runs suites concurrently, so the main
/// actor can be starved for seconds under full-suite load. The
/// polls exit the instant the condition holds, so a passing run
/// never slows — the deadline only bounds a genuine hang.
private let crossingHangGuard: Duration = .seconds(30)

@Suite("DragCrossingCoordinator", .serialized)
@MainActor
struct DragCrossingCoordinatorTests {
    /// Left half of the plane is display 1, right half display 2.
    private func makeCoordinator() -> DragCrossingCoordinator {
        let crossing = DragCrossingCoordinator()
        crossing.dwell = 0.05
        crossing.displayAt = { point in
            point.x < 1000 ? DisplayID(1) : DisplayID(2)
        }
        return crossing
    }

    @Test("A dwell on a foreign display fires one crossing")
    func dwellFires() async throws {
        let crossing = makeCoordinator()
        var fired: [DisplayID] = []
        crossing.onCross = { _, display in
            fired.append(display)
        }
        let id = WindowID(1)
        let onForeign = CGPoint(x: 1500, y: 100)
        crossing.moved(
            id,
            cursor: onForeign,
            homeDisplay: DisplayID(1)
        )
        let deadline = ContinuousClock.now + crossingHangGuard
        while fired.isEmpty, ContinuousClock.now < deadline {
            // Same-display moves must keep the armed dwell
            // running, not restart it.
            crossing.moved(
                id,
                cursor: onForeign,
                homeDisplay: DisplayID(1)
            )
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        // Grace window so a wrong second fire would show up.
        try await Task.sleep(nanoseconds: 100_000_000)
        #expect(fired == [DisplayID(2)])
    }

    @Test("Returning home before the dwell disarms it")
    func returnHomeDisarms() async throws {
        let crossing = makeCoordinator()
        var fired = 0
        crossing.onCross = { _, _ in fired += 1 }
        let id = WindowID(1)
        crossing.moved(
            id,
            cursor: CGPoint(x: 1500, y: 100),
            homeDisplay: DisplayID(1)
        )
        // Back on the home display before the dwell elapses:
        // the seam-skim case the debounce exists for.
        crossing.moved(
            id,
            cursor: CGPoint(x: 100, y: 100),
            homeDisplay: DisplayID(1)
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(fired == 0)
    }

    @Test("A cursor over no display disarms the dwell")
    func nowhereDisarms() async throws {
        let crossing = makeCoordinator()
        var fired = 0
        crossing.onCross = { _, _ in fired += 1 }
        let id = WindowID(1)
        // Arm toward a display that then stops resolving
        // (topology change mid-drag).
        crossing.displayAt = { _ in DisplayID(2) }
        crossing.moved(
            id,
            cursor: CGPoint(x: 1500, y: 100),
            homeDisplay: DisplayID(1)
        )
        crossing.displayAt = { _ in nil }
        crossing.moved(
            id,
            cursor: CGPoint(x: 1500, y: 100),
            homeDisplay: DisplayID(1)
        )
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(fired == 0)
    }

    @Test("endGesture disarms the pending dwell and reports")
    func endGestureDisarms() async throws {
        let crossing = makeCoordinator()
        var fired = 0
        crossing.onCross = { _, _ in fired += 1 }
        let id = WindowID(1)
        crossing.moved(
            id,
            cursor: CGPoint(x: 1500, y: 100),
            homeDisplay: DisplayID(1)
        )
        // Nothing crossed yet — the drop landed before the
        // dwell elapsed (the fast flick #492 still owns).
        #expect(crossing.endGesture(id) == false)
        try await Task.sleep(nanoseconds: 150_000_000)
        #expect(fired == 0)
    }

    @Test("Gesture bookkeeping: origin once, crossed, cleared")
    func gestureBookkeeping() {
        let crossing = makeCoordinator()
        let id = WindowID(1)
        crossing.recordOriginIfNeeded(id, space: "A", index: 2)
        // A second crossing keeps the FIRST home — that is the
        // abnormal-cancel restore point.
        crossing.recordOriginIfNeeded(id, space: "B", index: 0)
        #expect(crossing.origin(for: id)?.space == SpaceID("A"))
        #expect(crossing.origin(for: id)?.index == 2)
        #expect(crossing.hasCrossed(id) == false)
        crossing.markCrossed(id)
        #expect(crossing.hasCrossed(id))
        #expect(crossing.endGesture(id) == true)
        // Ended: a reused WindowID starts clean.
        #expect(crossing.origin(for: id) == nil)
        #expect(crossing.hasCrossed(id) == false)
    }

    @Test("A sticky refusal is remembered for the gesture")
    func stickyRefusalOnce() {
        let crossing = makeCoordinator()
        let id = WindowID(1)
        #expect(crossing.stickyRefused(id) == false)
        crossing.markStickyRefused(id)
        #expect(crossing.stickyRefused(id))
        crossing.endGesture(id)
        #expect(crossing.stickyRefused(id) == false)
    }
}
