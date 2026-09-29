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
        guard let app else {
            [
                frontBox, frontBorder, frontDivider, frontIcon,
                frontGlyph, frontName,
            ]
            .forEach { $0.isHidden = true }
            frontGlass?.isHidden = true
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

    /// Total axis length consumed by front segment (#409).
    func frontExtent(
        _ app: SpaceBarItemView.App?,
        depth: CGFloat,
        horizontal: Bool,
        style: SpaceBarLook
    ) -> CGFloat {
        guard let app else { return 0 }
        let pad = SpaceBarItemView.pad
        let cell = SpaceBarItemView.cell(
            contentDepth: style.contentDepth(forDepth: depth)
        )
        let inset = chipEndPad(
            style,
            depth: depth,
            horizontal: horizontal
        )
        var extent =
            style.itemGap + BarDivider.sectionThickness
            + style.itemGap + inset.total + cell
        if horizontal {
            extent += pad
            let size = style.titleFontSize(forDepth: depth)
            extent +=
                ceil(
                    // What is DRAWN, not the app name: measuring
                    // a different string than `layoutFrontName`
                    // lays out slides the whole Space run off its
                    // alignment.
                    ((app.title ?? app.name) as NSString).size(
                        withAttributes: [
                            .font: style.shelf.textFont(
                                ofSize: size
                            )
                        ]
                    ).width
                ) + pad
        }
        return extent
    }

    private func attachFrontViewsIfNeeded() {
        // Only a host CHANGE reparents (a plain `addSubview`
        // detaches from the previous parent); a view already in
        // its host is left alone, so a steady render adds nothing
        // to a glass subtree (#1315).
        let content = frontHost ?? itemContainer
        for view in [
            frontBox, frontBorder, frontDivider, frontIcon, frontGlyph,
            frontName,
        ] where view.superview !== content {
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
            + chipEndPad(style, depth: depth, horizontal: horizontal)
            .leading
    }

    /// The front chip's end padding — an item's pad, plus the
    /// rounded end's clearance where the app icon sits: leading
    /// always, trailing only on a vertical bar, where no title
    /// follows the icon (#1763, owner 2026-09-29) — or 0 where no
    /// chip draws. The extent, the content's start, the title's
    /// cap and the box all read it.
    func chipEndPad(
        _ style: SpaceBarLook,
        depth: CGFloat,
        horizontal: Bool
    ) -> ItemEnds {
        guard style.hasBox || wantsBoxGlass(style) else { return .zero }
        let pad = SpaceBarItemView.pad
        let clear = SpaceBarItemView.endClearance(look: style, depth: depth)
        return ItemEnds(
            leading: pad + clear,
            trailing: pad + (horizontal ? 0 : clear)
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
            let host = frontGlyph.superview ?? itemContainer
            frontGlyph.frame = host.backingAlignedRect(
                BarTextGlyph.frame(for: frontGlyph, in: frame),
                options: .alignAllEdgesNearest
            )
            frontGlyph.setAccessibilityElement(true)
            frontGlyph.setAccessibilityLabel(axLabel)
            frontGlyph.setAccessibilityCustomActions(shelfActions)
        } else {
            frontGlyph.isHidden = true
            frontGlyph.setAccessibilityElement(false)
            frontIcon.isHidden = false
            frontIcon.image = app.icon
            frontIcon.imageScaling = .scaleProportionallyUpOrDown
            frontIcon.frame = frame
            frontIcon.setAccessibilityElement(true)
            frontIcon.setAccessibilityLabel(axLabel)
            frontIcon.setAccessibilityCustomActions(shelfActions)
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
        frontName.sizeToFit()
        let height = frontName.frame.height
        // Clamp to the viewport's remaining length so a long name
        // ellipsizes instead of hard-clipping at the panel edge; a
        // chip's box runs its end pad past the name (#1763).
        let trailing = max(
            SpaceBarItemView.pad,
            chipEndPad(style, depth: depth, horizontal: true).trailing
        )
        let available = max(viewport - offset - trailing, 0)
        frontName.frame = CGRect(
            x: offset,
            y: BarTextGlyph.originY(
                capsCentredOn: depth / 2,
                for: frontName,
                height: height
            ),
            width: min(frontName.frame.width, available),
            height: height
        )
    }

    /// The shelf section as VoiceOver actions (#1518): the front-app
    /// chip is a plain label or image, so it carries them as a list
    /// rather than answering per query.
    private var shelfActions: [NSAccessibilityCustomAction] {
        contextMenus?.accessibilityActions(for: .empty) ?? []
    }
}
