import AppKit

/// Slot layout implementation for `SpaceBarItemView`.
extension SpaceBarItemView {
    /// Cross-axis padding inside the slot.
    nonisolated static let pad: CGFloat = 4

    /// The item's depth across the shelf.
    var depth: CGFloat { horizontal ? bounds.height : bounds.width }

    /// The depth this item's content is sized to (#1682).
    var contentDepth: CGFloat { style.contentDepth(forDepth: depth) }

    /// Cell dimension for glyphs along the bar axis.
    var cellLength: CGFloat { Self.cell(contentDepth: contentDepth) }

    /// A glyph cell's side for a content depth — the one
    /// derivation the items and the front-app segment share.
    static func cell(contentDepth: CGFloat) -> CGFloat {
        max(contentDepth - pad * 2, 8)
    }

    /// Computes requested slot length for given app count and the
    /// `+n` discs drawn (one per side that hides windows, #1528).
    /// `glyphGap` is the style's `resolvedGlyphGap`, taken with
    /// no default so a caller cannot measure without it (#1689);
    /// `contentDepth` is the shelf's for the strip (#1682), and
    /// `ends` the item's `ends(look:depth:first:last:)` (#1763).
    /// `marked` adds the Space marker's slot after the identifier
    /// (#1790).
    static func autoLength(
        appCount: Int,
        discs: Int = 0,
        marked: Bool = false,
        identifierInk: CGFloat? = nil,
        collapsed: Bool = false,
        contentDepth: CGFloat,
        glyphGap: CGFloat,
        ends: ItemEnds
    ) -> CGFloat {
        let cell = cell(contentDepth: contentDepth)
        let slots = appCount + discs
        let divider: CGFloat = slots > 0 ? pad + 1 + pad : 0
        let gaps = CGFloat(max(slots - 1, 0)) * glyphGap
        return contentInset(ends: ends).total + cell
            + markerLength(
                cell: cell,
                marked: marked,
                ink: identifierInk,
                collapsed: collapsed
            )
            + divider
            + CGFloat(slots) * cell + gaps
    }

    /// How far in from each end an item's content starts: `pad`
    /// and the rounded-end clearance `ends` owes — the one reading
    /// `layout()`, `autoLength` and the shelf divider share (#1779).
    static func contentInset(ends: ItemEnds) -> ItemEnds {
        ItemEnds(leading: pad + ends.leading, trailing: pad + ends.trailing)
    }

    override func layout() {
        super.layout()
        let cell = cellLength
        if case .text = spaceGlyph {
            identifierLabel.font = style.shelf.textFont(
                ofSize: identifierFont
            )
        }
        // Restyle BEFORE placing: `place` measures each text
        // glyph to center it, and the glyph fonts are set in
        // `restyle`.
        restyle()
        var cursor = Self.contentInset(ends: ends).leading
        place(identifierImage, at: cursor, cell: cell)
        place(
            identifierLabel,
            at: cursor,
            cell: cell,
            slack: Self.pad
        )
        if collapse != nil {
            layoutBadge(overflowBadge, onCellAt: cursor, cell: cell)
        }
        cursor += cell
        layoutMarker(after: cursor, cell: cell)
        cursor += Self.markerLength(
            cell: cell,
            marked: marker != nil,
            ink: identifierInkWidth,
            collapsed: collapse != nil
        )
        if !identifierDivider.isHidden {
            cursor += Self.pad
            // An in-item rule is content: centred on the full
            // depth, as long as the content allows (#1682).
            identifierDivider.frame = BarDivider.frame(
                at: cursor,
                depth: depth,
                horizontal: horizontal,
                lengthShare: BarDivider.ruleLengthShare
                    * contentDepth / max(depth, 1)
            )
            cursor += 1 + Self.pad
        }
        let glyphGap = style.resolvedGlyphGap
        if collapse == nil, !before.windows.isEmpty {
            layoutBadge(
                leadingBadge,
                onCellAt: cursor,
                cell: cell,
                centered: true
            )
            leadingTarget?.frame = cellRect(at: cursor, cell: cell)
            cursor += cell + glyphGap
        }
        for (index, view) in appViews.enumerated() {
            if index > 0 { cursor += glyphGap }
            place(view, at: cursor, cell: cell)
            if index < glyphTargets.count {
                glyphTargets[index].frame = cellRect(
                    at: cursor,
                    cell: cell
                )
            }
            if index < badgeViews.count {
                layoutBadge(
                    badgeViews[index],
                    onCellAt: cursor,
                    cell: cell
                )
            }
            layoutStateBadges(
                at: index,
                onCellAt: cursor,
                cell: cell
            )
            cursor += cell
        }
        if collapse == nil, !after.windows.isEmpty {
            if !appViews.isEmpty { cursor += glyphGap }
            layoutBadge(
                overflowBadge,
                onCellAt: cursor,
                cell: cell,
                centered: true
            )
            overflowTarget?.frame = cellRect(at: cursor, cell: cell)
            cursor += cell
        }
        slideGlyphs(pitch: cell + glyphGap)
        layoutAccent()
    }

    /// Positions count badge on cell corner or centered for overflow.
    private func layoutBadge(
        _ badge: NSTextField,
        onCellAt offset: CGFloat,
        cell: CGFloat,
        centered: Bool = false
    ) {
        guard !badge.isHidden else { return }
        let base =
            centered
            ? cell * 0.8 : StateBadgeMetrics.side(cell: cell)
        badge.font = style.shelf.badgeFont(
            ofSize: base * (centered ? 0.5 : 0.72),
            emphasis: .bold
        )
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        let diameter = min(max(base, textWidth + 2), cell + 2)
        let box = cellRect(at: offset, cell: cell)
        let rect =
            centered
            ? CGRect(
                x: box.midX - diameter / 2,
                y: box.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
            : CGRect(
                x: box.maxX - diameter + 1,
                y: box.minY - 1,
                width: diameter,
                height: diameter
            )
        badge.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
        badge.layer?.cornerRadius = diameter / 2
    }

    /// Positions sticky and floating state badges on glyph cell (#414).
    private func layoutStateBadges(
        at index: Int,
        onCellAt offset: CGFloat,
        cell: CGFloat
    ) {
        let side = StateBadgeMetrics.side(cell: cell)
        let box = cellRect(at: offset, cell: cell)
        if index < stickyBadgeViews.count,
            let badge = stickyBadgeViews[index], !badge.isHidden
        {
            badge.frame = backingAlignedRect(
                CGRect(
                    x: box.minX - 1,
                    y: box.minY - 1,
                    width: side,
                    height: side
                ),
                options: .alignAllEdgesNearest
            )
            badge.needsLayout = true
        }
        if index < floatingBadgeViews.count,
            let badge = floatingBadgeViews[index], !badge.isHidden
        {
            badge.frame = backingAlignedRect(
                CGRect(
                    x: box.minX - 1,
                    y: box.maxY - side + 1,
                    width: side,
                    height: side
                ),
                options: .alignAllEdgesNearest
            )
            badge.needsLayout = true
        }
    }

    /// `slack` is how far a text glyph's ink may reach past the
    /// cell on a side before its font is scaled (`BarTextGlyph`).
    private func place(
        _ view: NSView,
        at offset: CGFloat,
        cell: CGFloat,
        slack: CGFloat = 0
    ) {
        var rect = cellRect(at: offset, cell: cell)
        if let field = view as? NSTextField {
            rect = BarTextGlyph.frame(
                for: field,
                in: rect,
                band: .of(identifier: field.stringValue),
                slack: slack
            )
        }
        view.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
    }

    private func layoutAccent() {
        switch style.activeIndicator {
        case .outline:
            accent.frame =
                BarAccent.outline(
                    in: bounds,
                    radius: cornerRadius,
                    boxed: !style.shelf.drawsPlate
                ).frame
        case .edgeMark:
            accent.frame = BarAccent.edgeMarkFrame(
                in: bounds,
                edge: style.edge,
                thickness: style.edgeMarkThickness
            )
        }
    }
}
