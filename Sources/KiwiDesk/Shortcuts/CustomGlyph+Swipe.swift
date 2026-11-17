import AppKit
import KiwiDeskCore

/// A swipe's direction badge (#1873 ▸ Ruling 2026-11-15, variant A
/// tightened, owner): the finger dots and one filled arrow almost
/// touching them, read as one mark, the arrow pointing the way the
/// fingers move. The whole-family form stays `.swipes(n)`.
extension CustomGlyph {
    /// The directions a badge draws: a swipe's four.
    static let badgeDirections: [GestureDirection] = [
        .left, .right, .up, .down,
    ]

    /// The finger counts a direction or axis badge is drawn for.
    static let badgeFingers = 2...4

    /// Dot pitch and radius per finger count, on the 20 pt grid.
    private static func badgeDots(_ n: Int) -> (pitch: CGFloat, r: CGFloat) {
        switch n {
        case 2: (6.0, 2.1)
        case 3: (5.0, 1.95)
        default: (4.3, 1.6)
        }
    }

    /// The badge pointing right, turned to `direction` about the
    /// grid's centre; y is down, so a quarter turn points down.
    static func swipeBadge(_ n: Int, _ direction: GestureDirection) {
        let turns: CGFloat =
            switch direction {
            case .down: 1
            case .left, .back: 2
            case .up: 3
            default: 0
            }
        NSGraphicsContext.saveGraphicsState()
        let turn = NSAffineTransform()
        turn.translateX(by: 10, yBy: 10)
        turn.rotate(byDegrees: 90 * turns)
        turn.translateX(by: -10, yBy: -10)
        turn.concat()
        let (pitch, r) = badgeDots(min(max(n, 2), 4))
        let column: CGFloat = 4.6
        for i in 0..<n {
            let y = 10 + (CGFloat(i) - CGFloat(n - 1) / 2) * pitch
            NSBezierPath(
                ovalIn: NSRect(
                    x: column - r,
                    y: y - r,
                    width: 2 * r,
                    height: 2 * r
                )
            ).fill()
        }
        let start = column + r + 1.1
        NSRect(x: start, y: 8.9, width: 14.2 - start, height: 2.2).fill()
        let head = NSBezierPath()
        head.move(to: NSPoint(x: 18.6, y: 10))
        head.line(to: NSPoint(x: 13.4, y: 5.6))
        head.line(to: NSPoint(x: 13.4, y: 14.4))
        head.close()
        head.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
}
