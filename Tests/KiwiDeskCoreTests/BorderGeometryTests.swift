import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The capped-inner ring geometry (#278): inner overlap is pinned
/// at `min(width/2, 1)` pt so a thick border never hides window
/// content, and the stroke's rounded radius tracks the offset.
@Suite("Border geometry")
struct BorderGeometryTests {
    private let window = CGRect(x: 100, y: 100, width: 200, height: 150)

    @Test("Default 2 pt: 1 pt in / 1 pt out, like centered")
    func defaultWidth() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 2,
            cornerStyle: .rounded,
            systemRadius: 16
        )
        // outer reach = width - min(width/2, 1) = 1.
        #expect(g.overlayFrame == window.insetBy(dx: -1, dy: -1))
        #expect(g.lineWidth == 2)
        // Offset 0 at default → radius == system radius.
        #expect(g.cornerRadius == 16)
    }

    @Test("Thick width caps inner at 1 pt, grows outward")
    func thickWidth() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .rounded,
            systemRadius: 16
        )
        // inner 1, outer 9.
        #expect(g.overlayFrame == window.insetBy(dx: -9, dy: -9))
        #expect(g.lineWidth == 10)
        // radius = 16 + (10/2 - 1) = 20.
        #expect(g.cornerRadius == 20)
    }

    @Test("Square style strokes at radius 0, same overlay frame")
    func square() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .square,
            systemRadius: 16
        )
        #expect(g.cornerRadius == 0)
        #expect(g.overlayFrame == window.insetBy(dx: -9, dy: -9))
    }

    @Test("Width is clamped defensively into range")
    func clamp() {
        let tooThin = BorderGeometry.compute(
            windowFrame: window,
            width: 0.1,
            cornerStyle: .rounded
        )
        #expect(tooThin.lineWidth == BorderStyle.minWidth)
        let tooThick = BorderGeometry.compute(
            windowFrame: window,
            width: 999,
            cornerStyle: .rounded
        )
        #expect(tooThick.lineWidth == BorderStyle.maxWidth)
    }
}
