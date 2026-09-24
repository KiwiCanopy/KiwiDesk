import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// A bar's natural length is what its own render draws (#1517):
/// handed a segment exactly that long, the run fits without an
/// arrow and its plate reaches the segment's GUTTER-side end —
/// the side facing the other bar — so no slack widens the gutter.
/// `naturalLength` restates the render's padding, so this is
/// where the two are held together. The Space run keeps a `pad`
/// at its outer end, so below `item_gap == pad` its gutter side
/// may sit `pad − gap` in; that is the whole allowed slack.
@Suite("Shelf need parity (#1517)")
@MainActor
struct ShelfNeedParityTests {
    private let depth: CGFloat = 40

    nonisolated private static let placements:
        [(KiwiShelf.Alignment, CGFloat)] =
            [(.start, 2), (.start, 6), (.end, 2), (.end, 6)]

    @Test(
        "the Space run fills its natural segment",
        arguments: ShelfNeedParityTests.placements
    )
    func spaceRunFits(alignment: KiwiShelf.Alignment, gap: CGFloat) {
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
        let slack =
            alignment == .start ? need - plate.maxX : plate.minX
        #expect(slack >= 0)
        #expect(slack <= max(SpaceBarItemView.pad - gap, 0))
    }

    @Test(
        "the App run fills its natural segment",
        arguments: ShelfNeedParityTests.placements
    )
    func appRunFits(alignment: KiwiShelf.Alignment, gap: CGFloat) {
        var style = AppBarLook()
        style.itemGap = gap
        style.alignment = alignment
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
        let frames = AppBarOverlay.frames(
            lengths: Array(repeating: metrics.slot, count: items.count),
            in: strip,
            gap: gap,
            horizontal: true,
            alignment: alignment
        )
        let runStart = frames.first?.minX ?? 0
        let plate = BarPlate.frame(
            strip: strip,
            runStart: runStart,
            runTotal: metrics.total,
            inset: 0,
            gap: gap,
            horizontal: true,
            fit: .hug
        )
        let slack =
            alignment == .start ? need - plate.maxX : plate.minX
        #expect(slack == 0)
    }
}
