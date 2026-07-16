import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pure-outset ring geometry (#303): the whole stroke sits
/// outside the window frame — one uniform `width` outward offset
/// on every side, every corner style — so it never touches window
/// content, and the rounded radius grows concentrically by
/// `width / 2`.
@Suite("Border geometry")
struct BorderGeometryTests {
    private let window = CGRect(x: 100, y: 100, width: 200, height: 150)

    @Test("Default 2 pt: fully outset by the width")
    func defaultWidth() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 2,
            cornerStyle: .rounded,
            systemRadius: 16
        )
        // Outward reach = the full width now.
        #expect(g.overlayFrame == window.insetBy(dx: -2, dy: -2))
        #expect(g.lineWidth == 2)
        // Radius = 16 + width/2 = 17 (concentric centerline).
        #expect(g.cornerRadius == 17)
    }

    @Test("Thick width outsets by the full width")
    func thickWidth() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .rounded,
            systemRadius: 16
        )
        #expect(g.overlayFrame == window.insetBy(dx: -10, dy: -10))
        #expect(g.lineWidth == 10)
        // radius = 16 + 10/2 = 21.
        #expect(g.cornerRadius == 21)
    }

    @Test("Square outsets identically, radius 0")
    func square() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .square,
            systemRadius: 16
        )
        #expect(g.cornerRadius == 0)
        // Square reaches outward by the full width, same as rounded.
        #expect(g.overlayFrame == window.insetBy(dx: -10, dy: -10))
        #expect(g.lineWidth == 10)
    }

    @Test("outwardReach is the clamped width")
    func outwardReach() {
        #expect(BorderGeometry.outwardReach(width: 10) == 10)
        #expect(BorderGeometry.outwardReach(width: 2) == 2)
        // Clamped defensively into range.
        #expect(
            BorderGeometry.outwardReach(width: 999)
                == BorderStyle.maxWidth
        )
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
