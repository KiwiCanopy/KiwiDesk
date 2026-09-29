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
    /// focus change never changes its length (item 20): the
    /// glyphs drawn plus one cell per side that hides a group.
    @Test("an overflowing chip keeps one width")
    func fixedWidth() {
        for count in 7...12 {
            for anchor in 0..<count {
                let window = SpaceBarStrip.window(
                    count: count,
                    span: 5,
                    anchor: anchor
                )
                let discs =
                    (window.lowerBound > 0 ? 1 : 0)
                    + (window.upperBound < count ? 1 : 0)
                #expect(
                    window.count + discs == 7,
                    "count \(count), anchor \(anchor)"
                )
            }
        }
    }

    private func drawn(_ window: Range<Int>, of count: Int = 9)
        -> SpaceBarStrip.Drawn
    {
        .init(window: window, count: count)
    }

    @Test("a held window is kept only while the row still draws it")
    func heldWindowShapes() {
        #expect(drawn(0..<6).holds(count: 9, span: 5))
        #expect(drawn(2..<7).holds(count: 9, span: 5))
        #expect(drawn(3..<9).holds(count: 9, span: 5))
        #expect(!drawn(0..<5).holds(count: 9, span: 5))
        #expect(!drawn(4..<9).holds(count: 9, span: 5))
        #expect(drawn(0..<4, of: 4).holds(count: 4, span: 5))
        // A row that gained or lost a group shifts every index:
        // even a shape it could draw is not the one held.
        #expect(!drawn(2..<7).holds(count: 10, span: 5))
        #expect(!drawn(2..<7, of: 10).holds(count: 9, span: 5))
        #expect(!drawn(2..<7, of: 7).holds(count: 7, span: 5))
    }

    @Test("a step through the middle walks one cell, one glyph each end")
    func middleStep() {
        #expect(
            SpaceBarStrip.Walk.between(
                drawn(2..<7),
                leadingDisc: true,
                drawn(3..<8),
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
                drawn(3..<8),
                leadingDisc: true,
                drawn(2..<7),
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
                drawn(0..<6),
                leadingDisc: false,
                drawn(1..<6),
                leadingDisc: true
            ) == .init(cells: 0, leavingFront: 1)
        )
    }

    @Test("an unchanged or unknown strip plays no walk")
    func noWalk() {
        #expect(
            SpaceBarStrip.Walk.between(
                drawn(1..<6),
                leadingDisc: true,
                drawn(1..<6),
                leadingDisc: true
            ) == nil
        )
        #expect(
            SpaceBarStrip.Walk.between(
                nil,
                leadingDisc: false,
                drawn(1..<6),
                leadingDisc: true
            ) == nil
        )
    }

    /// A window opened or closed shifts every index, so the same
    /// numbers name other apps: nothing walks.
    @Test("a row that changed plays no walk")
    func changedRowNoWalk() {
        #expect(
            SpaceBarStrip.Walk.between(
                drawn(2..<7),
                leadingDisc: true,
                drawn(3..<8, of: 10),
                leadingDisc: true
            ) == nil
        )
    }

    /// A jump from one end to the other shares no glyph: walking
    /// it would slide glyphs across the neighbouring chips.
    @Test("a jump that shares no group plays no walk")
    func jumpNoWalk() {
        #expect(
            SpaceBarStrip.Walk.between(
                drawn(0..<6, of: 14),
                leadingDisc: false,
                drawn(8..<14, of: 14),
                leadingDisc: true
            ) == nil
        )
        // One shared group still walks.
        #expect(
            SpaceBarStrip.Walk.between(
                drawn(0..<6, of: 14),
                leadingDisc: false,
                drawn(5..<10, of: 14),
                leadingDisc: true
            ) != nil
        )
    }
}
