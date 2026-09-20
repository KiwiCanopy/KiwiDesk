import AppKit
import CoreText
import Testing

@testable import KiwiDeskCore

/// A text glyph stays whole and centred in a thin bar's cell
/// (#1529).
///
/// At thickness 20 the glyph cell is 12 pt and a label's
/// `cellSize` — advance plus ~8 pt of cell padding — exceeds it,
/// so `NSTextFieldCell` drew the string left-aligned and the
/// field clipped its trailing quarter. The width clauses pin the
/// one framing (`BarTextGlyph.frame`) on both call sites; the
/// render clauses pin the mechanism — the field's own render is
/// what clipped — and that the INK is centred, since centring
/// the advance drew a ligature a sixth of the cell to the left.
///
/// The display is the fixture's: every geometry here is the
/// strip handed to `sync` (#531), and the App Font is the
/// bundled one (`AppFontResourceTests`).
@Suite("Space Bar glyph cell at the thickness floor (#1529)")
@MainActor
struct SpaceBarGlyphCellTests {
    /// `AppBarStyle.minThickness`, the slider's floor (#1359).
    private static let depth: CGFloat = 20
    private static let cell: CGFloat = 12
    private static let glyph = ":safari:"

    init() { LiquidGlassGate.override = { false } }

    private static func icon() -> NSImage {
        NSImage(size: NSSize(width: 64, height: 64), flipped: false) {
            NSColor.black.setFill()
            $0.fill()
            return true
        }
    }

    private static func item(horizontal: Bool) -> SpaceBarItemView {
        let apps = [
            SpaceBarItemView.App(
                name: "Safari",
                icon: nil,
                glyph: glyph,
                focused: true,
                count: 1
            ),
            SpaceBarItemView.App(
                name: "Finder",
                icon: icon(),
                glyph: nil,
                focused: false,
                count: 1
            ),
        ]
        let length = SpaceBarItemView.autoLength(
            appCount: apps.count,
            depth: depth
        )
        let view = SpaceBarItemView(
            frame: horizontal
                ? CGRect(x: 0, y: 0, width: length, height: depth)
                : CGRect(x: 0, y: 0, width: depth, height: length)
        )
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: apps,
            active: true,
            horizontal: horizontal,
            style: SpaceBarStyle(),
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        return view
    }

    /// The columns of `field`'s own render that carry ink, in
    /// points from its frame's leading edge — the field clips to
    /// its frame, which is the mechanism under test.
    private static func inkSpan(
        of field: NSTextField
    ) -> ClosedRange<CGFloat>? {
        guard
            let rep = field.bitmapImageRepForCachingDisplay(
                in: field.bounds
            )
        else { return nil }
        field.cacheDisplay(in: field.bounds, to: rep)
        let scale = CGFloat(rep.pixelsWide) / field.bounds.width
        let inked = (0..<rep.pixelsWide).filter { x in
            (0..<rep.pixelsHigh).contains { y in
                (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
            }
        }
        guard let first = inked.first, let last = inked.last else {
            return nil
        }
        return (CGFloat(first) / scale)...(CGFloat(last + 1) / scale)
    }

    /// The glyph's ink width as the text system measures it.
    private static func inkWidth(of field: NSTextField) -> CGFloat {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: field.stringValue,
                attributes: [.font: field.font as Any]
            )
        )
        return CTLineGetImageBounds(line, nil).width
    }

    /// Whole: the rendered ink is as wide as the glyph; centred:
    /// its middle sits on the cell's, to the point the frame is
    /// rounded to.
    private static func expectWholeAndCentred(
        _ field: NSTextField,
        cellMid: CGFloat,
        axis: String
    ) throws {
        let span = try #require(Self.inkSpan(of: field))
        let ink = Self.inkWidth(of: field)
        #expect(
            span.upperBound - span.lowerBound >= ink - 1,
            "\(axis): \(span) of \(ink) pt drawn"
        )
        let mid = field.frame.minX + (span.lowerBound + span.upperBound) / 2
        #expect(
            abs(mid - cellMid) <= 1,
            "\(axis): ink mid \(mid) vs cell \(cellMid)"
        )
    }

    @Test("an App Font glyph is whole and centred on its cell, both axes")
    func itemGlyphIsWholeAndCentred() throws {
        for horizontal in [true, false] {
            let view = Self.item(horizontal: horizontal)
            let field = try #require(view.appViews[0] as? NSTextField)
            let axis = horizontal ? "horizontal" : "vertical"
            let width = ceil(field.cell?.cellSize.width ?? 0)
            #expect(width > Self.cell, "the fixture no longer overflows")
            #expect(field.frame.width >= width, "\(axis)")
            let cellMid: CGFloat
            if horizontal {
                // Identifier cell, pad, divider, pad, then the cell.
                let start =
                    SpaceBarItemView.pad + Self.cell
                    + SpaceBarItemView.pad + 1 + SpaceBarItemView.pad
                cellMid = start + Self.cell / 2
            } else {
                cellMid = Self.depth / 2
            }
            try Self.expectWholeAndCentred(
                field,
                cellMid: cellMid,
                axis: axis
            )
        }
    }

    @Test("an image glyph keeps the cell's own frame")
    func imageGlyphKeepsTheCell() throws {
        let view = Self.item(horizontal: false)
        let image = try #require(view.appViews[1] as? NSImageView)
        #expect(
            image.frame.size == CGSize(width: Self.cell, height: Self.cell)
        )
        #expect(image.frame.midX == Self.depth / 2)
    }

    @Test("the front-app glyph takes the same framing")
    func frontAppGlyphIsWholeAndCentred() throws {
        var style = SpaceBarStyle()
        style.thickness = Self.depth
        style.showFrontApp = true
        let bar = SpaceBarManager.Bar(
            display: barTitleDisplay,
            items: [
                SpaceBarOverlay.Item(
                    space: SpaceID("1"),
                    spaceGlyph: .text("1", tinted: true),
                    apps: [],
                    active: true,
                    overflow: 0,
                    focusInOverflow: false
                )
            ],
            frontApp: SpaceBarItemView.App(
                name: "Safari",
                icon: nil,
                glyph: Self.glyph,
                focused: true,
                count: 1
            ),
            frontWindow: WindowID(1),
            strip: CGRect(x: 0, y: 0, width: 1440, height: Self.depth),
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        let manager = SpaceBarManager()
        manager.sync([bar])
        let overlay = try #require(
            manager.overlayForTesting(barTitleDisplay)
        )
        let field = overlay.frontGlyph
        try #require(!field.isHidden, "the segment drew no glyph")
        let width = ceil(field.cell?.cellSize.width ?? 0)
        #expect(width > Self.cell, "the fixture no longer overflows")
        #expect(field.frame.width >= width)
        let span = try #require(Self.inkSpan(of: field))
        #expect(
            span.upperBound - span.lowerBound
                >= Self.inkWidth(of: field) - 1,
            "\(span) drawn"
        )
        // The cell is centred across the strip's depth; the ink's
        // centring along the bar is the helper's, pinned above.
        #expect(abs(field.frame.midY - Self.depth / 2) <= 0.5)
    }
}
