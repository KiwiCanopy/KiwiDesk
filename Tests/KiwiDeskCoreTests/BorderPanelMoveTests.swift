import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1956: AppKit's `setFrame` ties a panel move to the next commit
/// with a fence, and a ring commit waited ~500 ms on it while
/// another app's window transaction held WindowServer up. An
/// ordered-in panel that keeps the ring's size moves through
/// SkyLight instead, mid-animation too; any other change of frame
/// stays AppKit's (#1937). Every expected origin is derived from
/// an exact panel's own frame, so no clause reads the host's
/// displays (#531).
@Suite("Border ring panel moves")
@MainActor
struct BorderPanelMoveTests {
    private final class MoveSpy {
        var moves: [CGPoint] = []
        var answers = true
    }

    private func ring(_ spy: MoveSpy) -> AppKitBorderOverlay {
        AppKitBorderOverlay(
            order: .below,
            restack: { _, _, _ in true },
            move: { _, origin in
                spy.moves.append(origin)
                return spy.answers
            }
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
        let exact = AppKitBorderOverlay(order: .below)
        render(exact, at: origin)
        return exact.panelFrame ?? .zero
    }

    private let start = CGPoint(x: 100, y: 200)
    private let moved = CGPoint(x: 160, y: 240)

    @Test("An ordered-in ring of unchanged size moves through SkyLight")
    func sameSizeMoveSkipsAppKit() {
        let spy = MoveSpy()
        let ring = ring(spy)
        render(ring, at: start)
        ring.order(relativeTo: 7)
        let room = exactFrame(at: start).insetBy(dx: -1000, dy: -1000)
        render(ring, at: moved, room: room)
        let target = exactFrame(at: moved)
        #expect(ring.frameSets == 1)
        #expect(ring.skyLightMoves == 1)
        #expect(
            spy.moves
                == [
                    GeometryUtils.flip(
                        target,
                        primaryHeight: GeometryUtils.primaryHeight
                    ).origin
                ]
        )
        // The panel stays exact, so the ring sits at its origin.
        #expect(ring.ringFrameInPanel.origin == .zero)
        #expect(ring.ringFrameInPanel.size == target.size)
    }

    @Test("An animation's first render leaves an unmoved ring exact")
    func unmovedRingKeepsExactPanel() {
        let spy = MoveSpy()
        let ring = ring(spy)
        render(ring, at: start)
        ring.order(relativeTo: 7)
        let room = exactFrame(at: start).insetBy(dx: -1000, dy: -1000)
        render(ring, at: start, room: room)
        #expect(ring.frameSets == 1)
        #expect(spy.moves.isEmpty)
        #expect(ring.panelFrame == exactFrame(at: start))
    }

    @Test("A ring that changes size takes AppKit")
    func resizeTakesAppKit() {
        let spy = MoveSpy()
        let ring = ring(spy)
        render(ring, at: start)
        ring.order(relativeTo: 7)
        render(ring, at: moved, size: CGSize(width: 420, height: 300))
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 2)
    }

    @Test("A panel not ordered in takes AppKit")
    func unorderedPanelTakesAppKit() {
        let spy = MoveSpy()
        let ring = ring(spy)
        render(ring, at: start)
        render(ring, at: moved)
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 2)
        ring.order(relativeTo: 7)
        ring.hide()
        render(ring, at: start)
        #expect(spy.moves.isEmpty)
        #expect(ring.frameSets == 3)
    }

    @Test("A missing symbol keeps the room for an animating ring")
    func absentSymbolKeepsTheRoom() {
        let spy = MoveSpy()
        spy.answers = false
        let ring = ring(spy)
        render(ring, at: start)
        ring.order(relativeTo: 7)
        let room = exactFrame(at: start).insetBy(dx: -1000, dy: -1000)
        render(ring, at: moved, room: room)
        #expect(spy.moves.count == 1)
        #expect(ring.skyLightMoves == 0)
        #expect(ring.frameSets == 2)
        #expect(ring.panelFrame == room)
    }

    @Test("The manager's seam reaches the ring's panel")
    func managerSeamReachesThePanel() {
        let border = BorderManager()
        defer { border.clear() }
        border.restack = { _, _, _ in false }
        var moves = 0
        border.moveWindow = { _, _ in
            moves += 1
            return true
        }
        border.watchOverride = { _ in true }
        let spec: (CGFloat) -> BorderManager.Spec = { x in
            BorderManager.Spec(
                window: WindowID(9),
                frame: CGRect(x: x, y: 200, width: 400, height: 300),
                colorHex: "#FF0000",
                width: 4,
                cornerStyle: .rounded
            )
        }
        border.sync([spec(100)], alive: nil, reassertOrder: false)
        #expect(moves == 0)
        border.sync([spec(160)], alive: nil, reassertOrder: false)
        #expect(moves == 1)
    }
}
