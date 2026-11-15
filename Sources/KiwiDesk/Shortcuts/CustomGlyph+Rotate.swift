import AppKit

/// The rotate glyph (#1873 ▸ Ruling amendment 2026-11-13, owner):
/// Apple's `hand.pinch`, thumb and index, under a two-way arc around
/// the fingertips. `hand.pinch` needs macOS 15, so the floor draws
/// `GestureListWords.rotateFloor`'s symbol instead.
extension CustomGlyph {
    /// The hand's box on the 20 pt grid, bottom right, and the
    /// fingertips' centre the arc turns about.
    private static let handBox = NSRect(x: 4, y: 6.6, width: 16, height: 13)
    private static let pivot = NSPoint(x: 10.9, y: 10.2)

    /// Drawn black at full strength, as the arc is: a symbol image
    /// otherwise draws in the label colour's lighter ink.
    static func rotateHand() {
        let config = NSImage.SymbolConfiguration(
            pointSize: 12,
            weight: .semibold
        ).applying(.init(paletteColors: [.black]))
        if let hand = NSImage(
            systemSymbolName: "hand.pinch",
            accessibilityDescription: nil
        )?.withSymbolConfiguration(config) {
            hand.draw(
                in: handBox,
                from: .zero,
                operation: .sourceOver,
                fraction: 1,
                respectFlipped: true,
                hints: nil
            )
        }
        arcArrows(radius: 7.6, from: 215, to: 345)
    }

    /// An arc over the pivot, clockwise on screen from `from` to
    /// `to` degrees (y down, so 270 is straight up), a head at each
    /// end.
    private static func arcArrows(
        radius: CGFloat,
        from: CGFloat,
        to: CGFloat
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
        for (angle, sign) in [(from, CGFloat(-1)), (to, 1)] {
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
