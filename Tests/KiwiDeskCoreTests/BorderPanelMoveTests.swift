import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1956: a ring panel the ring's size moves through SkyLight
/// rather than AppKit's fenced `setFrame`, once WindowServer has
/// its window and AppKit has not set its frame this run loop pass;
/// everything else stays AppKit's (#1937). The pass is a counter
/// each test advances by hand, and the move a spy.
@Suite("Border ring panel moves")
@MainActor
struct BorderPanelMoveTests {
    private final class Spy {
        var moves: [CGPoint] = []
        var answers = true
        var pass: UInt64 = 0
    }

    private func ring(_ spy: Spy) -> AppKitBorderOverlay {
        AppKitBorderOverlay(
            order: .below,
            restack: { _, _, _ in true },
            movePanel: { _, origin in
                spy.moves.append(origin)
                return spy.answers
            },
            pass: { spy.pass }
        )
    }

    private func render(
        _ ring: AppKitBorderOverlay,
        at origin: CGPoint,
        size: CGSize = CGSize(width: 400, height: 300),
        room: CGRect? = nil
    ) {
        ring.update(
            geometry: BorderGeometry.compute(
                windowFrame: CGRect(origin: origin, size: size),
                width: 4,
                cornerStyle: .rounded,
                order: .below,
                systemRadius: 10
            ),
            colorHex: "#FF0000",
            screen: nil,
            room: room
        )
    }

    /// The AppKit frame an exact panel takes for a ring at `origin`.
    private func exactFrame(at origin: CGPoint) -> CGRect {
        let exact = AppKitBorderOverlay(
            order: .below,
            movePanel: { _, _ in false }
        )
        render(exact, at: origin)
        return exact.panelFrame ?? .zero
    }

    /// The top-left origin SkyLight is handed for a ring at `origin`.
    private func topLeft(at origin: CGPoint) -> CGPoint {
        GeometryUtils.flip(
            exactFrame(at: origin),
            primaryHeight: GeometryUtils.primaryHeight
        ).origin
    }

    /// Placed so the flip moves y whatever the host's height is:
    /// a frame centred on the flip's axis would read the same
    /// either way.
    private var start: CGPoint {
        CGPoint(
            x: 100,
            y: (GeometryUtils.primaryHeight / 2).rounded() - 400
        )
    }
    private var moved: CGPoint { CGPoint(x: 160, y: start.y + 40) }

    /// An ordered-in ring, one pass after AppKit placed it.
    private func shownRing(_ spy: Spy) -> AppKitBorderOverlay {
        let ring = ring(spy)
        render(ring, at: start)
        ring.order(relativeTo: 7)
        spy.pass += 1
        return ring
    }

    @Test("A shown ring of unchanged size moves through SkyLight")
    func sameSizeMoveSkipsAppKit() throws {
        let spy = Spy()
        let ring = shownRing(spy)
        let room = exactFrame(at: start).insetBy(dx: -1000, dy: -1000)
        render(ring, at: moved, room: room)
        try #require(topLeft(at: moved) != exactFrame(at: moved).origin)
        #expect(spy.moves == [topLeft(at: moved)])
        #expect(ring.frameSets == 1)
        #expect(ring.skyLightMoves == 1)
        // The panel stays exact, so the ring sits at its origin.
        #expect(ring.ringFrameInPanel.origin == .zero)
    }

    @Test("A ring moved away and back moves twice")
    func roundTripMovesBack() {
        let spy = Spy()
        let ring = shownRing(spy)
        render(ring, at: moved)
        render(ring, at: start)
        #expect(spy.moves == [topLeft(at: moved), topLeft(at: start)])
        #expect(ring.frameSets == 1)
    }

    @Test("An animation's first render leaves an unmoved ring exact")
    func unmovedRingKeepsExactPanel() {
        let spy = Spy()
        let ring = shownRing(spy)
        let room = exactFrame(at: start).insetBy(dx: -1000, dy: -1000)
        render(ring, at: start, room: room)
        #expect(ring.frameSets == 1)
        #expect(spy.moves.isEmpty)
        #expect(ring.panelFrame == exactFrame(at: start))
    }

    @Test("A ring that changes size takes AppKit")
    func resizeTakesAppKit() {
        let spy = Spy()
        let ring = shownRing(spy)
        render(ring, at: moved, size: CGSize(width: 420, height: 300))
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 2)
    }

    @Test("A panel never ordered in takes AppKit")
    func neverOrderedTakesAppKit() {
        let spy = Spy()
        let ring = ring(spy)
        render(ring, at: start)
        spy.pass += 1
        render(ring, at: moved)
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 2)
    }

    @Test("A hidden panel keeps its window and still moves")
    func hiddenPanelStillMoves() {
        let spy = Spy()
        let ring = shownRing(spy)
        ring.hide()
        render(ring, at: moved)
        #expect(spy.moves == [topLeft(at: moved)])
        #expect(ring.frameSets == 1)
    }

    @Test("AppKit keeps the frame for the rest of a pass it set it in")
    func samePassStaysAppKit() {
        let spy = Spy()
        let ring = shownRing(spy)
        render(ring, at: moved, size: CGSize(width: 420, height: 300))
        render(ring, at: start, size: CGSize(width: 420, height: 300))
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 3)
        spy.pass += 1
        render(ring, at: moved, size: CGSize(width: 420, height: 300))
        #expect(spy.moves.count == 1)
    }

    @Test("The pass that first orders the panel in stays AppKit's")
    func firstShowPassStaysAppKit() {
        let spy = Spy()
        let ring = ring(spy)
        render(ring, at: start)
        ring.order(relativeTo: 7)
        render(ring, at: moved)
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 2)
    }

    @Test("A missing symbol keeps the room for an animating ring")
    func absentSymbolKeepsTheRoom() {
        let spy = Spy()
        spy.answers = false
        let ring = shownRing(spy)
        let room = exactFrame(at: start).insetBy(dx: -1000, dy: -1000)
        render(ring, at: moved, room: room)
        #expect(spy.moves.count == 1)
        #expect(ring.skyLightMoves == 0)
        #expect(ring.frameSets == 2)
        #expect(ring.panelFrame == room)
    }
}
