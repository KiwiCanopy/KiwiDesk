import AppKit
import KiwiDeskCore

/// The rotate glyph (#1873 ▸ Ruling amendment 2026-11-13; shape
/// picked by the owner from renders, 2026-11-15): Apple's
/// `hand.pinch`, thumb and index, with a two-way arc turning about
/// the fingertips along the hand's left side, clear of the symbol's
/// own motion marks. `hand.pinch` needs macOS 15, so the floor draws
/// `GestureListWords.rotateFloor`'s symbol instead.
extension CustomGlyph {
    /// The hand's box on the 20 pt grid, bottom right, and the
    /// point the arc turns about.
    private static let handBox = NSRect(
        x: 5,
        y: 6.8,
        width: 15,
        height: 12.2
    )
    private static let pivot = NSPoint(x: 11, y: 12)

    /// Drawn black at full strength, as the arc is: a symbol image
    /// otherwise draws in the label colour's lighter ink.
    static func rotateHand(heads: Set<GestureDirection>) {
        let config = NSImage.SymbolConfiguration(
            pointSize: 12,
            weight: .semibold
        ).applying(.init(paletteColors: [.black]))
        // A fixed name; the floor's macOS has none and draws the arc
        // alone, where `GestureListWords.rotate` draws SF's arrow.
        NSImage(systemSymbolName: "hand.pinch", accessibilityDescription: nil)?
            .withSymbolConfiguration(config)?
            .draw(
                in: handBox,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        arcArrows(radius: 8, from: 150, to: 255, heads: heads)
    }

    /// An arc about the pivot, clockwise on screen from `from` to
    /// `to` degrees (y down, so 180 is left and 270 straight up), a
    /// head at each end.
    private static func arcArrows(
        radius: CGFloat,
        from: CGFloat,
        to: CGFloat,
        heads: Set<GestureDirection>
    ) {
        let arc = NSBezierPath()
        arc.appendArc(
            withCenter: pivot,
            radius: radius,
            startAngle: from,
            endAngle: to,
            clockwise: false
        )
        arc.lineWidth = 1.5
        arc.lineCapStyle = .round
        arc.stroke()
        // The arc runs clockwise on screen from `from` to `to`.
        let ends: [(CGFloat, CGFloat, GestureDirection)] = [
            (from, -1, .counterClockwise), (to, 1, .clockwise),
        ]
        for (angle, sign, way) in ends where heads.contains(way) {
            let a = angle * .pi / 180
            let tip = NSPoint(
                x: pivot.x + radius * cos(a),
                y: pivot.y + radius * sin(a)
            )
            // The tangent the arc leaves along at this end.
            let heading = a + sign * .pi / 2
            let head = NSBezierPath()
            for side in [-CGFloat.pi / 4.5, .pi / 4.5] {
                head.move(to: tip)
                head.line(
                    to: NSPoint(
                        x: tip.x - 3.2 * cos(heading + side),
                        y: tip.y - 3.2 * sin(heading + side)
                    )
                )
            }
            head.lineWidth = 1.5
            head.lineCapStyle = .round
            head.lineJoinStyle = .round
            head.stroke()
        }
    }
}
