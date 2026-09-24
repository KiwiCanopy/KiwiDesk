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

    /// Ten 100 pt entries, no gap (run 1000), a 400 viewport,
    /// 50 pt fades: the clear view is 50…350 of the viewport.
    private func page(
        from offset: CGFloat,
        forward: Bool,
        lengths: [CGFloat]? = nil
    ) -> CGFloat {
        ShelfOverflow.pageTarget(
            from: offset,
            lengths: lengths ?? self.lengths,
            gap: 0,
            viewport: 400,
            fade: 50,
            forward: forward
        )
    }

    @Test("A page lands on an entry boundary")
    func pagesAlignToEntries() {
        // From 0 the clear view ends at 350: entry 3 (300…400) is
        // the first not wholly clear, so it arrives just past the
        // near fade — offset 250.
        #expect(page(from: 0, forward: true) == 250)
        // Back from 450: clear view starts at 500, entry 4
        // (400…500) is the last not clear, its end arrives just
        // before the far fade — 500 - 400 + 50.
        #expect(page(from: 450, forward: false) == 150)
    }

    /// The owner's report: a page that stopped a few points short
    /// left the last entry "almost" shown and the arrow on.
    @Test("A page never stops a sliver short of an end")
    func pagesReachTheEnds() {
        // The run's last offset is 600; forward from 250 lands on
        // 550, less than an entry short — so it goes to 600.
        #expect(page(from: 250, forward: true) == 600)
        #expect(page(from: 600, forward: true) == 600)
        // Back from 90 would land under an entry from the start.
        #expect(page(from: 90, forward: false) == 0)
        #expect(page(from: 0, forward: false) == 0)
    }

    @Test("An entry wider than the clear view still moves a view")
    func wideEntryStillMoves() {
        let wide: [CGFloat] = [100, 900, 100]
        let next = page(from: 0, forward: true, lengths: wide)
        #expect(next > 0)
        #expect(next <= 700)
    }
}
