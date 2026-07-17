import AppKit

/// A text field cell that centers its text vertically.
final class IndicatorBarBadgeCell: NSTextFieldCell {
    override func titleRect(forBounds rect: NSRect) -> NSRect {
        var titleRect = super.titleRect(forBounds: rect)
        let minimumHeight = cellSize(forBounds: rect).height
        if titleRect.size.height > minimumHeight {
            titleRect.origin.y +=
                (titleRect.size.height - minimumHeight) / 2
            titleRect.size.height = minimumHeight
        }
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
