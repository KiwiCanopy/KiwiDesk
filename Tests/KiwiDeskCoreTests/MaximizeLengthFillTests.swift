import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A length resolves at the fill alone (#3460): below the axis it
/// is that many points, at or above it the axis whole, the shape's
/// axis kept; the anchor places it as it places a fraction.
@Suite("Maximize length fill (#3460)")
struct MaximizeLengthFillTests {
    private let screen = CGRect(x: 100, y: 50, width: 3200, height: 900)
    private let slot = CGRect(x: 2900, y: 50, width: 400, height: 300)

    private func bounds(
        _ axis: MaximizeAxis,
        _ points: CGFloat,
        _ anchor: MaximizeAnchor
    ) -> CGRect {
        TilingEngine.maximizedBounds(
            MaximizeShape(axis: axis, share: .points(points), anchor: anchor),
            screen: screen,
            slot: slot
        )
    }

    @Test("Height takes the length below, at and above the width")
    func heightTable() {
        let rows: [(CGFloat, MaximizeAnchor, CGRect)] = [
            (1280, .center, CGRect(x: 1060, y: 50, width: 1280, height: 900)),
            // In place, centred on the slot and moved back inside.
            (1280, .inPlace, CGRect(x: 2020, y: 50, width: 1280, height: 900)),
            (3200, .center, screen),
            (5000, .center, screen),
            (5000, .inPlace, screen),
        ]
        for (points, anchor, expected) in rows {
            #expect(bounds(.height, points, anchor) == expected)
        }
    }

    @Test("Width takes the length below, at and above the height")
    func widthTable() {
        let rows: [(CGFloat, MaximizeAnchor, CGRect)] = [
            (600, .center, CGRect(x: 100, y: 200, width: 3200, height: 600)),
            (600, .inPlace, CGRect(x: 100, y: 50, width: 3200, height: 600)),
            (900, .center, screen),
            (1400, .inPlace, screen),
        ]
        for (points, anchor, expected) in rows {
            #expect(bounds(.width, points, anchor) == expected)
        }
    }

    /// A length longer than its axis keeps the shape's axis: it is
    /// still a Height or Width Maximize, never a full one.
    @Test("an overflowing length keeps its axis")
    func overflowKeepsTheAxis() {
        let shape = MaximizeShape(axis: .height, share: .points(5000))
        #expect(shape.axis == .height)
    }

    /// A fraction still resolves as before, clamped to its range.
    @Test("a fraction is unchanged")
    func fractionUnchanged() {
        let rect = TilingEngine.maximizedBounds(
            MaximizeShape(axis: .height, share: .fraction(0.25)),
            screen: screen,
            slot: slot
        )
        #expect(rect.width == 800)
        let floor = TilingEngine.maximizedBounds(
            MaximizeShape(axis: .height, share: .fraction(0.01)),
            screen: screen,
            slot: slot
        )
        #expect(floor.width == 320)
    }
}
