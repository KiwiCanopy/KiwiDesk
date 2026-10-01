import AppKit

/// A badge's text cell: its line set on the one bar baseline,
/// a count's figures centred on the disc (#1707).
final class IndicatorBarBadgeCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        guard let font else { return titleRect }
        titleRect.origin.y = BarTextGlyph.lineTop(
            centredOn: rect.midY,
            band: .figures,
            font: font
        )
        titleRect.size.height = cellSize(forBounds: rect).height
        return titleRect
    }

    /// Draws the line itself: whether AppKit's own interior draw
    /// asks `titleRect` again differs by macOS release, and a
    /// second pass would move the line off the disc (#1707).
    override func drawInterior(
        withFrame cellFrame: NSRect,
        in controlView: NSView
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = alignment
        paragraph.lineBreakMode = .byClipping
        var attributes: [NSAttributedString.Key: Any] = [
            .paragraphStyle: paragraph
        ]
        if let font { attributes[.font] = font }
        if let color = (controlView as? NSTextField)?.textColor {
            attributes[.foregroundColor] = color
        }
        (stringValue as NSString).draw(
            with: titleRect(forBounds: cellFrame),
            options: [.usesLineFragmentOrigin],
            attributes: attributes
        )
    }
}
