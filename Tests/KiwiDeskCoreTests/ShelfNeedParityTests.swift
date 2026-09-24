import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A bar's natural length is what its own render draws (#1517):
/// handed a segment exactly that long, the run fits without an
/// arrow and its plate reaches the segment's far end — no scroll,
/// no slack beside the gutter. `naturalLength` restates the
/// render's padding, so this is where the two are held together.
@Suite("Shelf need parity (#1517)")
@MainActor
struct ShelfNeedParityTests {
    private let depth: CGFloat = 40
    private let gap: CGFloat = 6

    @Test(
        "the Space run fills its natural segment exactly",
        arguments: [KiwiShelf.Alignment.start, .end]
    )
    func spaceRunFits(alignment: KiwiShelf.Alignment) {
        let layer = SpaceBarOverlay.Item(
            layer: "L",
            glyph: .text("L", tinted: false)
        )
        let items =
            [layer]
            + (1...3).map {
                SpaceBarOverlay.Item(
                    space: SpaceID("\($0)"),
                    spaceGlyph: .text("\($0)", tinted: false),
                    apps: [],
                    active: $0 == 1,
                    overflow: 0,
                    focusInOverflow: false
                )
            }
        let need = SpaceBarOverlay.naturalLength(
            items: items,
            depth: depth,
            gap: gap
        )
        let lengths = SpaceBarOverlay.itemLengths(
            items,
            depth: depth,
            gap: gap
        )
        let total = SpaceBarOverlay.runTotal(
            lengths: lengths,
            gap: gap,
            frontExtent: 0
        )
        let (inset, _) = SpaceBarOverlay.scrollViewport(
            axis: need,
            total: total,
            gap: gap
        )
        #expect(inset == 0)
        let start = SpaceBarOverlay.contentStart(
            total: total,
            axis: need,
            alignment: alignment,
            pad: SpaceBarItemView.pad
        )
        let plate = BarPlate.frame(
            strip: CGRect(x: 0, y: 0, width: need, height: depth),
            runStart: start,
            runTotal: total,
            inset: 0,
            gap: gap,
            horizontal: true,
            fit: .hug
        )
        #expect(plate.minX == 0)
        #expect(plate.maxX == need)
    }

    @Test("the App run fills its natural segment exactly")
    func appRunFits() {
        var style = AppBarLook()
        style.itemGap = gap
        let items = ["Mail", "A much longer window title", "Notes"]
            .enumerated().map {
                AppBarOverlay.Item(
                    id: WindowID(UInt32($0.offset + 1)),
                    text: $0.element,
                    icon: nil
                )
            }
        let need = AppBarOverlay.naturalLength(
            items: items,
            style: style,
            thickness: depth,
            capAxis: 2000
        )
        let strip = CGRect(x: 0, y: 0, width: need, height: depth)
        let metrics = AppBarOverlay().metrics(
            strip: strip,
            count: items.count,
            style: style,
            items: items,
            capAxis: 2000
        )
        #expect(metrics.inset == 0)
        let plate = BarPlate.frame(
            strip: strip,
            runStart: 0,
            runTotal: metrics.total,
            inset: 0,
            gap: gap,
            horizontal: true,
            fit: .hug
        )
        #expect(plate.maxX == need)
    }
}
