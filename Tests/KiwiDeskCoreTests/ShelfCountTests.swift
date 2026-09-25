import AppKit
import Testing

@testable import KiwiDeskCore

/// Overflow shows as fades and counts, never arrows (#1517).
@Suite("Shelf counts and fades")
@MainActor
struct ShelfCountTests {
    init() { LiquidGlassGate.override = { false } }

    @Test("A count keeps its chevron, pointing where the entries are")
    func countGlyph() {
        let cases: [(ShelfCountView.Side, Bool, String)] = [
            (.before, true, "chevron.left"),
            (.after, true, "chevron.right"),
            (.before, false, "chevron.up"),
            (.after, false, "chevron.down"),
        ]
        for (side, horizontal, symbol) in cases {
            #expect(
                ShelfCountView.symbol(side: side, horizontal: horizontal)
                    == symbol
            )
            #expect(
                NSImage(
                    systemSymbolName: symbol,
                    accessibilityDescription: nil
                ) != nil
            )
        }
    }

    /// A count configured and placed on a shelf `depth` deep, as
    /// the sections place it.
    private func placed(
        _ side: ShelfCountView.Side,
        horizontal: Bool,
        depth: CGFloat = 24
    ) throws -> (view: ShelfCountView, number: CGRect, chevron: CGRect) {
        let view = ShelfCountView(side: side)
        view.configure(
            count: 12,
            horizontal: horizontal,
            fontSize: 14,
            ink: .white,
            hoverInk: .red
        )
        let container =
            horizontal
            ? CGRect(x: 0, y: 0, width: 300, height: depth)
            : CGRect(x: 0, y: 0, width: depth, height: 300)
        view.place(in: container, atEnd: side == .after)
        view.layout()
        let label = try #require(
            view.subviews.first { $0 is NSTextField } as? NSTextField
        )
        // The digits, not the label's padded cell.
        let digits = label.attributedStringValue.size()
        let number = CGRect(
            x: label.frame.midX - digits.width / 2,
            y: label.frame.midY - digits.height / 2,
            width: digits.width,
            height: digits.height
        )
        let chevron = try #require(
            view.subviews.first { $0 is NSImageView }
        ).frame
        return (view, number, chevron)
    }

    /// Owner 2026-09-25: stacked, number on top, on a horizontal
    /// shelf; side by side, number first, on a vertical one — and
    /// either fits a 24 pt shelf.
    @Test("The count stacks on a horizontal shelf, sits beside on a vertical")
    func countArrangement() throws {
        for side in [ShelfCountView.Side.before, .after] {
            let row = try placed(side, horizontal: true)
            #expect(row.view.stacks)
            #expect(
                row.chevron.minY
                    >= row.number.maxY + ShelfCountView.stackGap - 0.5
            )
            #expect(row.view.bounds.contains(row.chevron))
            #expect(row.number.minY >= 0)
            #expect(
                row.view.drawnSymbol
                    == ShelfCountView.symbol(side: side, horizontal: true)
            )
            let column = try placed(side, horizontal: false)
            #expect(!column.view.stacks)
            #expect(
                column.chevron.minX
                    >= column.number.maxX + ShelfCountView.sideGap - 0.5
            )
            #expect(column.view.bounds.contains(column.chevron))
            #expect(column.number.minX >= 0)
            #expect(
                column.view.drawnSymbol
                    == ShelfCountView.symbol(side: side, horizontal: false)
            )
        }
    }

    /// The pointer over a count takes the item hover ink.
    @Test("A hovered count takes the hover ink")
    func countHover() throws {
        let count = try placed(.after, horizontal: true).view
        let label = try #require(
            count.subviews.first { $0 is NSTextField } as? NSTextField
        )
        #expect(label.textColor == .white)
        count.setHovered(true)
        #expect(label.textColor == .red)
        count.setHovered(false)
        #expect(label.textColor == .white)
    }

    @Test("A count is a button that pages, and hides at zero")
    func countIsAButton() {
        let view = ShelfCountView(side: .after)
        var paged = 0
        view.onPage = { paged += 1 }
        view.configure(
            count: 4,
            horizontal: true,
            fontSize: 12,
            ink: .white,
            hoverInk: .white
        )
        #expect(!view.isHidden)
        #expect(view.accessibilityRole() == .button)
        #expect(view.accessibilityLabel()?.contains("4") == true)
        #expect(view.accessibilityPerformPress())
        #expect(paged == 1)
        view.configure(
            count: 0,
            horizontal: true,
            fontSize: 12,
            ink: .white,
            hoverInk: .white
        )
        #expect(view.isHidden)
    }

    @Test("The mask is clear at a hidden end and opaque in between")
    func maskStops() {
        #expect(
            ShelfFadeMask.stops(leading: 0, trailing: 50, length: 200)
                == [0, 0, 0.75, 1]
        )
        // A fade never passes the middle.
        #expect(
            ShelfFadeMask.stops(leading: 300, trailing: 300, length: 200)
                == [0, 0.5, 0.5, 1]
        )
    }

    /// The live bar: sixty Spaces overflow the fixture strip, so
    /// the trailing end fades, counts, and no drop target reaches
    /// into it.
    @Test("An overflowing Space Bar fades and counts its hidden end")
    func spaceBarFadesAndCounts() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        #expect(overlay.itemContainer.layer?.mask != nil)
        #expect(overlay.backCount.isHidden)
        #expect(!overlay.forwardCount.isHidden)
        let clear = try #require(overlay.scrollGeom).fades
        #expect(clear.trailing > 0 && clear.after > 0)
        let edge = overlay.itemContainer.frame.maxX - clear.trailing
        for (_, frame) in overlay.hitFrames {
            #expect(frame.maxX <= edge + 0.5)
        }
        // Few enough Spaces to fit: no mask, no counts.
        manager.sync([paintedSpaceBar(front: nil, spaces: 3)])
        #expect(overlay.itemContainer.layer?.mask == nil)
        #expect(overlay.forwardCount.isHidden)
    }
}

/// Drop targets keep their places when the leading end fades: an
/// item's hit frame is offset by the viewport, and only cut at
/// the fade (#1517 review blocker).
@Suite("Shelf drop targets under a fade")
@MainActor
struct ShelfDropTargetTests {
    init() { LiquidGlassGate.override = { false } }

    @Test("A scrolled Space Bar's drop targets sit on their items")
    func hitFramesStayOnTheirItems() throws {
        let manager = SpaceBarManager()
        manager.sync([paintedSpaceBar(front: nil, spaces: 60)])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        overlay.scrollOffset = 400
        overlay.render(followingActive: false)
        let fades = try #require(overlay.scrollGeom).fades
        try #require(fades.leading > 0, "nothing hidden at the start")
        let viewport = overlay.itemContainer.frame
        for (index, item) in overlay.itemViews.enumerated() {
            guard let space = SpaceID("\(index + 1)") as SpaceID?,
                let hit = overlay.hitFrames.first(where: {
                    $0.space == space
                })
            else { continue }
            let drawn = item.frame.offsetBy(
                dx: viewport.minX,
                dy: viewport.minY
            )
            #expect(
                drawn.contains(CGPoint(x: hit.frame.midX, y: hit.frame.midY)),
                Comment(
                    rawValue: "Space \(index + 1): \(hit.frame) vs \(drawn)"
                )
            )
        }
    }
}
