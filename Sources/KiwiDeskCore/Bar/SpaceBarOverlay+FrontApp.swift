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
        viewport: CGFloat,
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
            accent: accent,
            style: style
        )
        layoutFrontName(
            app,
            at: offset,
            depth: depth,
            viewport: viewport,
            horizontal: horizontal,
            accent: accent,
            style: style
        )
    }

    /// Axis length the segment will consume, for the render
    /// pass's alignment total — the leading box gap, the
    /// divider and glyph (`layoutDivider`/`layoutFrontGlyph`
    /// mirrors), and on horizontal bars the glyph→name pad
    /// plus the measured name. Vertical bars end at the glyph
    /// (no name), so no trailing pad is counted there. The
    /// horizontal name is an estimate on both ends —
    /// `sizeToFit` at layout time pads a little wider than
    /// `NSString.size`, the trailing pad here absorbs that —
    /// and the name still clamps to the remaining strip, so
    /// no alignment can push content past the rim.
    func frontExtent(
        _ app: SpaceBarItemView.App?,
        depth: CGFloat,
        horizontal: Bool,
        style: SpaceBarStyle
    ) -> CGFloat {
        guard let app else { return 0 }
        let pad = SpaceBarItemView.pad
        let cell = max(depth - pad * 2, 8)
        var extent = style.boxGap + 1 + pad + cell
        if horizontal {
            extent += pad
            let size =
                style.fontSize > 0
                ? style.fontSize : depth * 0.42
            extent +=
                ceil(
                    (app.name as NSString).size(
                        withAttributes: [
                            .font: NSFont.systemFont(
                                ofSize: size
                            )
                        ]
                    ).width
                ) + pad
        }
        return extent
    }

    private func attachFrontViewsIfNeeded() {
        // The segment lives inside the clipping viewport so it
        // scrolls (and clips) with the items — the tail of one
        // run (#385). Re-added every render so it stays ABOVE item
        // views created later (`syncItemViewCount` appends on
        // top) — otherwise a long item row paints over it.
        let content = itemContainer
        for view in [
            frontDivider, frontIcon, frontGlyph, frontName,
        ] {
            content.addSubview(
                view,
                positioned: .above,
                relativeTo: nil
            )
        }
        frontDivider.wantsLayer = true
        frontIcon.setAccessibilityElement(false)
        frontName.setAccessibilityElement(false)
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
            color.withAlphaComponent(SpaceBarStyle.frontDividerAlpha)
            .cgColor
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
        accent: NSColor,
        style: SpaceBarStyle
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
        // The one AX element the segment exposes: the visible
        // glyph carries "Front app: <name>"; everything else
        // stays silent (glyphs are informational).
        let axLabel = L(
            "space_bar.front_app.ax",
            "Front app: %1$@",
            app.name
        )
        if let glyph = app.glyph {
            frontIcon.isHidden = true
            frontGlyph.isHidden = false
            frontGlyph.stringValue = glyph
            // Same ladder as item glyphs: an explicit font_size
            // wins, else scale with the cell.
            let size =
                style.fontSize > 0
                ? style.fontSize * 0.9 : cell * 0.72
            frontGlyph.font =
                AppFont.font(size: size)
                ?? .systemFont(ofSize: size)
            frontGlyph.textColor = accent
            // Text draws from the frame's top: shrink to the
            // measured height, centered in the cell — the
            // `SpaceBarItemView.place` twin.
            var glyphFrame = frame
            let height = ceil(
                frontGlyph.cell?.cellSize.height ?? 0
            )
            if height > 0, height < glyphFrame.height {
                glyphFrame.origin.y +=
                    ((glyphFrame.height - height) / 2)
                    .rounded()
                glyphFrame.size.height = height
            }
            frontGlyph.frame = glyphFrame
            frontGlyph.setAccessibilityElement(true)
            frontGlyph.setAccessibilityLabel(axLabel)
        } else {
            frontGlyph.isHidden = true
            frontGlyph.setAccessibilityElement(false)
            frontIcon.isHidden = false
            frontIcon.image = app.icon
            frontIcon.imageScaling = .scaleProportionallyUpOrDown
            frontIcon.frame = frame
            frontIcon.setAccessibilityElement(true)
            frontIcon.setAccessibilityLabel(axLabel)
        }
        return cell + SpaceBarItemView.pad
    }

    /// The app name — horizontal bars only (vertical stays
    /// icon-only, never rotated).
    private func layoutFrontName(
        _ app: SpaceBarItemView.App,
        at offset: CGFloat,
        depth: CGFloat,
        viewport: CGFloat,
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
        // Clamp to the viewport's remaining length so a long name
        // ellipsizes instead of hard-clipping at the panel edge.
        let available = max(
            viewport - offset - SpaceBarItemView.pad,
            0
        )
        frontName.frame = CGRect(
            x: offset,
            y: (depth - height) / 2,
            width: min(frontName.frame.width, available),
            height: height
        )
    }
}
