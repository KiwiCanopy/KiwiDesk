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

    /// Placed a pass earlier with nothing ordered in, so only the
    /// order-in's own stamp keeps the move out of the pass AppKit
    /// creates the window in (`BorderPanelMoveTests`' ring twin).
    @Test("The pass that first orders an overflow mark in stays AppKit's")
    func overflowOrderInStampsThePass() {
        let spy = Spy()
        let overlay = OverflowMarkOverlay(
            mark: mark(anchor: start),
            movePanel: spy.move
        )
        defer { overlay.hide() }
        overlay.ordersPanel = false
        overlay.update(frame: start)
        endPass()
        overlay.ordersPanel = true
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

/// The managers hand each overlay they make their own move, so a
/// `movePanel` wired in Bootstrap reaches every mark (#2531).
@Suite("Mark managers hand their move to each mark", .serialized)
@MainActor
struct MarkManagerMoveTests {
    private let start = CGRect(x: -9_000, y: -9_000, width: 400, height: 300)
    private var moved: CGRect { start.offsetBy(dx: 60, dy: 40) }

    @Test("A sticky mark made by its manager moves through its move")
    func stickyManagerHandsTheMove() {
        var moves = 0
        let manager = StickyMarkManager()
        manager.movePanel = { _, _ in
            moves += 1
            return true
        }
        defer { manager.sync([]) }
        manager.sync([.init(window: WindowID(1), frame: start, glass: false)])
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        manager.reposition(WindowID(1), windowFrame: moved)
        #expect(moves == 1)
    }

    @Test("An overflow mark made by its manager moves through its move")
    func overflowManagerHandsTheMove() {
        var moves = 0
        let manager = OverflowMarkManager()
        manager.movePanel = { _, _ in
            moves += 1
            return true
        }
        defer { manager.sync([]) }
        let mark = OverflowMark(
            space: SpaceID("1"),
            anchor: WindowID(1),
            end: .right,
            windows: [WindowID(2)],
            bounds: start.insetBy(dx: -500, dy: -500),
            zoneOrigin: .zero
        )
        manager.sync([
            .init(
                mark: mark,
                frame: start,
                name: "",
                shelf: KiwiShelf(),
                spans: false
            )
        ])
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        manager.reposition(WindowID(1), windowFrame: moved)
        #expect(moves == 1)
    }
}
