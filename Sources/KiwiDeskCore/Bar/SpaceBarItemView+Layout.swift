import AppKit

/// Slot layout for one Space item: the identifier glyph leads
/// (left on a horizontal bar, top on a vertical one), the app
/// glyphs follow along the bar axis. Pixel-rounded so glyphs
/// never land on half pixels.
extension SpaceBarItemView {
    /// Cross-axis padding inside the slot.
    static let pad: CGFloat = 4

    /// Square cell length each glyph (identifier or app)
    /// occupies along the bar axis, derived from the cross
    /// depth.
    var cellLength: CGFloat {
        let depth = horizontal ? bounds.height : bounds.width
        return max(depth - Self.pad * 2, 8)
    }

    /// The slot length an item with `appCount` glyphs wants
    /// along the bar axis: identifier cell + the divider rule
    /// (when glyphs follow) + one cell per app glyph (+ one for
    /// the "+n" overflow badge) + padding. The overlay uses
    /// this for auto sizing.
    static func autoLength(
        appCount: Int,
        overflow: Int = 0,
        depth: CGFloat
    ) -> CGFloat {
        let cell = max(depth - pad * 2, 8)
        let slots = appCount + (overflow > 0 ? 1 : 0)
        let divider: CGFloat = slots > 0 ? pad + 1 + pad : 0
        return pad * 2 + cell + divider + CGFloat(slots) * cell
    }

    override func layout() {
        super.layout()
        let cell = cellLength
        if case .text = spaceGlyph {
            // Emoji/character identifiers use the system font;
            // App Font ligatures are app glyphs, never
            // identifiers.
            identifierLabel.font = .systemFont(
                ofSize: identifierFont
            )
        }
        // Restyle BEFORE placing: `place` measures each text
        // glyph to center it vertically, and the glyph fonts
        // are set in `restyle` (bounds are already final here).
        restyle()
        var cursor = Self.pad
        place(identifierImage, at: cursor, cell: cell)
        place(identifierLabel, at: cursor, cell: cell)
        cursor += cell
        if !identifierDivider.isHidden {
            cursor += Self.pad
            let depth =
                horizontal ? bounds.height : bounds.width
            identifierDivider.frame = BarDivider.frame(
                at: cursor,
                depth: depth,
                cell: cell,
                horizontal: horizontal
            )
            cursor += 1 + Self.pad
        }
        for (index, view) in appViews.enumerated() {
            place(view, at: cursor, cell: cell)
            if index < badgeViews.count {
                layoutBadge(
                    badgeViews[index],
                    onCellAt: cursor,
                    cell: cell
                )
            }
            cursor += cell
        }
        if overflow > 0 {
            // The "+n" badge occupies its own trailing slot,
            // centered like a glyph.
            layoutBadge(
                overflowBadge,
                onCellAt: cursor,
                cell: cell,
                centered: true
            )
            cursor += cell
        }
        layoutAccent()
    }

    /// A count badge hugging its glyph cell's top-trailing
    /// corner (flipped coordinates), or centered in the cell
    /// for the overflow slot. Circle grows for multi-digit
    /// counts — same shape as the App Bar's badge.
    private func layoutBadge(
        _ badge: NSTextField,
        onCellAt offset: CGFloat,
        cell: CGFloat,
        centered: Bool = false
    ) {
        guard !badge.isHidden else { return }
        // 0.42/8: the 0.5-of-cell badge with its 9pt floor read
        // oversized next to small glyphs (QA 2026-07-19); the
        // cap still stops ballooning on fat bars.
        let base = min(max(cell * 0.42, 8), 13)
        badge.font = .systemFont(
            ofSize: base * 0.9,
            weight: .bold
        )
        let textWidth = ceil(badge.cell?.cellSize.width ?? 0)
        // Capped at the cell so a "+42" on a thin bar squeezes
        // rather than clipping top/bottom under masksToBounds.
        let diameter = min(
            max(base, textWidth + 2),
            cell + 2
        )
        let cellRect =
            horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
        let rect =
            centered
            ? CGRect(
                x: cellRect.midX - diameter / 2,
                y: cellRect.midY - diameter / 2,
                width: diameter,
                height: diameter
            )
            : CGRect(
                x: cellRect.maxX - diameter + 1,
                y: cellRect.minY - 1,
                width: diameter,
                height: diameter
            )
        badge.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
        badge.layer?.cornerRadius = diameter / 2
    }

    private func place(
        _ view: NSView,
        at offset: CGFloat,
        cell: CGFloat
    ) {
        var rect =
            horizontal
            ? CGRect(
                x: offset,
                y: (bounds.height - cell) / 2,
                width: cell,
                height: cell
            )
            : CGRect(
                x: (bounds.width - cell) / 2,
                y: offset,
                width: cell,
                height: cell
            )
        // AppKit draws text from the frame's TOP, so a text
        // glyph (App Font ligature, character identifier)
        // handed the whole square cell reads top-aligned.
        // Shrink to its measured height, centered — the
        // `AppBarItemView+GlyphSlot` midY idiom. Images
        // center natively and keep the full cell.
        if let field = view as? NSTextField {
            let height = ceil(
                field.cell?.cellSize.height ?? 0
            )
            if height > 0, height < rect.height {
                rect.origin.y +=
                    ((rect.height - height) / 2).rounded()
                rect.size.height = height
            }
        }
        view.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
    }

    private func layoutAccent() {
        switch style.activeIndicator {
        case .ring:
            // Boxed hugs the box; plain/material insets to the
            // App Bar's capsule ring (ui-designer 2026-07-14) —
            // a full-bounds square poked past the shared plate's
            // rounded corners in hug mode (QA 2026-07-19).
            accent.frame =
                style.tabBackground.rendered == .boxed
                ? bounds
                : bounds.insetBy(
                    dx: BarAccent.capsuleInset,
                    dy: BarAccent.capsuleInset
                )
        case .edgeMark:
            // On the window-facing side of the slot: a top bar
            // faces down, a left bar right, and so on. The view
            // is flipped (y grows down), so a top bar's mark
            // sits at maxY.
            let mark: CGFloat = 3
            switch style.edge {
            case .top:
                accent.frame = CGRect(
                    x: 0,
                    y: bounds.height - mark,
                    width: bounds.width,
                    height: mark
                )
            case .bottom:
                accent.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: bounds.width,
                    height: mark
                )
            case .left:
                accent.frame = CGRect(
                    x: bounds.width - mark,
                    y: 0,
                    width: mark,
                    height: bounds.height
                )
            case .right:
                accent.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: mark,
                    height: bounds.height
                )
            }
        case .gap:
            accent.frame = .zero
        }
    }
}
