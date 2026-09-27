import AppKit

/// A badge's text cell: its line set on the one bar baseline,
/// the font's caps centred on the disc (#1707).
final class IndicatorBarBadgeCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        guard let font else { return titleRect }
        titleRect.origin.y = BarTextGlyph.lineTop(
            capsCentredOn: rect.midY,
            font: font
        )
        titleRect.size.height = cellSize(forBounds: rect).height
        return titleRect
    }

    override func drawInterior(
        withFrame cellFrame: NSRect,
        in controlView: NSView
    ) {
        super.drawInterior(
            withFrame: titleRect(forBounds: cellFrame),
            in: controlView
        )
    }
}
