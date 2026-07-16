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

    @Test("Square tucks the inner edge to the corner tangent")
    func square() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .square,
            systemRadius: 16
        )
        #expect(g.cornerRadius == 0)
        // inner = 16·(1 − √2/2) ≈ 4.686 (> the rounded 1 pt), so
        // the stroke reaches outward by only width − inner, less
        // than the rounded case's 9 pt — the band closes the gap.
        let tuck = 1 - CGFloat(2).squareRoot() / 2
        let inner = 16 * tuck
        let outer = 10 - inner
        #expect(
            g.overlayFrame == window.insetBy(dx: -outer, dy: -outer)
        )
    }

    @Test("A thin square tucks fully inside the window")
    func thinSquareTucksInside() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 2,
            cornerStyle: .square,
            systemRadius: 16
        )
        // inner (~4.686) exceeds the width, so outer is negative
        // and the overlay is inset *into* the window — a thin
        // square frame just inside the edge, no empty corner.
        #expect(g.overlayFrame.width < window.width)
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

    /// Seam guard: `outwardReach` must equal `compute`'s outward
    /// growth (floored at 0) for every style. Both derive from the
    /// one `innerOverlap`/`squareCornerTuck`, so this pins them
    /// together if the tuck constant is ever retuned (#311).
    @Test("outwardReach matches compute's outward offset")
    func outwardReachMatchesCompute() {
        let widths: [CGFloat] = [BorderStyle.minWidth, 2, 10, 20]
        for style in [BorderStyle.CornerStyle.rounded, .square] {
            for width in widths {
                let g = BorderGeometry.compute(
                    windowFrame: window,
                    width: width,
                    cornerStyle: style,
                    systemRadius: 16
                )
                let offset = window.minX - g.overlayFrame.minX
                let reach = BorderGeometry.outwardReach(
                    width: width,
                    cornerStyle: style,
                    systemRadius: 16
                )
                #expect(abs(reach - max(0, offset)) < 0.0001)
            }
        }
    }
}
