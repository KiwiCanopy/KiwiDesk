import AppKit
import CoreText

/// Where a bar's text glyph — an App Font ligature, a Space's
/// digits or monogram — is framed inside its square cell (#1529).
enum BarTextGlyph {
    /// The frame for `field` whose ink is centred on `cell`.
    ///
    /// A label's `cellSize` carries ~8 pt of cell padding around
    /// the advance, so it exceeds a thin bar's cell for every
    /// glyph, and `NSTextFieldCell` draws a string wider than its
    /// frame LEFT-aligned whatever `alignment` says — at a 12 pt
    /// cell the ink ran past the trailing edge and the field
    /// clipped it. The frame takes the label's own width, centred
    /// on the cell, so the alignment holds; the ink stays inside
    /// the cell because the glyph ladder bounds it
    /// (`SpaceBarStyle.glyphFontSize`).
    static func frame(
        for field: NSTextField,
        in cell: CGRect
    ) -> CGRect {
        let size = field.cell?.cellSize ?? .zero
        var rect = cell
        let width = ceil(size.width)
        if width > rect.width {
            rect.origin.x -= ((width - rect.width) / 2).rounded()
            rect.size.width = width
        }
        rect.origin.x -= inkOffset(of: field)
        let height = ceil(size.height)
        if height > 0, height < rect.height {
            rect.origin.y += ((rect.height - height) / 2).rounded()
            rect.size.height = height
        }
        return rect
    }

    /// How far the ink's centre sits from the advance's, which is
    /// what the cell centres: an App Font ligature carries its
    /// slack on the trailing side, so centring the advance drew
    /// the glyph a sixth of the cell to the left.
    private static func inkOffset(of field: NSTextField) -> CGFloat {
        guard let font = field.font, !field.stringValue.isEmpty
        else { return 0 }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: field.stringValue,
                attributes: [.font: font]
            )
        )
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ink = CTLineGetImageBounds(line, nil)
        guard advance > 0, !ink.isNull, ink.width > 0 else { return 0 }
        return (ink.midX - advance / 2).rounded()
    }
}
