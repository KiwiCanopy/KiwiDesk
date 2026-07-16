import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The hidden-overlap ring geometry (#278): configured width stays
/// fully visible outside the target, with an additional fixed stroke
/// depth masked behind it.
@Suite("Border geometry")
struct BorderGeometryTests {
    private let window = CGRect(x: 100, y: 100, width: 200, height: 150)

    @Test("Default width stays fully visible outside")
    func defaultWidth() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 2,
            cornerStyle: .rounded,
            systemRadius: 16
        )
        #expect(g.overlayFrame == window.insetBy(dx: -2, dy: -2))
        #expect(
            g.lineWidth
                == 2 + BorderGeometry.roundedHiddenOverlap
        )
        #expect(
            g.cornerRadius
                == 16 + 2 - g.lineWidth / 2
        )
    }

    @Test("Thick width also keeps a fixed hidden overlap")
    func thickWidth() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .rounded,
            systemRadius: 16
        )
        #expect(g.overlayFrame == window.insetBy(dx: -10, dy: -10))
        #expect(
            g.lineWidth
                == 10 + BorderGeometry.roundedHiddenOverlap
        )
        #expect(
            g.cornerRadius
                == 16 + 10 - g.lineWidth / 2
        )
    }

    @Test("Square adds its deeper overlap to visible width")
    func square() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 10,
            cornerStyle: .square,
            systemRadius: 16
        )
        #expect(g.cornerRadius == 0)
        #expect(
            g.overlayFrame == window.insetBy(dx: -10, dy: -10)
        )
        #expect(
            g.lineWidth
                == 10 + BorderGeometry.squareHiddenOverlap
        )
    }

    @Test("A thin square does not lose width to the overlap")
    func thinSquareRemainsVisible() {
        let g = BorderGeometry.compute(
            windowFrame: window,
            width: 2,
            cornerStyle: .square,
            systemRadius: 16
        )
        #expect(g.overlayFrame == window.insetBy(dx: -2, dy: -2))
        #expect(
            g.lineWidth
                == 2 + BorderGeometry.squareHiddenOverlap
        )
    }

    @Test("Width is clamped defensively into range")
    func clamp() {
        let tooThin = BorderGeometry.compute(
            windowFrame: window,
            width: 0.1,
            cornerStyle: .rounded
        )
        #expect(
            tooThin.lineWidth
                == BorderStyle.minWidth
                + BorderGeometry.roundedHiddenOverlap
        )
        let tooThick = BorderGeometry.compute(
            windowFrame: window,
            width: 999,
            cornerStyle: .rounded
        )
        #expect(
            tooThick.lineWidth
                == BorderStyle.maxWidth
                + BorderGeometry.roundedHiddenOverlap
        )
    }

    /// Seam guard: `outwardReach` must equal `compute`'s outward
    /// growth for every style. The renderer-only overlap must never
    /// leak into this public reach.
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
                    width: width
                )
                #expect(abs(reach - offset) < 0.0001)
            }
        }
    }
}
