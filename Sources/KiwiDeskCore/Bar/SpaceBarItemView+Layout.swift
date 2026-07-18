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
    /// along the bar axis: identifier cell + one cell per app
    /// glyph + padding. The overlay uses this for auto sizing.
    static func autoLength(
        appCount: Int,
        depth: CGFloat
    ) -> CGFloat {
        let cell = max(depth - pad * 2, 8)
        return pad * 2 + cell + CGFloat(appCount) * cell
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
        var cursor = Self.pad
        place(identifierImage, at: cursor, cell: cell)
        place(identifierLabel, at: cursor, cell: cell)
        cursor += cell
        for view in appViews {
            place(view, at: cursor, cell: cell)
            cursor += cell
        }
        layoutAccent()
        // Corner radius and fonts depend on the final bounds.
        restyle()
    }

    private func place(
        _ view: NSView,
        at offset: CGFloat,
        cell: CGFloat
    ) {
        let rect =
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
        view.frame = backingAlignedRect(
            rect,
            options: .alignAllEdgesNearest
        )
    }

    private func layoutAccent() {
        switch style.activeIndicator {
        case .ring:
            accent.frame = bounds
        case .edgeMark:
            // On the window-facing side of the slot: a top bar
            // faces down, a left bar right, and so on.
            let mark: CGFloat = 3
            switch style.edge {
            case .top:
                accent.frame = CGRect(
                    x: 0,
                    y: 0,
                    width: bounds.width,
                    height: mark
                )
            case .bottom:
                accent.frame = CGRect(
                    x: 0,
                    y: bounds.height - mark,
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
