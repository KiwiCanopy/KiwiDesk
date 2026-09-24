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

@Suite("Shelf overflow counts and paging")
struct ShelfOverflowPagingTests {
    private let lengths: [CGFloat] = Array(repeating: 100, count: 10)

    @Test("Hidden items are counted on each side by their middle")
    func hiddenCounts() {
        // Items at 0,100,…,900 (no gap); viewport 250..570.
        let counts = ShelfOverflow.hiddenCounts(
            lengths: lengths,
            gap: 0,
            offset: 250,
            viewport: 320
        )
        // Middles 50,150 are before; 250 is on the edge (in).
        #expect(counts.before == 2)
        // Middles 650…950 are after; 550 is in.
        #expect(counts.after == 4)
        let none = ShelfOverflow.hiddenCounts(
            lengths: [100, 100],
            gap: 0,
            offset: 0,
            viewport: 200
        )
        #expect(none.before == 0 && none.after == 0)
    }

    @Test("A page moves a viewport less both fades, clamped")
    func paging() {
        #expect(
            ShelfOverflow.pageTarget(
                from: 0,
                total: 1000,
                viewport: 400,
                fade: 50,
                forward: true
            ) == 300
        )
        #expect(
            ShelfOverflow.pageTarget(
                from: 500,
                total: 1000,
                viewport: 400,
                fade: 50,
                forward: true
            ) == 600
        )
        #expect(
            ShelfOverflow.pageTarget(
                from: 100,
                total: 1000,
                viewport: 400,
                fade: 50,
                forward: false
            ) == 0
        )
        // Fades wider than half the viewport still move half.
        #expect(
            ShelfOverflow.pageTarget(
                from: 0,
                total: 1000,
                viewport: 100,
                fade: 40,
                forward: true
            ) == 50
        )
    }
}
