import AppKit
import CoreText

/// Where a bar places a text glyph — an App Font ligature, a
/// Space's digits or monogram — by its INK (#1529, #1543). The
/// Space Bar's three fields on `SpaceBarStyle.glyphFontSize`'s one
/// ladder take `frame`; the App Bar's slot keeps its own
/// font-scaling and snug rulings (`AppBarItemView+GlyphSlot`) and
/// anchors through `Metrics`.
enum BarTextGlyph {
    /// A string as the text system lays it: the advance the
    /// cell's alignment centres, and the ink relative to the line
    /// origin — a ligature carries its slack on the trailing
    /// side, so the two centres differ. The placements live here
    /// so no site derives "where the frame goes so the ink lands"
    /// a second way.
    struct Metrics {
        let advance: CGFloat
        let ink: CGRect

        /// Where the ink's leading edge sits inside a frame of
        /// `width` whose alignment centres the advance.
        func inkLead(inFrameOfWidth width: CGFloat) -> CGFloat {
            width / 2 - advance / 2 + ink.minX
        }

        /// The frame origin that centres the ink on `mid`.
        func originX(
            centringInkOn mid: CGFloat,
            frameWidth width: CGFloat
        ) -> CGFloat {
            mid - inkLead(inFrameOfWidth: width) - ink.width / 2
        }

        /// The frame origin that ends the ink at `trailing`.
        func originX(
            inkTrailingAt trailing: CGFloat,
            frameWidth width: CGFloat
        ) -> CGFloat {
            trailing - inkLead(inFrameOfWidth: width) - ink.width
        }

        /// The ink's span along the bar for a frame at `frame`.
        func inkSpan(in frame: CGRect) -> ClosedRange<CGFloat> {
            let lead = frame.minX + inkLead(inFrameOfWidth: frame.width)
            return lead...(lead + ink.width)
        }
    }

    /// Total: an ink-less string reads as ink the width of its
    /// advance, so every placement degrades to the advance's.
    static func metrics(_ text: String, font: NSFont) -> Metrics {
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(
                string: text,
                attributes: [.font: font]
            )
        )
        let advance = CTLineGetTypographicBounds(line, nil, nil, nil)
        let ink = CTLineGetImageBounds(line, nil)
        guard advance > 0, !ink.isNull, ink.width > 0 else {
            return Metrics(
                advance: advance,
                ink: CGRect(x: 0, y: 0, width: advance, height: 0)
            )
        }
        return Metrics(advance: advance, ink: ink)
    }

    static func metrics(of field: NSTextField) -> Metrics {
        metrics(
            field.stringValue,
            font: field.font ?? .systemFont(ofSize: NSFont.systemFontSize)
        )
    }

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
    /// image cells whose pixels centre.
    static func frame(
        for field: NSTextField,
        in cell: CGRect,
        slack: CGFloat = 0
    ) -> CGRect {
        fit(field, toWidth: cell.width + slack * 2)
        let size = field.cell?.cellSize ?? .zero
        var rect = cell
        rect.size.width = max(cell.width, ceil(size.width))
        rect.origin.x = metrics(of: field).originX(
            centringInkOn: cell.midX,
            frameWidth: rect.width
        )
        let height = ceil(size.height)
        if height > 0, height < rect.height {
            rect.origin.y += (rect.height - height) / 2
            rect.size.height = height
        }
        return rect
    }

    /// Scales the font down until the ink fits `width`: a few of
    /// the bundled ligatures overshoot their em, and along the
    /// bar an app cell abuts its neighbour. Converted through the
    /// font manager, which keeps the face, and re-measured once,
    /// since the system font's tracking is not linear in size.
    private static func fit(
        _ field: NSTextField,
        toWidth width: CGFloat
    ) {
        guard let font = field.font, width > 0 else { return }
        var fitted = font
        var ink = metrics(field.stringValue, font: fitted).ink.width
        guard ink > width else { return }
        for _ in 0..<2 where ink > width {
            fitted = NSFontManager.shared.convert(
                fitted,
                toSize: fitted.pointSize * width / ink
            )
            ink = metrics(field.stringValue, font: fitted).ink.width
        }
        field.font = fitted
    }
}
