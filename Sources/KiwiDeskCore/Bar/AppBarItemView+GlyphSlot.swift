import AppKit

/// The icon slot's occupancy and glyph placement (#294),
/// split from the main slot layout (file-size ceiling).
/// Internal, not private: `layoutHorizontal` /
/// `layoutVertical` call in from their own file.
extension AppBarItemView {
    /// Whether the icon slot is occupied at all — by the app
    /// image or by an App Font glyph (#294); both share the
    /// same square.
    var iconSlotHidden: Bool {
        iconView.isHidden && glyphLabel.isHidden
    }

    /// Places whichever occupant the icon slot has: the image
    /// fills the square; the glyph (text) works in a box grown
    /// back to the full cross thickness — the font's glyphs
    /// carry their own internal margins inside the em, so the
    /// padded image square reads visibly undersized for them.
    /// The glyph sizes to its cell, shrinks until the cell fits
    /// the box's width (a wide ligature must never spill into
    /// the tab padding or the name), and centers pixel-aligned.
    func layoutIconSlot(in square: CGRect) {
        if glyphLabel.isHidden {
            iconView.frame = square
            return
        }
        // The glyph's working box grows past the image square —
        // the font's glyphs carry internal margins, so the
        // padded square reads undersized — but only DOWNWARD-
        // vertically and toward the text: the leading edge
        // stays pinned to the square so a wide glyph never
        // shifts toward (or out of) the tab border.
        let pad = Self.contentPadding
        let box =
            horizontal
            ? CGRect(
                x: square.minX,
                y: square.minY - pad,
                width: square.width + pad,
                height: square.height + pad * 2
            )
            : square.insetBy(dx: -pad, dy: -pad)
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
        // so a wide glyph can never hang out of the tab.
        // Icon-only tabs center.
        let snugToName = horizontal && !label.isHidden
        let x =
            snugToName
            ? max(square.maxX - cell.width, box.minX)
            : box.midX - cell.width / 2
        glyphLabel.frame = CGRect(
            x: x.rounded(),
            y: (box.midY - cell.height / 2).rounded(),
            width: min(cell.width, box.width),
            height: cell.height
        )
    }
}
