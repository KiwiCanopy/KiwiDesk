import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1937: a panel resize hands WindowServer a fenced transaction the
/// main actor waits on, once per frame of an animation. An animating
/// ring moves inside a screen-sized panel instead, resized once, and
/// the settle resizes the panel back to the ring.
@Suite("Border ring moving room")
@MainActor
struct BorderMovingRoomTests {
    private let room = CGRect(x: 0, y: 0, width: 2000, height: 1200)

    private func render(
        _ ring: AppKitBorderOverlay,
        at origin: CGPoint,
        room: CGRect?
    ) {
        ring.update(
            geometry: BorderGeometry.compute(
                windowFrame: CGRect(
                    origin: origin,
                    size: CGSize(
                        width: 400,
                        height: 300
                    )
                ),
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

    @Test("The panel takes the room only while it holds the ring")
    func panelFrameRule() {
        let ring = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(AppKitBorderOverlay.panelFrame(for: ring, room: room) == room)
        #expect(AppKitBorderOverlay.panelFrame(for: ring, room: nil) == ring)
        let outside = ring.offsetBy(dx: 1900, dy: 0)
        #expect(
            AppKitBorderOverlay.panelFrame(for: outside, room: room)
                == outside
        )
    }

    @Test("A moving ring resizes its panel once, then only moves")
    func movingRingResizesOnce() {
        let ring = AppKitBorderOverlay(order: .below)
        let exact = AppKitBorderOverlay(order: .below)
        for step in 0..<10 {
            let origin = CGPoint(x: CGFloat(100 + step * 40), y: 200)
            render(ring, at: origin, room: room)
            render(exact, at: origin, room: nil)
            // The ring is drawn where an exact panel would put it.
            let drawn = ring.ringFrameInPanel.offsetBy(
                dx: ring.panelFrame?.minX ?? 0,
                dy: ring.panelFrame?.minY ?? 0
            )
            #expect(drawn == exact.panelFrame)
        }
        #expect(ring.frameSets == 1)
        #expect(ring.panelFrame == room)
    }

    @Test("The settle resizes the panel back to the ring")
    func settleShrinksPanel() {
        let ring = AppKitBorderOverlay(order: .below)
        render(ring, at: CGPoint(x: 100, y: 200), room: room)
        render(ring, at: CGPoint(x: 140, y: 200), room: nil)
        #expect(ring.frameSets == 2)
        #expect(ring.panelFrame != room)
        #expect(ring.ringFrameInPanel.origin == .zero)
        #expect(ring.panelFrame?.size == ring.ringFrameInPanel.size)
    }

    @Test("The manager offers the screen's room only mid-animation")
    func managerOffersRoomWhileAnimating() {
        let border = BorderManager()
        border.restack = { _, _, _ in false }
        defer { border.clear() }
        let backend = RoomCapturingBackend()
        border.backendFactory = { backend }
        border.watchOverride = { _ in true }
        let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        border.sync(
            [
                BorderManager.Spec(
                    window: WindowID(9),
                    frame: frame,
                    colorHex: "#FF0000",
                    width: 4,
                    cornerStyle: .rounded
                )
            ],
            alive: nil,
            reassertOrder: false
        )
        border.isAnimating = { _ in true }
        border.apply(WindowID(9), windowFrame: frame)
        let screen = border.screen(for: frame)?.frame
        if !NSScreen.screens.isEmpty { #expect(screen != nil) }
        #expect(backend.rooms.last == screen)
        border.isAnimating = { _ in false }
        border.apply(WindowID(9), windowFrame: frame)
        #expect(backend.rooms.last == .some(nil))
    }
}

@MainActor
private final class RoomCapturingBackend: BorderOverlayBackend {
    let orderMode: BorderGeometry.Order = .below
    private(set) var rooms: [CGRect?] = []
    func update(
        geometry: BorderGeometry,
        colorHex: String,
        screen: NSScreen?,
        room: CGRect?
    ) {
        rooms.append(room)
    }
    func order(relativeTo windowNumber: CGWindowID) {}
    func hide() {}
}
