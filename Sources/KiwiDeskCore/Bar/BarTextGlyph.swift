import AppKit
import CoreText

/// Where bar text goes: along the bar a text glyph — an App Font
/// ligature, a Space's digits or monogram — is placed by its INK
/// (#1529, #1543); across it every bar text sits on one baseline
/// per font, its cap height — a numeral's figures — centred
/// (#1707). The Space Bar's fields on
/// `SpaceBarStyle.glyphFontSize`'s one ladder take `frame`;
/// free-running text (a title, a count) takes `originY` and a
/// badge cell `lineTop`; the App Bar's slot keeps its own
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

        /// The frame origin that starts the ink at `leading`.
        func originX(
            inkLeadingAt leading: CGFloat,
            frameWidth width: CGFloat
        ) -> CGFloat {
            leading - inkLead(inFrameOfWidth: width)
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

    @MainActor
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
    /// image cells whose pixels centre. Vertically an App Font
    /// ligature centres its line box and text sets its baseline
    /// through `originY(centredOn:for:band:height:)`.
    @MainActor
    static func frame(
        for field: NSTextField,
        in cell: CGRect,
        band: Band,
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
        guard height > 0 else { return rect }
        rect.size.height = height
        rect.origin.y =
            AppFont.isAppFont(field.font)
            ? cell.midY - height / 2
            : originY(
                centredOn: cell.midY,
                for: field,
                band: band,
                height: height
            )
        return rect
    }

    /// The frame origin's y for `field` laid out `height` tall
    /// in a FLIPPED host (every bar view is): its baseline sits
    /// where `lineTop(centredOn:band:font:)` puts it. The frame
    /// may pass the cell.
    @MainActor
    static func originY(
        centredOn mid: CGFloat,
        for field: NSTextField,
        band: Band,
        height: CGFloat
    ) -> CGFloat {
        guard let font = field.font, let cell = field.cell else {
            return mid - height / 2
        }
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: max(ceil(cell.cellSize.width), 1),
            height: height
        )
        return lineTop(
            centredOn: mid,
            band: band,
            font: font
        ) - cell.titleRect(forBounds: bounds).minY
    }

    /// The span above the baseline a line centres, named by the
    /// SITE's role and never read off the string, so a "3" and a
    /// "+3" badge share a line.
    enum Band {
        /// The cap height: titles, names, a lettered identifier.
        case caps
        /// The ink of the font's ten digits: counts and numbered
        /// identifiers — an old-style face's figures sit below its
        /// caps' middle, so a numeral centred by its caps reads low.
        case figures

        /// A Space identifier's band: figures for a numeral, caps
        /// for anything carrying a letter or symbol.
        static func of(identifier text: String) -> Band {
            !text.isEmpty && text.allSatisfy(\.isNumber)
                ? .figures : .caps
        }
    }

    /// Where a line of `font` starts, flipped, so its baseline
    /// centres `band` on `mid`: one baseline per font and band
    /// whatever a string's own ink, so an old-style 3 and a 1 line
    /// up and a tall face's ascent does not lift it (#1707).
    @MainActor
    static func lineTop(
        centredOn mid: CGFloat,
        band: Band,
        font: NSFont
    ) -> CGFloat {
        let span = span(of: band, font: font)
        return mid + (span.lowerBound + span.upperBound) / 2
            - layout.defaultBaselineOffset(for: font)
    }

    /// `band`'s span above the baseline in `font`; a face with no
    /// digit ink centres its caps. Memoized per font, since a
    /// badge cell asks on every draw.
    @MainActor
    static func span(of band: Band, font: NSFont) -> ClosedRange<CGFloat> {
        let caps = 0...font.capHeight
        guard band == .figures else { return caps }
        if let known = figureSpans[font] { return known }
        let ink = metrics("0123456789", font: font).ink
        let span = ink.height > 0 ? ink.minY...ink.maxY : caps
        if figureSpans.count > 64 { figureSpans.removeAll() }
        figureSpans[font] = span
        return span
    }

    @MainActor private static var figureSpans: [NSFont: ClosedRange<CGFloat>] =
        [:]

    @MainActor private static let layout = NSLayoutManager()

    /// Scales the font down until the ink fits `width`: a few of
    /// the bundled ligatures overshoot their em, and along the
    /// bar an app cell abuts its neighbour. Converted through the
    /// font manager, which keeps the face, and re-measured once,
    /// since the system font's tracking is not linear in size.
    @MainActor
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
