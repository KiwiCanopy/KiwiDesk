import Testing

@testable import KiwiDeskCore

/// The centred strip's arithmetic (#1528 items 17, 20, 21): the
/// window centred on the anchor and clamped, the fixed width it
/// spends, the windows a held strip may keep, and the walk a
/// moved strip plays.
@Suite("Space Bar centred strip")
struct SpaceBarStripTests {
    /// Nine groups, span 5: every anchor's window, the ends
    /// clamped to span + 1 glyphs, the middle span glyphs.
    @Test("the window centres on the anchor and clamps at the ends")
    func windowCentresAndClamps() {
        let expected: [Range<Int>] = [
            0..<6, 0..<6, 0..<6, 1..<6, 2..<7, 3..<8, 3..<9, 3..<9,
            3..<9,
        ]
        for anchor in 0..<9 {
            let window = SpaceBarStrip.window(
                count: 9,
                span: 5,
                anchor: anchor
            )
            #expect(window == expected[anchor], "anchor \(anchor)")
            #expect(window.contains(anchor), "anchor \(anchor)")
        }
    }

    @Test("an even span puts its extra glyph after the focus")
    func evenSpanLeansTrailing() {
        #expect(SpaceBarStrip.window(count: 9, span: 4, anchor: 4) == 3..<7)
    }

    @Test("a row that fits draws whole, with no anchor from the start")
    func fitsAndDefaults() {
        #expect(SpaceBarStrip.window(count: 6, span: 5, anchor: 5) == 0..<6)
        #expect(SpaceBarStrip.window(count: 0, span: 5, anchor: nil) == 0..<0)
        #expect(SpaceBarStrip.window(count: 9, span: 5, anchor: nil) == 0..<6)
    }

    /// The chip spends span + 2 cells whatever the anchor, so a
    /// focus change never changes its length (item 20).
    @Test("an overflowing chip keeps one width")
    func fixedWidth() {
        for anchor in 0..<9 {
            let window = SpaceBarStrip.window(
                count: 9,
                span: 5,
                anchor: anchor
            )
            let discs =
                (window.lowerBound > 0 ? 1 : 0)
                + (window.upperBound < 9 ? 1 : 0)
            #expect(window.count + discs == 7, "anchor \(anchor)")
        }
        #expect(SpaceBarStrip.cells(count: 9, span: 5) == 7)
        #expect(SpaceBarStrip.cells(count: 6, span: 5) == 6)
        #expect(SpaceBarStrip.cells(count: 3, span: 5) == 3)
    }

    @Test("a held window is kept only while the row still draws it")
    func heldWindowShapes() {
        #expect(SpaceBarStrip.isWindow(0..<6, count: 9, span: 5))
        #expect(SpaceBarStrip.isWindow(2..<7, count: 9, span: 5))
        #expect(SpaceBarStrip.isWindow(3..<9, count: 9, span: 5))
        #expect(!SpaceBarStrip.isWindow(0..<5, count: 9, span: 5))
        #expect(!SpaceBarStrip.isWindow(4..<9, count: 9, span: 5))
        #expect(!SpaceBarStrip.isWindow(2..<7, count: 7, span: 5))
        #expect(SpaceBarStrip.isWindow(0..<4, count: 4, span: 5))
    }

    @Test("a step through the middle walks one cell, one glyph each end")
    func middleStep() {
        #expect(
            SpaceBarStrip.Walk.between(
                2..<7,
                leadingDisc: true,
                3..<8,
                leadingDisc: true
            )
                == .init(
                    cells: 1,
                    leavingFront: 1,
                    enteringBack: 1
                )
        )
        #expect(
            SpaceBarStrip.Walk.between(
                3..<8,
                leadingDisc: true,
                2..<7,
                leadingDisc: true
            )
                == .init(
                    cells: -1,
                    leavingBack: 1,
                    enteringFront: 1
                )
        )
    }

    /// Leaving the row's start, the disc appears in the first
    /// glyph's cell: nothing travels, that glyph fades under it.
    @Test("a disc appearing takes the cell of the glyph it hides")
    func discAppears() {
        #expect(
            SpaceBarStrip.Walk.between(
                0..<6,
                leadingDisc: false,
                1..<6,
                leadingDisc: true
            ) == .init(cells: 0, leavingFront: 1)
        )
    }

    @Test("an unchanged or unknown strip plays no walk")
    func noWalk() {
        #expect(
            SpaceBarStrip.Walk.between(
                1..<6,
                leadingDisc: true,
                1..<6,
                leadingDisc: true
            ) == nil
        )
        #expect(
            SpaceBarStrip.Walk.between(
                nil,
                leadingDisc: false,
                1..<6,
                leadingDisc: true
            ) == nil
        )
    }
}
