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
        nameBound: CGFloat,
        style: SpaceBarStyle,
        horizontal: Bool
    ) {
        guard let app else {
            [frontBox, frontDivider, frontIcon, frontGlyph, frontName]
                .forEach { $0.isHidden = true }
            frontGlass?.isHidden = true
            return
        }
        attachFrontViewsIfNeeded()
        let depth = horizontal ? strip.height : strip.width
        let cell = max(depth - SpaceBarItemView.pad * 2, 8)
        // The focused window's accent paints the front-app glyph
        // and name — the segment IS the focused window.
        let accent = NSColor(kiwiHex: style.focusedItemColor)
        var offset = cursor
        offset += layoutDivider(
            at: offset,
            depth: depth,
            cell: cell,
            horizontal: horizontal,
            style: style
        )
        let contentStart = offset
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
            viewport: nameBound,
            horizontal: horizontal,
            accent: accent,
            style: style
        )
        layoutFrontBox(
            app,
            from: contentStart,
            depth: depth,
            cell: cell,
            horizontal: horizontal,
            style: style
        )
    }

    /// Axis length the segment will consume, for the render
    /// pass's alignment total — the leading item gap, the
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
        // Mirror the placement (#409): leading gap, rule, symmetric
        // `itemGap` right gap, glyph cell, plus the chip's `pad`
        // inset each side — which also reserves the pinned band.
        let chip = style.hasBox || wantsBoxGlass(style)
        let inset = chip ? pad : 0
        var extent =
            style.itemGap + BarDivider.sectionThickness
            + style.itemGap + inset + cell + inset
        if horizontal {
            extent += pad
            let size =
                style.fontSize > 0
                ? style.fontSize : depth * 0.42
            extent +=
                ceil(
                    // What is DRAWN, not the app name: the
                    // estimate feeds the render pass's alignment
                    // total, so measuring a different string
                    // than `layoutFrontName` lays out slides the
                    // whole Space run off its alignment.
                    ((app.title ?? app.name) as NSString).size(
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
        // The segment hosts in the clipping viewport (run tail) or,
        // while pinned, in the panel content outside it (#409) — see
        // `frontHost`. Re-added every render so it stays ABOVE item
        // views created later (`syncItemViewCount` appends on top,
        // and pinned it must sit over the plate) — otherwise a long
        // item row paints over it. Moving hosts also detaches it
        // from the previous parent (a plain `addSubview` reparents).
        let content = frontHost ?? itemContainer
        // frontBox first so it lands beneath the divider/glyph/
        // name added above it — the box is the chip behind them.
        for view in [
            frontBox, frontDivider, frontIcon, frontGlyph, frontName,
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
    /// Derives its own treatment from the style so no caller
    /// can hand it an untreated color.
    private func layoutDivider(
        at offset: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        style: SpaceBarStyle
    ) -> CGFloat {
        frontDivider.isHidden = false
        frontDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor)
            .cgColor
        frontDivider.frame = BarDivider.frame(
            at: offset,
            depth: depth,
            cell: cell,
            horizontal: horizontal,
            thickness: BarDivider.sectionThickness,
            fullDepth: true
        )
        // Symmetric gap (#409): `itemGap` on the rule's right to
        // match the `itemGap` the run cursor already left on its
        // left. Under a chip (Boxed / per-box glass) the content is
        // `pad`-inset, so the chip EDGE lands `itemGap` out; Plain
        // has no chip, so the bare glyph sits `itemGap` out.
        let chip = style.hasBox || wantsBoxGlass(style)
        return BarDivider.sectionThickness + style.itemGap
            + (chip ? SpaceBarItemView.pad : 0)
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
        // The one AX element the segment exposes; everything
        // else stays silent (glyphs are informational).
        //
        // Names the APP even when a title is drawn, and names it
        // first: the icon beside it is the app's, a title alone
        // ("Downloads") says nothing about where it lives, and
        // an app name is stable under a reader while a title
        // changes as the user types. Two frames rather than one
        // with a withheld argument — an app with no title yet
        // (#160) should announce a short sentence, not a
        // dangling separator.
        let axLabel =
            app.title.map {
                L(
                    "space_bar.front_window.ax",
                    "Front app: %1$@, window %2$@",
                    app.name,
                    $0
                )
            }
            ?? L(
                "space_bar.front_app.ax",
                "Front app: %1$@",
                app.name
            )
        if let glyph = app.glyph {
            frontIcon.isHidden = true
            frontGlyph.isHidden = false
            frontGlyph.stringValue = glyph
            // The item glyphs' shared ladder — a second formula
            // here rendered the same app at a visibly different
            // size in auto mode (QA 2026-07-19).
            let size = style.glyphFontSize(forDepth: depth)
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
        frontName.stringValue = app.title ?? app.name
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
