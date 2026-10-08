import Testing

@testable import KiwiDeskCore

/// The centred strip's arithmetic (#1528 items 17, 20, 21): the
/// window centred on the anchor and clamped, the fixed width it
/// spends, the windows a held strip may keep, and the walk a
/// moved strip plays.
@Suite("Space Bar centred strip")
struct SpaceBarStripTests {
    /// Nine groups, span 5: every anchor's window, the ends
    /// clamped to span + 1 glyphs, the middle span glyphs — and
    /// an anchor whose centred window would hide one group on a
    /// side clamped to that end instead (#2052).
    @Test("the window centres on the anchor and clamps at the ends")
    func windowCentresAndClamps() {
        let expected: [Range<Int>] = [
            0..<6, 0..<6, 0..<6, 0..<6, 2..<7, 3..<9, 3..<9, 3..<9,
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
        // span + 2 groups fill the cells the discs would take.
        #expect(SpaceBarStrip.window(count: 7, span: 5, anchor: 3) == 0..<7)
        #expect(SpaceBarStrip.window(count: 0, span: 5, anchor: nil) == 0..<0)
        #expect(SpaceBarStrip.window(count: 9, span: 5, anchor: nil) == 0..<6)
    }

    /// Every window `window` draws over a sweep of spans and of
    /// rows that overflow them, for every anchor and for none.
    private func sweep(
        _ body: (_ window: Range<Int>, _ count: Int, _ span: Int) -> Void
    ) {
        for span in SpaceBarStyle.glyphSpanRange {
            for count in (span + 2)...(span + 9) {
                let anchors = [nil] + (0..<count).map(Optional.some)
                for anchor in anchors {
                    let window = SpaceBarStrip.window(
                        count: count,
                        span: span,
                        anchor: anchor
                    )
                    body(window, count, span)
                }
            }
        }
    }

    /// The chip spends span + 2 cells whatever the anchor, so a
    /// focus change never changes its length (item 20): the
    /// glyphs drawn plus one cell per side that hides a group.
    @Test("an overflowing chip keeps one width")
    func fixedWidth() {
        sweep { window, count, span in
            let discs =
                (window.lowerBound > 0 ? 1 : 0)
                + (window.upperBound < count ? 1 : 0)
            #expect(
                window.count + discs == span + 2,
                "count \(count), span \(span), window \(window)"
            )
        }
    }

    /// A disc and a glyph take one cell each, so a side hiding a
    /// single group draws that group's glyph (#2052).
    @Test("a disc always hides two groups or more")
    func discHidesTwoOrMore() {
        sweep { window, count, span in
            let hiddenBefore = window.lowerBound
            let hiddenAfter = count - window.upperBound
            #expect(
                hiddenBefore != 1 && hiddenAfter != 1,
                "count \(count), span \(span), window \(window)"
            )
        }
    }

    /// Every window the row draws is one a held strip may keep.
    @Test("every drawn window is one a hold accepts")
    func drawnWindowsRoundTrip() {
        sweep { window, count, span in
            #expect(
                SpaceBarStrip.isWindow(window, count: count, span: span),
                "count \(count), span \(span), window \(window)"
            )
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
        // A side hiding one group is never drawn (#2052).
        #expect(!drawn(1..<6).holds(count: 9, span: 5))
        #expect(!drawn(3..<8).holds(count: 9, span: 5))
        #expect(!drawn(0..<6, of: 7).holds(count: 7, span: 5))
        #expect(drawn(0..<7, of: 7).holds(count: 7, span: 5))
        #expect(drawn(0..<4, of: 4).holds(count: 4, span: 5))
        // A row that gained or lost a group shifts every index:
        // even a shape it could draw is not the one held.
        #expect(!drawn(2..<7).holds(count: 10, span: 5))
        #expect(!drawn(2..<7, of: 10).holds(count: 9, span: 5))
        #expect(!drawn(2..<7, of: 7).holds(count: 7, span: 5))
    }

    /// The walk fixtures' span, and the cells its chip spends.
    private static let span = 5
    private static let cellCount = span + 2

    /// The walk between two strips, each held to be one the row
    /// draws, so a fixture edited to an undrawable shape reds
    /// rather than measuring a chip that cannot exist; each
    /// leading disc is derived from its window.
    private func walk(
        _ old: Range<Int>?,
        of oldCount: Int = 9,
        to new: Range<Int>,
        grownTo newCount: Int? = nil
    ) -> SpaceBarStrip.Walk? {
        let newCount = newCount ?? oldCount
        let strips = [old.map { ($0, oldCount) }, (new, newCount)]
        for case (let window, let count)? in strips {
            #expect(
                drawn(window, of: count)
                    .holds(count: count, span: Self.span),
                "fixture \(window) of \(count) is not drawable"
            )
        }
        return SpaceBarStrip.Walk.between(
            old.map { drawn($0, of: oldCount) },
            leadingDisc: (old?.lowerBound ?? 0) > 0,
            drawn(new, of: newCount),
            leadingDisc: new.lowerBound > 0
        )
    }

    @Test("a step through the middle walks one cell, one glyph each end")
    func middleStep() {
        #expect(
            walk(2..<7, of: 10, to: 3..<8)
                == .init(
                    cells: 1,
                    leavingFront: 1,
                    enteringBack: 1
                )
        )
        #expect(
            walk(3..<8, of: 10, to: 2..<7)
                == .init(
                    cells: -1,
                    leavingBack: 1,
                    enteringFront: 1
                )
        )
    }

    /// Leaving the row's start moves the window two groups while
    /// the kept glyphs travel one cell (#2052): the second glyph
    /// walks into the disc's cell, and the first, which would walk
    /// off the chip, fades in place under the disc instead.
    @Test("a disc appearing fades the glyph past the chip in place")
    func discAppears() throws {
        let step = try #require(walk(0..<6, to: 2..<7))
        let cells = Self.cellCount
        #expect(step == .init(cells: 1, leavingFront: 2, enteringBack: 1))
        // Carried off: groups 0 and 1, resting at cells -1 and 0.
        #expect(
            step.travel(resting: -1, cellCount: cells) == .init(from: 0, to: 0)
        )
        #expect(
            step.travel(resting: 0, cellCount: cells) == .init(from: 1, to: 0)
        )
        // Kept: group 2 walks from cell 2 to cell 1.
        #expect(
            step.travel(resting: 1, cellCount: cells) == .init(from: 2, to: 1)
        )
    }

    /// The mirror at the row's end: the last group, brought in
    /// two cells past the walk's one, fades in at its own cell.
    @Test("a disc leaving the end fades the glyph past it in place")
    func discLeavesTheEnd() throws {
        let step = try #require(walk(2..<7, to: 3..<9))
        let cells = Self.cellCount
        #expect(step == .init(cells: 1, leavingFront: 1, enteringBack: 2))
        #expect(
            step.travel(resting: 6, cellCount: cells) == .init(from: 6, to: 6)
        )
        #expect(
            step.travel(resting: 5, cellCount: cells) == .init(from: 6, to: 5)
        )
    }

    @Test("an unchanged or unknown strip plays no walk")
    func noWalk() {
        #expect(walk(2..<7, to: 2..<7) == nil)
        #expect(walk(nil, to: 2..<7) == nil)
    }

    /// A window opened or closed shifts every index, so the same
    /// numbers name other apps: nothing walks.
    @Test("a row that changed plays no walk")
    func changedRowNoWalk() {
        #expect(walk(2..<7, to: 3..<8, grownTo: 10) == nil)
    }

    /// A jump from one end to the other shares no glyph: walking
    /// it would slide glyphs across the neighbouring chips.
    @Test("a jump that shares no group plays no walk")
    func jumpNoWalk() {
        #expect(walk(0..<6, of: 14, to: 8..<14) == nil)
        // One shared group still walks.
        #expect(walk(0..<6, of: 14, to: 5..<10) != nil)
    }
}
