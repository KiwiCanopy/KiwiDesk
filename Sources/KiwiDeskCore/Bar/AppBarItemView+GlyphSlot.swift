import AppKit

/// App Bar item icon slot and font glyph layout (`AppBarItemView`, #294).
extension AppBarItemView {
    /// True when neither image icon nor font glyph is visible (#294).
    var iconSlotHidden: Bool {
        iconView.isHidden && glyphLabel.isHidden
    }

    /// Positions app icon image or App Font glyph within the slot square.
    func layoutIconSlot(in square: CGRect) {
        if glyphLabel.isHidden {
            iconView.frame = square
            return
        }
        // The glyph's working box grows past the image square —
        // the font's glyphs carry internal margins, so the
        // padded square reads undersized. Horizontal: grow
        // vertically plus toward the text by exactly the
        // icon-name gap (pad/2), leading edge pinned, so the
        // glyph can neither reach the item border nor overlap
        // the label. Vertical: grow along the bar axis only —
        // the sides stay pinned so a wide ligature never
        // touches the item's side borders.
        let pad = Self.contentPadding
        let box =
            horizontal
            ? CGRect(
                x: square.minX,
                y: square.minY - pad,
                width: square.width + pad / 2,
                height: square.height + pad * 2
            )
            : square.insetBy(dx: 0, dy: -pad)
        var size = box.height * AppBarStyle.glyphSlotRatio
        glyphLabel.font =
            AppFont.font(size: size)
            ?? .systemFont(ofSize: size)
        var cell = glyphLabel.cell?.cellSize ?? .zero
        if cell.width > box.width, cell.width > 0 {
            size *= box.width / cell.width
            glyphLabel.font =
                AppFont.font(size: size)
                ?? .systemFont(ofSize: size)
            cell = glyphLabel.cell?.cellSize ?? .zero
        }
        // With a name, a narrow glyph snugs toward the text so
        // its slack doesn't widen the gap; icon-only items center.
        let snugToName = horizontal && !label.isHidden
        // The frame takes the cell's own width so the alignment
        // holds, and the INK is what centres and snugs, never the
        // advance (#1529, #1543). The frame's padding may cross
        // the box; the ink stays inside it while the cell's
        // padding exceeds a ligature's overshoot of its advance.
        let width = ceil(cell.width)
        let metrics = BarTextGlyph.metrics(of: glyphLabel)
        let x =
            snugToName
            ? max(
                metrics.originX(
                    inkTrailingAt: square.maxX,
                    frameWidth: width
                ),
                box.minX - metrics.inkLead(inFrameOfWidth: width)
            )
            : metrics.originX(
                centringInkOn: box.midX,
                frameWidth: width
            )
        glyphLabel.frame = CGRect(
            x: x.rounded(),
            y: (box.midY - cell.height / 2).rounded(),
            width: width,
            height: cell.height
        )
    }

    /// The glyph's ink along the bar — what a badge hangs on.
    var glyphInkFrame: CGRect {
        let frame = glyphLabel.frame
        let span = BarTextGlyph.metrics(of: glyphLabel).inkSpan(in: frame)
        return CGRect(
            x: span.lowerBound,
            y: frame.minY,
            width: span.upperBound - span.lowerBound,
            height: frame.height
        )
    }
}
