import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #2531: both marks follow their window through the ring's one
/// placement — a follow that keeps the panel's size moves through
/// SkyLight, never AppKit's fenced `setFrame`, whose commit waited
/// ~500 ms on a slow app while an overflow scrolled. Real panels,
/// parked off every screen, ordered in once; the run loop is
/// pumped past the pass AppKit created the window in, and the
/// move is a spy that moves nothing.
@Suite("Mark panels move through SkyLight", .serialized)
@MainActor
struct MarkPanelMoveTests {
    private final class Spy {
        var moves: [CGPoint] = []
        func move(_: CGWindowID, _ origin: CGPoint) -> Bool {
            moves.append(origin)
            return true
        }
    }

    private let start = CGRect(x: -9_000, y: -9_000, width: 400, height: 300)
    private var moved: CGRect { start.offsetBy(dx: 60, dy: 40) }

    /// Ends the pass AppKit created and placed the window in.
    private func endPass() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
    }

    private func mark(anchor: CGRect) -> OverflowMark {
        OverflowMark(
            space: SpaceID("1"),
            anchor: WindowID(1),
            end: .right,
            windows: [WindowID(2), WindowID(3)],
            bounds: anchor.insetBy(dx: -500, dy: -500),
            zoneOrigin: .zero
        )
    }

    @Test("An overflow mark's follow keeps its size and skips AppKit")
    func overflowFollowMovesThroughSkyLight() {
        let spy = Spy()
        let overlay = OverflowMarkOverlay(
            mark: mark(anchor: start),
            movePanel: spy.move
        )
        defer { overlay.hide() }
        overlay.update(frame: start)
        let first = overlay.placedFrame
        endPass()
        overlay.update(frame: moved)
        #expect(spy.moves.count == 1)
        #expect(overlay.placedFrame != first)
        #expect(overlay.placedFrame?.size == first?.size)
    }

    @Test("An overflow mark moved in the pass it first showed stays AppKit's")
    func overflowFirstShowPassStaysAppKit() {
        let spy = Spy()
        let overlay = OverflowMarkOverlay(
            mark: mark(anchor: start),
            movePanel: spy.move
        )
        defer { overlay.hide() }
        overlay.update(frame: start)
        overlay.update(frame: moved)
        #expect(spy.moves.isEmpty)
    }

    @Test("A sticky mark's follow keeps its size and skips AppKit")
    func stickyFollowMovesThroughSkyLight() {
        let spy = Spy()
        let overlay = StickyMarkOverlay(window: 1, movePanel: spy.move)
        defer { overlay.hide() }
        overlay.update(frame: start)
        endPass()
        overlay.update(frame: moved)
        #expect(spy.moves.count == 1)
    }

    @Test("A sticky mark moved in the pass it first showed stays AppKit's")
    func stickyFirstShowPassStaysAppKit() {
        let spy = Spy()
        let overlay = StickyMarkOverlay(window: 1, movePanel: spy.move)
        defer { overlay.hide() }
        overlay.update(frame: start)
        overlay.update(frame: moved)
        #expect(spy.moves.isEmpty)
    }
}
