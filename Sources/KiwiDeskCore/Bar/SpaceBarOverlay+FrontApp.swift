import AppKit

/// Trailing front-app segment rendering for `SpaceBarOverlay` (#293 verdict
/// 6).
extension SpaceBarOverlay {
    /// Lays out or hides front-app segment along bar axis.
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

    /// Total axis length consumed by front segment (#409).
    func frontExtent(
        _ app: SpaceBarItemView.App?,
        depth: CGFloat,
        horizontal: Bool,
        style: SpaceBarStyle
    ) -> CGFloat {
        guard let app else { return 0 }
        let pad = SpaceBarItemView.pad
        let cell = max(depth - pad * 2, 8)
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
                    // What is DRAWN, not the app name: measuring
                    // a different string than `layoutFrontName`
                    // lays out slides the whole Space run off its
                    // alignment.
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
        // Re-added every render so the segment stays ABOVE item
        // views created later (`syncItemViewCount` appends on
        // top); moving hosts also detaches from the previous
        // parent (a plain `addSubview` reparents).
        let content = frontHost ?? itemContainer
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

    /// Separator rule between Space items and front app segment (#409).
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
        let chip = style.hasBox || wantsBoxGlass(style)
        return BarDivider.sectionThickness + style.itemGap
            + (chip ? SpaceBarItemView.pad : 0)
    }

    /// Focused app glyph or icon layout with accessibility (#160, QA
    /// 2026-07-19, `SpaceBarItemView.place`).
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
        // The one AX element the segment exposes. Names the APP
        // even when a title is drawn, and first — a title alone
        // says nothing about where it lives. Two frames rather
        // than one with a withheld argument: an app with no title
        // yet (#160) should announce a short sentence, not a
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
            let size = style.glyphFontSize(forDepth: depth)
            frontGlyph.font =
                AppFont.font(size: size)
                ?? .systemFont(ofSize: size)
            frontGlyph.textColor = accent
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

    /// Front app window title layout for horizontal bars.
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
