import AppKit
import Testing

@testable import KiwiDeskCore

/// The shelf's font family (#1681) against the one framing: a
/// tall face (Zapfino, whose ascenders dwarf its em) and a mono
/// face (Menlo) still draw the identifier whole, ink-centred
/// along the bar and on the one baseline across it (#1707).
extension SpaceBarGlyphCellTests {
    /// The rows of `field`'s own render that carry ink, in points
    /// from its frame's bottom edge.
    static func inkRows(
        of field: NSTextField
    ) -> ClosedRange<CGFloat>? {
        guard
            let rep = field.bitmapImageRepForCachingDisplay(
                in: field.bounds
            )
        else { return nil }
        field.cacheDisplay(in: field.bounds, to: rep)
        let scale = CGFloat(rep.pixelsHigh) / field.bounds.height
        let inked = (0..<rep.pixelsHigh).filter { y in
            (0..<rep.pixelsWide).contains { x in
                (rep.colorAt(x: x, y: y)?.alphaComponent ?? 0) > 0.05
            }
        }
        guard let first = inked.first, let last = inked.last else {
            return nil
        }
        return (CGFloat(first) / scale)...(CGFloat(last + 1) / scale)
    }

    @Test(
        "an identifier in another face is whole and ink-centred",
        arguments: ["Zapfino", "Menlo"]
    )
    func identifierInFaceIsWholeAndCentred(family: String) throws {
        try #require(BarFont.isInstalled(family), "\(family) missing")
        var style = Self.style
        style.fontFamily = family
        let view = Self.item(horizontal: true)
        view.configure(
            identity: .space(SpaceID("1")),
            spaceGlyph: .text("1", tinted: true),
            apps: [],
            active: true,
            horizontal: true,
            style: style,
            stateMarkColors: StateMarkColors(
                sticky: "#ffffff",
                floating: "#ffffff"
            )
        )
        view.layout()
        let field = view.identifierLabel
        let font = try #require(field.font)
        #expect(font.familyName == family)
        let span = try #require(Self.inkSpan(of: field))
        #expect(
            span.lowerBound > 0 && span.upperBound < field.bounds.width,
            "\(family): ink \(span) touches the field's side"
        )
        let rows = try #require(Self.inkRows(of: field))
        #expect(
            rows.lowerBound > 0 && rows.upperBound < field.bounds.height,
            "\(family): ink \(rows) clipped top or bottom"
        )
        let mid =
            field.frame.minX + (span.lowerBound + span.upperBound) / 2
        let cellMid =
            SpaceBarItemView.pad + view.ends.leading + Self.cell / 2
        #expect(
            abs(mid - cellMid) <= 1,
            "\(family): ink mid \(mid) vs cell \(cellMid)"
        )
    }
}
