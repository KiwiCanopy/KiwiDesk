import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// #1937: a panel resize hands WindowServer a fenced transaction the
/// main actor waits on, once per frame of an animation. An animating
/// ring moves inside a room-sized panel instead, resized once, and a
/// settled render resizes the panel back to the ring. Every room
/// here is derived from the ring's own flipped frame, so no clause
/// reads the host's displays (#531).
@Suite("Border ring moving room")
@MainActor
struct BorderMovingRoomTests {
    private func render(
        _ ring: AppKitBorderOverlay,
        at origin: CGPoint,
        room: CGRect?
    ) {
        ring.update(
            geometry: BorderGeometry.compute(
                windowFrame: CGRect(
                    origin: origin,
                    size: CGSize(width: 400, height: 300)
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

    /// The panel an exact render at `origin` takes, outset so a ring
    /// moving 400 pt from there still fits.
    private func room(around origin: CGPoint) -> CGRect {
        let exact = AppKitBorderOverlay(order: .below)
        render(exact, at: origin, room: nil)
        return (exact.panelFrame ?? .zero).insetBy(dx: -1000, dy: -1000)
    }

    @Test("The panel takes the room only while it holds the ring")
    func panelFrameRule() {
        let room = CGRect(x: 0, y: 0, width: 2000, height: 1200)
        let ring = CGRect(x: 100, y: 100, width: 400, height: 300)
        #expect(AppKitBorderOverlay.panelFrame(for: ring, room: room) == room)
        #expect(AppKitBorderOverlay.panelFrame(for: ring, room: nil) == ring)
        // Straddling the room's edge is outside it.
        let outside = ring.offsetBy(dx: 1800, dy: 0)
        #expect(
            AppKitBorderOverlay.panelFrame(for: outside, room: room)
                == outside
        )
    }

    @Test("A room holds a ring at its screen's edge or past it")
    func roomCoversEdges() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let room = BorderManager.room(around: screen, scale: 2)
        // A ring whose glow reaches past the edge, and one sliding
        // in from a parked corner, both fit.
        #expect(room.contains(CGRect(x: -12, y: -12, width: 600, height: 400)))
        #expect(
            room.contains(CGRect(x: 1700, y: 1100, width: 900, height: 700))
        )
    }

    @Test("A moving ring resizes its panel once, then only moves")
    func movingRingResizesOnce() {
        let start = CGPoint(x: 100, y: 200)
        let room = room(around: start)
        let ring = AppKitBorderOverlay(order: .below)
        let exact = AppKitBorderOverlay(order: .below)
        for step in 0..<10 {
            let origin = CGPoint(x: start.x + CGFloat(step * 40), y: start.y)
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

    @Test("A settled render resizes the panel back to the ring")
    func settleShrinksPanel() {
        let start = CGPoint(x: 100, y: 200)
        let room = room(around: start)
        let ring = AppKitBorderOverlay(order: .below)
        render(ring, at: start, room: room)
        #expect(ring.panelFrame == room)
        render(ring, at: CGPoint(x: 140, y: 200), room: nil)
        #expect(ring.frameSets == 2)
        #expect(ring.ringFrameInPanel.origin == .zero)
        #expect(ring.panelFrame?.size == ring.ringFrameInPanel.size)
    }

    @Test("Both writers offer the room only mid-animation")
    func managerOffersRoomWhileAnimating() {
        let border = BorderManager()
        border.restack = { _, _, _ in false }
        border.moveWindow = { _, _ in false }
        defer { border.clear() }
        let backend = RoomCapturingBackend()
        border.backendFactory = { backend }
        border.watchOverride = { _ in true }
        let screen = CGRect(x: 0, y: 0, width: 1000, height: 800)
        border.roomScreenOverride = screen
        let frame = CGRect(x: 0, y: 0, width: 400, height: 300)
        let spec = BorderManager.Spec(
            window: WindowID(9),
            frame: frame,
            colorHex: "#FF0000",
            width: 4,
            cornerStyle: .rounded
        )
        border.sync([spec], alive: nil, reassertOrder: false)
        #expect(backend.rooms.last == .some(nil))
        border.isAnimating = { _ in true }
        let room = BorderManager.room(around: screen, scale: 2)
        border.sync([spec], alive: nil, reassertOrder: false)
        #expect(backend.rooms.last == room)
        border.apply(WindowID(9), windowFrame: frame)
        #expect(backend.rooms.last == room)
        border.isAnimating = { _ in false }
        border.apply(WindowID(9), windowFrame: frame)
        #expect(backend.rooms.last == .some(nil))
    }

    @Test("A room stays inside AppKit's window limit")
    func roomIsCapped() {
        let wide = CGRect(x: 0, y: 0, width: 5120, height: 2160)
        let room = BorderManager.room(around: wide, scale: 2)
        #expect(room.width <= BorderManager.roomLimit)
        #expect(room.height <= BorderManager.roomLimit)
        #expect(BorderManager.roomLimit < 10000)
        #expect(room.contains(wide))
    }

    /// #1956: the ring of a window parked in the stash corner —
    /// mostly past the screen, a sliver on it — or sliding in from
    /// there fits the room, so it never takes an exact panel whose
    /// every move the main actor waited ~500 ms on mid-switch.
    @Test("A room holds a ring parked in the corner")
    func roomHoldsParkedRing() {
        let screen = CGRect(x: 0, y: 0, width: 1728, height: 1117)
        let room = BorderManager.room(around: screen, scale: 2)
        // Measured on the owner's desk: a 1372×963 ring parked at
        // the bottom-right corner, AppKit coordinates.
        let parked = CGRect(x: 1622, y: -842, width: 1372, height: 963)
        #expect(room.contains(parked))
        // The widest ring around a screen-sized window, parked in
        // either corner. Built in AX coordinates: the room is
        // symmetric about a screen at the origin, so the flip to
        // AppKit's keeps containment.
        for corner in [TilingEngine.HideCorner.bottomRight, .bottomLeft] {
            let window = TilingEngine.stashFrame(
                screen,
                in: screen,
                corner: corner
            )
            let ringFrame = BorderGeometry.compute(
                windowFrame: window,
                width: BorderStyle.maxWidth,
                cornerStyle: .rounded,
                order: .below,
                systemRadius: 10,
                glowBlur: BorderStyle.maxGlowSize
            ).overlayFrame
            #expect(room.contains(ringFrame), "\(corner)")
        }
    }

    @Test("KiwiDesk's chrome is never a front presentation")
    func ownChromeLeavesFrontFrames() {
        let row: (pid_t, Int, CGFloat) -> [String: Any] = {
            pid,
            number,
            x in
            [
                kCGWindowLayer as String: 0,
                kCGWindowAlpha as String: 1.0,
                kCGWindowOwnerPID as String: pid,
                kCGWindowNumber as String: number,
                kCGWindowBounds as String: [
                    "X": x, "Y": 0, "Width": 100, "Height": 100,
                ],
            ]
        }
        var raised = row(77, 10, 600)
        raised[kCGWindowLayer as String] = 3
        var clear = row(77, 11, 800)
        clear[kCGWindowAlpha as String] = 0.0
        // A ring panel (own, chrome), the tiled Settings window
        // (own, not chrome), another app's window, and two rows no
        // presentation is: a raised layer and an invisible one.
        let frames = FloatDetection.normalFrames(
            in: [
                row(42, 5, 0), row(42, 6, 200), row(77, 9, 400),
                raised, clear,
            ]
        ) { pid, number in pid == 42 && number == 5 }
        #expect(frames.map(\.minX) == [200, 400])
    }
}

extension BorderMovingRoomTests {
    /// The production room comes from the screen the ring renders
    /// on; every other manager clause pins it.
    @Test(
        "An animating ring's room comes from its screen",
        .enabled(if: !NSScreen.screens.isEmpty)
    )
    func roomComesFromTheScreen() throws {
        let border = BorderManager()
        defer { border.clear() }
        let screen = try #require(NSScreen.screens.first)
        border.isAnimating = { _ in true }
        #expect(
            border.room(for: WindowID(9), screen: screen)
                == BorderManager.room(
                    around: screen.frame,
                    scale: screen.backingScaleFactor
                )
        )
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
