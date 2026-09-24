import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The overflow arithmetic every shelf section reads (#1517).
@Suite("Shelf overflow")
struct ShelfOverflowTests {
    @Test(
        "The fade scales with thickness inside its bounds",
        arguments: [
            (CGFloat(10), CGFloat(32)),
            (24, 48),
            (40, 72),
            (60, 72),
        ]
    )
    func fadeScales(thickness: CGFloat, fade: CGFloat) {
        #expect(ShelfOverflow.fadeLength(thickness: thickness) == fade)
    }

    /// A short section keeps most of its content legible.
    @Test("The fade never takes more than its share of the section")
    func fadeCapped() {
        #expect(
            ShelfOverflow.fadeLength(thickness: 40, visible: 200)
                == 200 * ShelfOverflow.fadeShareCap
        )
        #expect(
            ShelfOverflow.fadeLength(thickness: 40, visible: 1000)
                == 72
        )
        #expect(
            ShelfOverflow.fadeLength(thickness: 40, visible: -5) == 0
        )
    }
}
