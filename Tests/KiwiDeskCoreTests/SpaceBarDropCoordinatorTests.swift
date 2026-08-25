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
        coord.beginSweep = { space, _, _ in
            rec.sweeps.append(space)
        }
        coord.clearFeedback = { rec.clears += 1 }
        coord.spring = {
            rec.sprang.append(($0, $1))
            // The mock always springs (no #445 refusal), so `fire`
            // records `sprungSpace` as before.
            return true
        }
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
    func dwellSpringsThenPlaces() async {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B"),
            dwell: 0.05
        )
        coord.moved(win, cursor: cursor)
        // Await the dwell's own timeline rather than poll a wall
        // clock for its effect (#994; `tests.md` ▸ Async tests).
        // The spring fires from a `@MainActor` Task, so a deadline
        // here measured how long the *other* suites held the main
        // actor and not this coordinator at all: a 50 ms dwell was
        // measured taking 29.7 s of wall clock in a full run, and
        // raising the bound 30 → 120 s only chose the number the
        // next grown suite would cross.
        //
        // Read the handle before awaiting it — `fire` clears it —
        // and keep the non-nil check load-bearing: `await
        // nil?.value` returns at once, so an arm that scheduled no
        // dwell would otherwise sail through green.
        let dwell = coord.dwellTask
        #expect(dwell != nil, "arming scheduled no dwell")
        await dwell?.value
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

    @Test("Re-arming a new item clears the previous sweep")
    func rearmClearsPrevious() {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B")
        )
        coord.moved(win, cursor: cursor)
        let clearsAfterFirst = rec.clears
        // Move straight onto another item without leaving the bar.
        coord.hitTest = { _ in SpaceID("C") }
        coord.moved(win, cursor: cursor)
        #expect(rec.clears > clearsAfterFirst)
        #expect(rec.sweeps == [SpaceID("B"), SpaceID("C")])
    }

    @Test("reset cancels a pending spring (abandoned drag)")
    func resetCancelsSpring() async {
        let (coord, rec) = make(
            current: SpaceID("A"),
            hit: SpaceID("B"),
            dwell: 0.05
        )
        coord.moved(win, cursor: cursor)
        #expect(coord.isArmed)
        #expect(coord.draggingWindow == win)
        let dwell = coord.dwellTask
        #expect(dwell != nil, "arming scheduled no dwell")
        coord.reset()
        #expect(!coord.isArmed)
        #expect(coord.draggingWindow == nil)
        // Read the cancelled timeline rather than sleep past the
        // dwell and hope: `isCancelled` is the fact itself, and
        // awaiting the handle afterwards says the spring never
        // fired instead of that it had not fired *yet*.
        #expect(dwell?.isCancelled == true)
        await dwell?.value
        #expect(rec.sprang.isEmpty)
    }
}
