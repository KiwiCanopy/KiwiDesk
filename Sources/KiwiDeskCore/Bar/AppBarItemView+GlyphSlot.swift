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
        // 0.9: full box height read a touch heavy in manual QA.
        var size = box.height * 0.9
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
        // its slack doesn't widen the gap — clamped to its box,
        // so a wide glyph can never hang out of the item.
        // Icon-only items center.
        let snugToName = horizontal && !label.isHidden
        // Clamp BEFORE positioning: centering the unclamped
        // cell width then clamping the frame shifted the glyph
        // toward the leading edge whenever the measured cell
        // exceeded its box (QA 2026-07-19, vertical bars).
        let width = min(cell.width, box.width)
        let x =
            snugToName
            ? max(square.maxX - width, box.minX)
            : box.midX - width / 2
        glyphLabel.frame = CGRect(
            x: x.rounded(),
            y: (box.midY - cell.height / 2).rounded(),
            width: width,
            height: cell.height
        )
    }
}
