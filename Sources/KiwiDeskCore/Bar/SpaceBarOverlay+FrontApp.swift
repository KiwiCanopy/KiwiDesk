import AppKit

/// The trailing front-app segment (#293 verdict 6):
/// `| <glyph + app name>` after the last Space item. On
/// vertical bars the segment is icon-only — never rotated
/// text, never hidden — and the divider flips to a horizontal
/// rule. Informational; no click target.
extension SpaceBarOverlay {
    /// Lays out (or hides) the segment starting at `cursor`
    /// along the bar axis.
    func renderFrontSegment(
        _ app: SpaceBarItemView.App?,
        after cursor: CGFloat,
        strip: CGRect,
        style: SpaceBarStyle,
        horizontal: Bool
    ) {
        guard let app else {
            [frontDivider, frontIcon, frontGlyph, frontName]
                .forEach { $0.isHidden = true }
            return
        }
        attachFrontViewsIfNeeded()
        let depth = horizontal ? strip.height : strip.width
        let cell = max(depth - SpaceBarItemView.pad * 2, 8)
        let accent = NSColor(kiwiHex: style.activeTextColor)
        var offset = cursor
        offset += layoutDivider(
            at: offset,
            depth: depth,
            cell: cell,
            horizontal: horizontal,
            color: NSColor(kiwiHex: style.textColor)
        )
        offset += layoutFrontGlyph(
            app,
            at: offset,
            depth: depth,
            cell: cell,
            horizontal: horizontal,
            accent: accent
        )
        layoutFrontName(
            app,
            at: offset,
            depth: depth,
            horizontal: horizontal,
            accent: accent,
            style: style
        )
    }

    private func attachFrontViewsIfNeeded() {
        guard let content = panelContentView else { return }
        for view in [
            frontDivider, frontIcon, frontGlyph, frontName,
        ]
        where view.superview == nil {
            content.addSubview(view)
        }
        frontDivider.wantsLayer = true
    }

    /// The separator rule; returns the axis length consumed.
    private func layoutDivider(
        at offset: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        color: NSColor
    ) -> CGFloat {
        frontDivider.isHidden = false
        frontDivider.layer?.backgroundColor =
            color.withAlphaComponent(0.4).cgColor
        let inset = (depth - cell) / 2
        frontDivider.frame =
            horizontal
            ? CGRect(x: offset, y: inset, width: 1, height: cell)
            : CGRect(x: inset, y: offset, width: cell, height: 1)
        return 1 + SpaceBarItemView.pad
    }

    /// The focused app's glyph (App Font ligature or image);
    /// returns the axis length consumed.
    private func layoutFrontGlyph(
        _ app: SpaceBarItemView.App,
        at offset: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        accent: NSColor
    ) -> CGFloat {
        let inset = (depth - cell) / 2
        let frame =
            horizontal
            ? CGRect(
                x: offset,
                y: inset,
                width: cell,
                height: cell
            )
            : CGRect(
                x: inset,
                y: offset,
                width: cell,
                height: cell
            )
        if let glyph = app.glyph {
            frontIcon.isHidden = true
            frontGlyph.isHidden = false
            frontGlyph.stringValue = glyph
            frontGlyph.font =
                AppFont.font(size: cell * 0.72)
                ?? .systemFont(ofSize: cell * 0.72)
            frontGlyph.textColor = accent
            frontGlyph.frame = frame
        } else {
            frontGlyph.isHidden = true
            frontIcon.isHidden = false
            frontIcon.image = app.icon
            frontIcon.imageScaling = .scaleProportionallyUpOrDown
            frontIcon.frame = frame
        }
        return cell + SpaceBarItemView.pad
    }

    /// The app name — horizontal bars only (vertical stays
    /// icon-only, never rotated).
    private func layoutFrontName(
        _ app: SpaceBarItemView.App,
        at offset: CGFloat,
        depth: CGFloat,
        horizontal: Bool,
        accent: NSColor,
        style: SpaceBarStyle
    ) {
        guard horizontal else {
            frontName.isHidden = true
            return
        }
        frontName.isHidden = false
        frontName.stringValue = app.name
        let size =
            style.fontSize > 0
            ? style.fontSize : depth * 0.42
        frontName.font = .systemFont(ofSize: size)
        frontName.textColor = accent
        frontName.lineBreakMode = .byTruncatingTail
        frontName.sizeToFit()
        let height = frontName.frame.height
        frontName.frame = CGRect(
            x: offset,
            y: (depth - height) / 2,
            width: frontName.frame.width,
            height: height
        )
    }
}
