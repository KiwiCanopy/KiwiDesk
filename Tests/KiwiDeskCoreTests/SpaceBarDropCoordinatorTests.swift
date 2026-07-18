import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The Space Bar drag-drop state machine (#372): the two-speed
/// gesture (fast drop relocates, dwell springs then places),
/// hover arming, and cancellation. Injected closures keep the
/// coordinator AppKit-free, so this drives it directly.
@MainActor
@Suite("Space bar drop coordinator")
struct SpaceBarDropCoordinatorTests {
    /// Records the visual cues the coordinator emits.
    private final class Recorder {
        var hovered: [SpaceID?] = []
        var sweeps: [SpaceID] = []
        var clears = 0
        var sprang: [(SpaceID, WindowID)] = []
    }

    private let win = WindowID(1)
    /// Cursor over space "B"; the hit test below maps to it.
    private let cursor = CGPoint(x: 10, y: 10)

    private func make(
        current: SpaceID,
        hit: SpaceID?,
        dwell: TimeInterval = 30
    ) -> (SpaceBarDropCoordinator, Recorder) {
        let rec = Recorder()
        let coord = SpaceBarDropCoordinator()
        coord.dwellProvider = { dwell }
        coord.hitTest = { _ in hit }
        coord.currentSpace = { _ in current }
        coord.setHover = { rec.hovered.append($0) }
        coord.beginSweep = { space, _ in rec.sweeps.append(space) }
        coord.clearFeedback = { rec.clears += 1 }
        coord.spring = { rec.sprang.append(($0, $1)) }
        return (coord, rec)
    }

    @Test("Fast drop onto another space relocates it")
    func fastDropRelocates() {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B")
        )
        coord.moved(win, cursor: cursor)
        #expect(coord.isArmed)
        #expect(rec.hovered.last == SpaceID("B"))
        #expect(rec.sweeps == [SpaceID("B")])
        // Released before the (long) dwell → relocate, no spring.
        #expect(
            coord.ended(win, cursor: cursor)
                == .relocate(
                    SpaceID("B")
                )
        )
        #expect(rec.sprang.isEmpty)
    }

    @Test("Hovering the window's own space never arms")
    func ownSpaceInert() {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("A")
        )
        coord.moved(win, cursor: cursor)
        #expect(!coord.isArmed)
        #expect(rec.sweeps.isEmpty)
        #expect(coord.ended(win, cursor: cursor) == .none)
    }

    @Test("Dropping off any bar item falls through")
    func offBarFallsThrough() {
        let (coord, _) = make(current: SpaceID("A"), hit: nil)
        coord.moved(win, cursor: cursor)
        #expect(!coord.isArmed)
        #expect(coord.ended(win, cursor: cursor) == .none)
    }

    @Test("Leaving the item cancels the pending spring")
    func leaveCancels() {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B")
        )
        coord.moved(win, cursor: cursor)
        #expect(coord.isArmed)
        // Cursor leaves the strip: the next move hit-tests nil.
        coord.hitTest = { _ in nil }
        coord.moved(win, cursor: cursor)
        #expect(!coord.isArmed)
        #expect(rec.clears >= 1)
    }

    @Test(
        "Dwell springs the space, then the drop places in it"
    )
    func dwellSpringsThenPlaces() async throws {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B"),
            dwell: 0.05
        )
        coord.moved(win, cursor: cursor)
        // Generous hang-guard (AGENTS.md): the wait exits the
        // instant the spring fires; the deadline only bounds a
        // genuine hang under concurrent-suite load.
        try await untilTrue(timeout: 30) {
            !rec.sprang.isEmpty
        }
        #expect(rec.sprang.map(\.0) == [SpaceID("B")])
        #expect(rec.sprang.first?.1 == win)
        #expect(coord.sprungSpace == SpaceID("B"))
        // The window is now on the visible target: the drop places
        // it there rather than relocating.
        #expect(
            coord.ended(win, cursor: cursor)
                == .placeInSprung(
                    SpaceID("B")
                )
        )
        #expect(coord.sprungSpace == nil)
    }

    @Test("reset cancels a pending spring (abandoned drag)")
    func resetCancelsSpring() async throws {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B"),
            dwell: 0.05
        )
        coord.moved(win, cursor: cursor)
        #expect(coord.isArmed)
        #expect(coord.draggingWindow == win)
        coord.reset()
        #expect(!coord.isArmed)
        #expect(coord.draggingWindow == nil)
        // Wait well past the (tiny) dwell: the spring must never
        // fire — proven by the gap (200ms vs the 50ms dwell).
        try await Task.sleep(nanoseconds: 200_000_000)
        #expect(rec.sprang.isEmpty)
    }

    /// Polls `condition` until true or `timeout` seconds elapse,
    /// yielding between checks. Passing runs exit at once.
    private func untilTrue(
        timeout: TimeInterval,
        _ condition: @MainActor () -> Bool
    ) async throws {
        let start = Date()
        while !condition() {
            if Date().timeIntervalSince(start) > timeout {
                Issue.record("condition never became true")
                return
            }
            try await Task.sleep(nanoseconds: 5_000_000)
        }
    }
}
