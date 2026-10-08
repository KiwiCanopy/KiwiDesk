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
        style: SpaceBarLook,
        horizontal: Bool
    ) {
        frontWindows = app?.windows ?? []
        guard let app else {
            [
                frontBox, frontBorder, frontAccentClip, frontDivider,
                frontIcon, frontGlyph, frontName,
            ]
            .forEach { $0.isHidden = true }
            // The glass AND its tint: a tint left up reads as a
            // dark chip on a Space with no front app.
            updateFrontGlass(nil, radius: 0, style: style)
            return
        }
        attachFrontViewsIfNeeded()
        let depth = horizontal ? strip.height : strip.width
        let cell = SpaceBarItemView.cell(
            contentDepth: style.contentDepth(forDepth: depth)
        )
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

    /// The axis length the front segment DRAWS from the run's
    /// `frontStart` (#409): the section rule, a gap, the chip —
    /// its ends, the glyph cell and, on a horizontal bar, a pad
    /// and the name's fixed `titleSlot`, never the name itself, so
    /// a focus change moves nothing (#2086). The gap before the
    /// rule is the run's (`runTotal`), so a hugging plate ends
    /// where the chip does.
    func frontExtent(
        _ app: SpaceBarItemView.App?,
        depth: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook
    ) -> CGFloat {
        guard app != nil else { return 0 }
        let cell = SpaceBarItemView.cell(
            contentDepth: style.contentDepth(forDepth: depth)
        )
        var extent =
            BarDivider.sectionThickness + style.itemGap
            + Self.chipEndPad(style, depth: depth).total + cell
        if horizontal {
            extent +=
                SpaceBarItemView.pad + Self.titleSlot(style, depth: depth)
        }
        return extent
    }

    /// The width `layoutFrontName`'s `sizeToFit` gives `text` in
    /// `font` — the label's own cell, padding included.
    static func titleWidth(_ text: String, font: NSFont) -> CGFloat {
        measure.font = font
        measure.stringValue = text
        measure.sizeToFit()
        return measure.frame.width
    }

    private static let measure = NSTextField(labelWithString: "")

    private func attachFrontViewsIfNeeded() {
        // Only a host CHANGE reparents (a plain `addSubview`
        // detaches from the previous parent); a view already in
        // its host is left alone, so a steady render adds nothing
        // to a glass subtree (#1315).
        let content = frontHost ?? itemRun
        for view in [
            frontBox, frontBorder, frontAccentClip, frontDivider,
            frontIcon, frontGlyph, frontName,
        ] where view.superview !== content {
            content.addSubview(
                view,
                positioned: .above,
                relativeTo: nil
            )
        }
        frontDivider.wantsLayer = true
        if frontAccent.superview !== frontAccentClip {
            frontAccentClip.wantsLayer = true
            frontAccentClip.addSubview(frontAccent)
        }
        frontIcon.setAccessibilityElement(false)
        frontName.setAccessibilityElement(false)
    }

    /// Separator rule between Space items and front app segment (#409).
    private func layoutDivider(
        at offset: CGFloat,
        depth: CGFloat,
        cell: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook
    ) -> CGFloat {
        frontDivider.isHidden = false
        frontDivider.layer?.backgroundColor =
            BarDivider.color(textColor: style.itemColor)
            .cgColor
        frontDivider.frame = BarDivider.frame(
            at: offset,
            depth: depth,
            horizontal: horizontal,
            thickness: BarDivider.sectionThickness,
            lengthShare: BarDivider.sectionLengthShare
        )
        return BarDivider.sectionThickness + style.itemGap
            + Self.chipEndPad(style, depth: depth)
            .leading
    }

    /// The front chip's end padding — an item's pad plus the
    /// rounded end's clearance at each end the shelf rounds, read
    /// through the one `KiwiShelf.itemEnds` (#1763) for the run's
    /// last place: both ends while Boxed or outlined, so a title
    /// ends as far inside the chip as the icon starts (#1856,
    /// owner 2026-10-01), and every shelf style pads, since the
    /// chip draws its indicator in each. The extent, the
    /// content's start, the title's cap, the box and the indicator
    /// all read it.
    static func chipEndPad(
        _ style: SpaceBarLook,
        depth: CGFloat
    ) -> ItemEnds {
        let pad = SpaceBarItemView.pad
        let ends = style.shelf.itemEnds(
            clearance: SpaceBarItemView.endClearance(
                look: style,
                depth: depth
            ),
            first: false,
            last: true,
            outlined: style.activeIndicator.drawsOutline
        )
        return ItemEnds(
            leading: pad + ends.leading,
            trailing: pad + ends.trailing
        )
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
        style: SpaceBarLook
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
            let host = frontGlyph.superview ?? itemRun
            frontGlyph.frame = host.backingAlignedRect(
                BarTextGlyph.frame(
                    for: frontGlyph,
                    in: frame,
                    band: .caps
                ),
                options: .alignAllEdgesNearest
            )
            frontGlyph.setAccessibilityElement(true)
            frontGlyph.setAccessibilityLabel(axLabel)
            frontGlyph.actions = { [weak self] in self?.shelfActions ?? [] }
        } else {
            frontGlyph.isHidden = true
            frontGlyph.setAccessibilityElement(false)
            frontIcon.isHidden = false
            frontIcon.image = app.icon
            frontIcon.imageScaling = .scaleProportionallyUpOrDown
            frontIcon.frame = frame
            frontIcon.setAccessibilityElement(true)
            frontIcon.setAccessibilityLabel(axLabel)
            frontIcon.actions = { [weak self] in self?.shelfActions ?? [] }
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
        style: SpaceBarLook
    ) {
        guard horizontal else {
            frontName.isHidden = true
            return
        }
        frontName.isHidden = false
        frontName.stringValue = app.title ?? app.name
        let size = style.titleFontSize(forDepth: depth)
        frontName.font = style.shelf.textFont(ofSize: size)
        frontName.textColor = accent
        frontName.lineBreakMode = .byTruncatingTail
        frontName.alignment = .center
        frontName.sizeToFit()
        let height = frontName.frame.height
        // Clamp to the viewport's remaining length so a long name
        // ellipsizes instead of hard-clipping at the panel edge; a
        // chip's box runs its end pad past the name (#1763).
        let trailing = max(
            SpaceBarItemView.pad,
            Self.chipEndPad(style, depth: depth).trailing
        )
        let available = max(viewport - offset - trailing, 0)
        let slot = min(Self.titleSlot(style, depth: depth), available)
        frontNameEnd = offset + slot
        let span = Self.nameSpan(
            frontName,
            natural: frontName.frame.width,
            slotStart: offset,
            slot: slot
        )
        frontName.frame = CGRect(
            x: span.lowerBound,
            y: BarTextGlyph.originY(
                centredOn: depth / 2,
                for: frontName,
                band: .caps,
                height: height
            ),
            width: span.upperBound - span.lowerBound,
            height: height
        )
    }

    /// The segment's menu as VoiceOver actions (#1518, #2024): the
    /// chip is a plain label or image, so it carries them as a list
    /// rather than answering per query.
    var shelfActions: [NSAccessibilityCustomAction] {
        contextMenus?.accessibilityActions(for: frontMenuHit) ?? []
    }
}
