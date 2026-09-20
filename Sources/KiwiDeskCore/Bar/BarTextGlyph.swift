import AppKit
import CoreText

/// Where the Space Bar frames a text glyph — an App Font ligature,
/// a Space's digits or monogram — inside its square cell (#1529).
/// The three fields on `SpaceBarStyle.glyphFontSize`'s one ladder
/// take it; the App Bar's slot frames its own (`AppBarItemView+
/// GlyphSlot`, converging under #1543).
enum BarTextGlyph {
    /// The frame for `field` whose ink is centred on `cell`, its
    /// font scaled down where the ink would reach past the cell
    /// by more than `slack` on a side — 0 for an app glyph, whose
    /// neighbour abuts; the item's pad for the identifier, which
    /// keeps the ladder's size at the cost of reaching into it.
    /// Unaligned: the site rounds once, to its backing.
    ///
    /// The frame takes the label's own `cellSize` width, because
    /// `NSTextFieldCell` draws a string wider than its frame
    /// LEFT-aligned whatever `alignment` says, and that size
    /// carries ~8 pt of padding around the advance — wider than
    /// a thin bar's cell for every glyph. The ink is centred
    /// rather than the advance, since the cell's neighbours are
    /// image cells whose pixels centre; a ligature's slack sits
    /// on its trailing side.
    static func frame(
        for field: NSTextField,
        in cell: CGRect,
        slack: CGFloat = 0
    ) -> CGRect {
        fit(field, toWidth: cell.width + slack * 2)
        let size = field.cell?.cellSize ?? .zero
        var rect = cell
        let width = ceil(size.width)
        if width > rect.width {
            rect.origin.x -= (width - rect.width) / 2
            rect.size.width = width
        }
        rect.origin.x -= inkOffset(of: field)
        let height = ceil(size.height)
        if height > 0, height < rect.height {
            rect.origin.y += (rect.height - height) / 2
            rect.size.height = height
        }
        return rect
    }

    /// Scales the font down until the ink fits `width`: a few of
    /// the bundled ligatures overshoot their em, and along the
    /// bar an app cell abuts its neighbour. Converted rather than
    /// re-minted, so the system font stays the system font, and
    /// re-measured once, since its tracking is not linear in size.
    private static func fit(
        _ field: NSTextField,
        toWidth width: CGFloat
    ) {
        guard let font = field.font, width > 0 else { return }
        var fitted = font
        var ink = inkBounds(field.stringValue, font: fitted).width
        guard ink > width else { return }
        for _ in 0..<2 where ink > width {
            fitted = NSFontManager.shared.convert(
                fitted,
                toSize: fitted.pointSize * width / ink
            )
            ink = inkBounds(field.stringValue, font: fitted).width
        }
        field.font = fitted
    }

    /// How far the ink's centre sits from the advance's, which is
    /// what the cell's alignment centres.
    private static func inkOffset(of field: NSTextField) -> CGFloat {
        guard let font = field.font else { return 0 }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: field.stringValue,
                attributes: [.font: font]
            )
        )
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ink = CTLineGetImageBounds(line, nil)
        guard advance > 0, !ink.isNull, ink.width > 0 else { return 0 }
        return ink.midX - advance / 2
    }

    /// The glyph's ink, relative to the line origin.
    static func inkBounds(_ text: String, font: NSFont) -> CGRect {
        guard !text.isEmpty else { return .null }
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: text,
                attributes: [.font: font]
            )
        )
        return CTLineGetImageBounds(line, nil)
    }
}
