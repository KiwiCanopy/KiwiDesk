import AppKit
import Testing

@testable import KiwiDeskCore

/// The App Bar anchors a glyph's INK, not its advance (#1543).
///
/// A sketchybar ligature carries its slack on the trailing side,
/// so centring the advance drew every glyph a sixth of the slot
/// to the left, and the snug-to-name anchor left that slack
/// between glyph and name. Both anchors now place the ink —
/// through the one `BarTextGlyph.metrics` the Space Bar's
/// framing reads (#1529) — and both clauses render the label to
/// find where the ink landed, since a frame clause cannot tell
/// the two anchors apart.
///
/// `@MainActor` for the views it renders to bitmaps, walked
/// pixel by pixel. The geometry is the fixture's frame; the font
/// is the bundled App Font, required per test.
@Suite("App Bar glyph ink anchoring (#1543)")
@MainActor
struct AppBarGlyphInkTests {
    private static let glyph = ":safari:"

    private static func item(
        thickness: CGFloat,
        horizontal: Bool,
        text: String = "Safari"
    ) -> AppBarItemView {
        let view = AppBarItemView(
            frame: horizontal
                ? NSRect(x: 0, y: 0, width: 160, height: thickness)
                : NSRect(x: 0, y: 0, width: thickness, height: 160)
        )
        view.configure(
            id: WindowID(1),
            text: text,
            icon: nil,
            glyph: glyph,
            count: 1,
            active: false,
            horizontal: horizontal,
            style: AppBarStyle()
        )
        view.layout()
        return view
    }

    /// The columns of `field`'s own render that carry ink, in
    /// points from its frame's leading edge.
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

    private static func inkRange(
        of field: NSTextField
    ) throws -> ClosedRange<CGFloat> {
        try #require(field.font?.fontName == AppFont.fontName)
        let span = try #require(inkSpan(of: field))
        let start = field.frame.minX + span.lowerBound
        let end = field.frame.minX + span.upperBound
        return start...end
    }

    @Test(
        "an icon-only glyph's ink is centred on the slot",
        arguments: [20.0, 32.0, 48.0]
    )
    func iconOnlyInkIsCentred(thickness: CGFloat) throws {
        let view = Self.item(thickness: thickness, horizontal: false)
        try #require(view.label.isHidden)
        let ink = try Self.inkRange(of: view.glyphLabel)
        // The vertical slot is centred across the bar's width.
        let mid = (ink.lowerBound + ink.upperBound) / 2
        #expect(
            abs(mid - thickness / 2) <= 1,
            "ink mid \(mid) vs slot \(thickness / 2)"
        )
    }

    /// From 32 up: at 24 the pre-fix clamp lands the advance's
    /// frame within a rounding of the same place, so a thinner
    /// argument would be blind to the regression (guard-prover).
    @Test(
        "a named glyph's ink snugs to the name",
        arguments: [32.0, 48.0]
    )
    func namedInkSnugsToTheName(thickness: CGFloat) throws {
        let view = Self.item(thickness: thickness, horizontal: true)
        try #require(!view.label.isHidden)
        let ink = try Self.inkRange(of: view.glyphLabel)
        // The slot's trailing edge sits one icon-name gap before
        // the label, and the ink's trailing edge sits on it.
        let slotEnd =
            view.label.frame.minX - AppBarItemView.contentPadding / 2
        #expect(
            abs(ink.upperBound - slotEnd) <= 1,
            "ink ends \(ink.upperBound) vs slot \(slotEnd)"
        )
    }
}
